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
    assert proc.stdout == "installed .git/hooks/pre-commit -> tests/hooks/pre-commit\n"
    assert os.readlink(tmp_path / ".git" / "hooks" / "pre-commit") == "../../tests/hooks/pre-commit"
