"""Shared fixtures.

`dots` has no .py suffix, so it is loaded here by path once per session and
handed to tests as the `dots` fixture; the CLI tests call `dots.main(argv)`
in-process so coverage sees every line.  HOME is redirected per test through
the environment -- Path.home() reads $HOME -- so nothing here can touch the
real home directory.
"""

import importlib.util
import os
import sys
from pathlib import Path

import pytest

REPO = Path(__file__).resolve().parent.parent
DOTS = REPO / "dots"


def pytest_configure(config):
    config.addinivalue_line("markers", "long: integration and end-to-end; not in the commit gate")


def load_dots():
    spec = importlib.util.spec_from_loader("dots", importlib.machinery.SourceFileLoader("dots", str(DOTS)))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


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


def run_subprocess(home, src, *args, env=None):
    """The CLI as a real process, for exit codes and argparse behavior."""
    import subprocess

    environment = dict(os.environ, HOME=str(home), DOTS_SOURCE=str(src))
    environment.update(env or {})
    return subprocess.run([sys.executable, str(DOTS), *args], env=environment,
                          capture_output=True, text=True)
