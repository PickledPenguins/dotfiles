"""Shared fixtures.

`dots` has no .py suffix, so it is loaded here by path once per session and
handed to tests as the `dots` fixture; the CLI tests call `dots.main(argv)`
in-process so coverage sees every line. HOME is redirected per test through
the environment -- Path.home() reads $HOME -- so nothing here can touch the
real home directory.
"""

import importlib.util
import os
import subprocess
import sys
from pathlib import Path

import pytest

REPO = Path(__file__).resolve().parent.parent

# core.gitconfig names ~/.local/share/git-template, which a throwaway home
# lacks until git hooks template writes it: every git init there would warn.
# The tests' children take git's own template instead, next to its exec
# path (--template, or GIT_TEMPLATE_DIR unset, brings back the setting).
os.environ.setdefault("GIT_TEMPLATE_DIR", str(
    Path(subprocess.run(["git", "--exec-path"], capture_output=True, text=True, check=True).stdout.strip())
    .parent.parent / "share" / "git-core" / "templates"))
DOTS = REPO / "dots"


def fast_mode_apart(environment, home):
    """The caller's fast mode out of a test shell's ENVIRONMENT, and fast mode's
    samples kept beside HOME instead of in the runner's /dev/shm/dots-UID."""
    for var in [v for v in environment if v.startswith("DOTS_FAST")]:
        environment.pop(var)
    run_dir = Path(home).parent / "xdg-run"
    run_dir.mkdir(mode=0o700, exist_ok=True)
    environment["XDG_RUNTIME_DIR"] = str(run_dir)
    return environment


def pytest_configure(config):
    config.addinivalue_line("markers", "long: integration and end-to-end; not in the commit gate")


def load_dots():
    sys.dont_write_bytecode = True      # or the loader drops __pycache__/ into the source root
    spec = importlib.util.spec_from_loader("dots", importlib.machinery.SourceFileLoader("dots", str(DOTS)))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


@pytest.fixture(autouse=True)
def umask_022():
    """New files 644: `add` infers private_ from the mode, so the caller's umask
    (the shipped 027 among them) would otherwise change what the tests see."""
    old = os.umask(0o022)
    yield
    os.umask(old)


@pytest.fixture(scope="session")
def dots():
    return load_dots()


@pytest.fixture
def home(tmp_path, monkeypatch):
    """An empty HOME, also exported so subprocesses and Path.home() agree."""
    h = tmp_path / "home"
    h.mkdir()
    monkeypatch.setenv("HOME", str(h))
    for var in ("XDG_CONFIG_HOME", "DOTS_SOURCE", "DOTFILES_DIR", "DOTFILES_BASH_DIR"):
        monkeypatch.delenv(var, raising=False)
    return h


@pytest.fixture
def src(tmp_path):
    """A small source tree exercising every naming attribute."""
    s = tmp_path / "src"
    (s / "dot_config" / "app").mkdir(parents=True)
    (s / "private_dot_ssh").mkdir()
    (s / "dot_local" / "bin").mkdir(parents=True)
    (s / "dot_bashrc").write_text("# bashrc\n")
    (s / "dot_config" / "app" / "settings.ini").write_text("[app]\n")
    (s / "private_dot_ssh" / "config").write_text("Host *\n")
    (s / "dot_local" / "bin" / "executable_hello").write_text("#!/bin/sh\necho hi\n")
    (s / "README.md").write_text("docs\n")
    (s / ".dotsignore").write_text("# comment\nREADME.md\n")
    (s / ".git").mkdir()
    (s / ".git" / "HEAD").write_text("ref\n")
    return s


@pytest.fixture
def run(dots, src, capsys):
    """Call the CLI in-process against `src`; returns (exit code, stdout, stderr)."""
    def _run(*args, source=None):
        code = dots.main(["-S", str(source or src), *args])
        out = capsys.readouterr()
        return code, out.out, out.err

    return _run


@pytest.fixture
def linked(home):
    """HOME with this checkout applied by dots."""
    proc = run_subprocess(home, REPO, "apply")
    assert proc.returncode == 0, proc.stdout
    return home


def run_subprocess(home, src, *args, env=None):
    """The CLI as a real process, for exit codes and argparse behavior."""
    environment = fast_mode_apart(dict(os.environ, HOME=str(home), DOTS_SOURCE=str(src)), home)
    environment.update(env or {})
    return subprocess.run([sys.executable, str(DOTS), *args], env=environment,
                          capture_output=True, text=True)
