"""Run the example catalog: every case under tests/examples/, end to end.

A case is a directory with a README.md and a case.sh.  The runner gives the
script a fresh SRC (empty, or a copy of this repository when the script says
`# source: repo`), a fresh HOME, and a `dots` on PATH, runs it with bash from
inside HOME, and compares stdout+stderr -- with the temporary paths and
backup timestamps normalized -- to expected.txt beside it.

    python3 tests/test_examples.py CASE...     print a case's normalized output
    python3 tests/test_examples.py --write CASE...   (re)write its expected.txt
"""

import os
import re
import shutil
import stat
import subprocess
import sys
from pathlib import Path

import pytest

REPO = Path(__file__).resolve().parent.parent
EXAMPLES = REPO / "tests" / "examples"
LEVELS = ("simple", "moderate", "complex", "failures")


def cases():
    return [c for level in LEVELS for c in sorted((EXAMPLES / level).iterdir()) if c.is_dir()]


def case_id(case):
    return f"{case.parent.name}/{case.name}"


def run_case(case, tmp):
    src, home, bin_dir = tmp / "src", tmp / "home", tmp / "bin"
    script = (case / "case.sh").read_text()
    if "# source: repo" in script:
        shutil.copytree(REPO, src, ignore=shutil.ignore_patterns(".git", ".build", ".pytest_cache", "__pycache__"))
    else:
        src.mkdir()
    home.mkdir()
    bin_dir.mkdir()
    shim = bin_dir / "dots"
    shim.write_text(f"#!/bin/sh\nexec {sys.executable} {REPO / 'dots'} \"$@\"\n")
    shim.chmod(shim.stat().st_mode | stat.S_IXUSR)
    env = {
        "HOME": str(home), "SRC": str(src), "DOTS_SOURCE": str(src), "REPO": str(REPO),
        "PATH": f"{bin_dir}:{os.environ['PATH']}", "TERM": "xterm-256color", "LANG": "C.UTF-8",
        "USER": os.environ.get("USER", "user"),
    }
    proc = subprocess.run(["bash", str(case / "case.sh")], cwd=home, env=env, stdout=subprocess.PIPE,
                          stderr=subprocess.STDOUT, text=True, errors="replace", timeout=120)
    out = (proc.stdout.replace(str(src), "SRC").replace(str(home), "HOME")
           .replace(str(REPO), "REPO").replace(str(tmp), "TMP"))
    out = re.sub(r"\d{8}-\d{6}", "TS", out)
    out = re.sub(r"pytest-of-\w+/pytest-\d+/[^/]+/", "TMP/", out)
    return proc.returncode, out


@pytest.mark.long
@pytest.mark.parametrize("case", cases(), ids=case_id)
def test_example(case, tmp_path):
    code, out = run_case(case, tmp_path)
    assert code == 0, out
    expected = (case / "expected.txt").read_text()
    assert out == expected


@pytest.mark.long
@pytest.mark.parametrize("case", cases(), ids=case_id)
def test_every_case_documents_itself(case):
    readme = (case / "README.md").read_text()
    assert readme.startswith("# "), "README needs a title"
    assert re.search(r"^\*\*Level:\*\* (simple|moderate|complex|failure)$", readme, re.M), "README needs a Level line"
    assert "## What it shows" in readme
    assert "## Expected" in readme
    if case.parent.name == "complex":
        assert "## Why the combination matters" in readme


@pytest.mark.long
def test_catalog_has_enough_variety():
    counts = {level: len(list((EXAMPLES / level).iterdir())) for level in LEVELS}
    assert counts["simple"] >= 15 and counts["moderate"] >= 12 and counts["complex"] >= 6
    assert counts["failures"] >= 8


if __name__ == "__main__":
    import tempfile

    write = "--write" in sys.argv
    names = [a for a in sys.argv[1:] if a != "--write"]
    for case in cases():
        if names and case_id(case) not in names and case.name not in names:
            continue
        with tempfile.TemporaryDirectory() as tmp:
            code, out = run_case(case, Path(tmp))
        print(f"=== {case_id(case)} (exit {code})")
        print(out, end="")
        if write:
            (case / "expected.txt").write_text(out)
