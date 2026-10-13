"""tests/run-tests.sh: where pytest comes from, run from a copy with stub programs."""

import os
import shutil
import subprocess
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parent.parent
# What hook sets hooks.test and hooks.perf to, before the suite name.
RUNNER = 'r=tests/run-tests.sh; [ -e "$r" ] || r=./run-tests.sh; "$r"'


def runner(tmp_path, *args, in_env=None, git=None, python3="exit 1\n"):
    """Run a copy of tests/run-tests.sh whose python3 has no pytest; IN_ENV, GIT
    and PYTHON3, when given, are the bodies of stub programs beside it."""
    (tmp_path / "tests").mkdir()
    shutil.copy(ROOT / "tests" / "run-tests.sh", tmp_path / "tests" / "run-tests.sh")
    fake = tmp_path / "fakebin"
    fake.mkdir()
    stubs = {"python3": python3}
    if in_env is not None:
        stubs["in-env"] = in_env
    if git is not None:
        stubs["git"] = git
    for name, body in stubs.items():
        (fake / name).write_text("#!/bin/sh\n" + body)
        os.chmod(fake / name, 0o755)
    env = {**os.environ, "PATH": f"{fake}:/usr/bin:/bin"}
    return subprocess.run(["sh", str(tmp_path / "tests" / "run-tests.sh"), *args],
                          capture_output=True, text=True, env=env, cwd=tmp_path / "tests")


def test_without_pytest_the_runner_reruns_itself_under_in_env(tmp_path):
    proc = runner(tmp_path, "fast", "-k", "add", in_env='[ "$1" = python3 ] && exit 0\necho "in-env $*"\n')
    assert (proc.returncode, proc.stdout, proc.stderr) == (0, "in-env tests/run-tests.sh fast -k add\n", "")


@pytest.mark.parametrize("in_env", [None, "exit 1\n"], ids=["no in-env", "in-env without pytest"])
def test_without_pytest_anywhere_the_runner_names_the_interpreter_and_exits_2(tmp_path, in_env):
    proc = runner(tmp_path, "long", in_env=in_env)
    assert (proc.returncode, proc.stdout) == (2, "")
    assert proc.stderr == (f"run-tests.sh: python3 ({tmp_path}/fakebin/python3) has no pytest: "
                           "install it, or put in-env on PATH\n")


def test_installing_the_hook_needs_no_pytest(tmp_path):
    proc = runner(tmp_path, "hook", git='[ "$1" = rev-parse ] && echo .git/hooks && exit 0\necho "git $*"\n')
    assert (proc.returncode, proc.stdout, proc.stderr) == (
        0, f"git config hooks.test {RUNNER} fast\ngit config hooks.perf {RUNNER} perf\n"
           "git hooks install test-push perf-push\nswitch them on with: git hooks on test-push perf-push\n", "")


@pytest.mark.parametrize("where", ["tests/run-tests.sh", "./run-tests.sh"], ids=["now", "before-the-move"])
def test_the_hook_command_finds_the_runner_where_the_commit_has_it(tmp_path, where):
    runner = tmp_path / where
    runner.parent.mkdir(exist_ok=True)
    runner.write_text('#!/bin/sh\necho "$0 $*"\n')
    runner.chmod(0o755)
    proc = subprocess.run(["sh", "-c", f"{RUNNER} fast"], capture_output=True, text=True, cwd=tmp_path)
    assert (proc.returncode, proc.stdout) == (0, f"{where} fast\n")


def test_perf_needs_no_pytest_and_passes_its_arguments_on(tmp_path):
    proc = runner(tmp_path, "perf", "--runs", "3", python3='[ "$1" = -c ] && exit 1\necho "python3 $* in $PWD"\n')
    assert (proc.returncode, proc.stdout, proc.stderr) == (0, f"python3 tests/perf.py --runs 3 in {tmp_path}\n", "")
