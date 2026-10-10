"""run-tests.sh: where pytest comes from, run from a copy with stub programs."""

import os
import shutil
import subprocess
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parent.parent


def runner(tmp_path, *args, in_env=None):
    """Run a copy of run-tests.sh whose python3 has no pytest; IN_ENV, when
    given, is the body of a stub in-env beside it."""
    shutil.copy(ROOT / "run-tests.sh", tmp_path / "run-tests.sh")
    fake = tmp_path / "fakebin"
    fake.mkdir()
    stubs = {"python3": "exit 1\n"}
    if in_env is not None:
        stubs["in-env"] = in_env
    for name, body in stubs.items():
        (fake / name).write_text("#!/bin/sh\n" + body)
        os.chmod(fake / name, 0o755)
    env = {**os.environ, "PATH": f"{fake}:/usr/bin:/bin"}
    return subprocess.run(["sh", str(tmp_path / "run-tests.sh"), *args], capture_output=True,
                          text=True, env=env, cwd=tmp_path)


def test_without_pytest_the_runner_reruns_itself_under_in_env(tmp_path):
    proc = runner(tmp_path, "fast", "-k", "add", in_env='[ "$1" = python3 ] && exit 0\necho "in-env $*"\n')
    assert (proc.returncode, proc.stdout, proc.stderr) == (0, "in-env ./run-tests.sh fast -k add\n", "")


@pytest.mark.parametrize("in_env", [None, "exit 1\n"], ids=["no in-env", "in-env without pytest"])
def test_without_pytest_anywhere_the_runner_names_the_interpreter_and_exits_2(tmp_path, in_env):
    proc = runner(tmp_path, "long", in_env=in_env)
    assert (proc.returncode, proc.stdout) == (2, "")
    assert proc.stderr == (f"run-tests.sh: python3 ({tmp_path}/fakebin/python3) has no pytest: "
                           "install it, or put in-env on PATH\n")


def test_installing_the_hook_needs_no_pytest(tmp_path):
    (tmp_path / ".git" / "hooks").mkdir(parents=True)
    proc = runner(tmp_path, "hook")
    assert proc.returncode == 0, proc.stderr
    assert proc.stdout == ("installed .git/hooks/pre-push.off -> tests/hooks/pre-push,"
                           " switched off (git hooks on pre-push)\n")
    assert os.readlink(tmp_path / ".git" / "hooks" / "pre-push.off") == "../../tests/hooks/pre-push"
    assert not (tmp_path / ".git" / "hooks" / "pre-push").exists()


def test_the_pre_push_hook_tests_each_pushed_commit_in_a_clean_checkout(tmp_path):
    def git(*args):
        return subprocess.run(["git", "-C", str(tmp_path), *args], capture_output=True, text=True, check=True).stdout

    git("init", "-q")
    git("-c", "user.name=t", "-c", "user.email=t@t", "commit", "-q", "--allow-empty", "-m", "no hook yet")
    old = git("rev-parse", "HEAD").strip()
    (tmp_path / "tests" / "hooks").mkdir(parents=True)
    shutil.copy(ROOT / "tests" / "hooks" / "pre-push", tmp_path / "tests" / "hooks" / "pre-push")
    # The suite reads its stdin: the hook's own, the pushed refs, must not be it.
    (tmp_path / "run-tests.sh").write_text('#!/bin/sh\ncat >/dev/null\necho "suite $*"\n[ ! -e broken ]\n')
    os.chmod(tmp_path / "run-tests.sh", 0o755)
    git("add", ".")
    git("-c", "user.name=t", "-c", "user.email=t@t", "commit", "-q", "-m", "good")
    good = git("rev-parse", "HEAD").strip()
    (tmp_path / "broken").write_text("")
    git("add", "broken")
    git("-c", "user.name=t", "-c", "user.email=t@t", "commit", "-q", "-m", "bad")
    bad = git("rev-parse", "HEAD").strip()
    git("rm", "-q", "--cached", "broken")            # still in the work tree, untracked

    def push(*shas):
        lines = "".join(f"refs/heads/x {s} refs/heads/x {'0' * 40}\n" for s in shas)
        return subprocess.run([str(tmp_path / "tests" / "hooks" / "pre-push"), "origin", "url"], input=lines,
                              capture_output=True, text=True, cwd=tmp_path)

    proc = push("0" * 40, old, good)
    assert (proc.returncode, proc.stdout, proc.stderr) == (0, "suite fast\n", f"pre-push: {old} has no tests/hooks/pre-push; not tested\n")
    proc = push(good, bad)
    assert (proc.returncode, proc.stdout, proc.stderr) == (
        1, "suite fast\nsuite fast\n", f"pre-push: tests fail at {bad}; push stopped\n")
    assert len(git("worktree", "list").splitlines()) == 1
