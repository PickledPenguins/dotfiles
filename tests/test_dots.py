"""Tests for the dots command and for the shipped configuration.

Every test runs dots as a subprocess with HOME and DOTS_SOURCE pointing at
temporary directories, so nothing touches the real home directory.
"""

import os
import shutil
import stat
import subprocess
import sys
from pathlib import Path

import pytest

REPO = Path(__file__).resolve().parent.parent
DOTS = REPO / "dots"


def run(home, src, *args, check=True):
    env = dict(os.environ, HOME=str(home), DOTS_SOURCE=str(src))
    env.pop("XDG_CONFIG_HOME", None)
    proc = subprocess.run([sys.executable, str(DOTS), *args], env=env,
                          capture_output=True, text=True)
    if check:
        assert proc.returncode == 0, proc.stdout + proc.stderr
    return proc


@pytest.fixture
def home(tmp_path):
    h = tmp_path / "home"
    h.mkdir()
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


# ── naming and selection ──────────────────────────────────────────────────


def test_managed_maps_attributes_to_target_paths(home, src):
    out = run(home, src, "managed").stdout.splitlines()
    assert out == [".bashrc", ".config/app/settings.ini", ".local/bin/hello", ".ssh/config"]


def test_dotfiles_in_source_root_and_ignore_patterns_are_skipped(home, src):
    out = run(home, src, "managed").stdout
    assert "README.md" not in out
    assert "HEAD" not in out
    assert ".dotsignore" not in out


def test_managed_show_source_prints_source_paths(home, src):
    out = run(home, src, "managed", "--show-source").stdout.splitlines()
    assert out[0] == str(src / "dot_bashrc")


# ── apply ─────────────────────────────────────────────────────────────────


def test_apply_links_files_and_creates_real_directories(home, src):
    run(home, src, "apply")
    assert (home / ".bashrc").is_symlink()
    assert os.readlink(home / ".bashrc") == str(src / "dot_bashrc")
    assert (home / ".config" / "app").is_dir() and not (home / ".config" / "app").is_symlink()
    assert (home / ".config" / "app" / "settings.ini").read_text() == "[app]\n"


def test_apply_sets_private_and_executable_modes(home, src):
    run(home, src, "apply")
    assert stat.S_IMODE((home / ".ssh").stat().st_mode) == 0o700
    assert stat.S_IMODE((src / "private_dot_ssh" / "config").stat().st_mode) & 0o077 == 0
    assert (src / "dot_local" / "bin" / "executable_hello").stat().st_mode & stat.S_IXUSR


def test_apply_is_idempotent(home, src):
    run(home, src, "apply")
    out = run(home, src, "apply").stdout
    assert out.strip() == "0 change(s)"


def test_apply_dry_run_changes_nothing(home, src):
    out = run(home, src, "apply", "--dry-run").stdout
    assert "link      .bashrc" in out
    assert "(dry run)" in out
    assert not (home / ".bashrc").exists()


def test_apply_refuses_real_file_without_force(home, src):
    (home / ".bashrc").write_text("mine\n")
    out = run(home, src, "apply").stdout
    assert "conflict  .bashrc" in out
    assert (home / ".bashrc").read_text() == "mine\n"


def test_apply_force_backs_up_real_file_then_links(home, src):
    (home / ".bashrc").write_text("mine\n")
    out = run(home, src, "apply", "--force").stdout
    assert "backup    .bashrc" in out
    assert (home / ".bashrc").is_symlink()
    backups = list((home / ".dotfiles-backup").glob("*/.bashrc"))
    assert len(backups) == 1 and backups[0].read_text() == "mine\n"


def test_apply_treats_foreign_symlink_as_conflict(home, src):
    (home / "elsewhere").write_text("other\n")
    os.symlink(home / "elsewhere", home / ".bashrc")
    out = run(home, src, "apply").stdout
    assert "conflict  .bashrc" in out
    run(home, src, "apply", "--force")
    assert os.readlink(home / ".bashrc") == str(src / "dot_bashrc")
    # the old symlink itself was backed up, not the file it pointed to
    assert (home / "elsewhere").read_text() == "other\n"


def test_apply_relinks_stale_link_into_source_tree(home, src):
    run(home, src, "apply")
    shutil.move(str(src / "dot_bashrc"), str(src / "dot_bashrc.old"))
    (src / "dot_bashrc").write_text("# new\n")
    os.remove(home / ".bashrc")
    os.symlink(src / "dot_bashrc.old", home / ".bashrc")   # points inside src, wrong file
    out = run(home, src, "apply").stdout
    assert "relink    .bashrc" in out
    assert os.readlink(home / ".bashrc") == str(src / "dot_bashrc")


def test_apply_restricted_to_a_path(home, src):
    run(home, src, "apply", str(home / ".config"))
    assert (home / ".config" / "app" / "settings.ini").is_symlink()
    assert not (home / ".bashrc").exists()


# ── status, unlink, add, forget ───────────────────────────────────────────


def test_status_reports_each_state_and_exit_code(home, src):
    (home / ".bashrc").write_text("mine\n")
    proc = run(home, src, "status", check=False)
    assert proc.returncode == 1
    assert "conflict    .bashrc" in proc.stdout
    assert "missing     .ssh/config" in proc.stdout
    run(home, src, "apply", "--force")
    proc = run(home, src, "status")
    assert proc.stdout.strip() == "ok: 4"


def test_unlink_removes_only_our_links(home, src):
    run(home, src, "apply")
    (home / "elsewhere").write_text("other\n")
    os.remove(home / ".bashrc")
    os.symlink(home / "elsewhere", home / ".bashrc")
    out = run(home, src, "unlink").stdout
    assert "3 link(s) removed" in out
    assert (home / ".bashrc").is_symlink()          # foreign link untouched
    assert not (home / ".ssh" / "config").exists()
    assert (src / "private_dot_ssh" / "config").exists()   # source untouched


def test_add_moves_file_into_source_and_links_back(home, src):
    (home / ".config" / "tool").mkdir(parents=True)
    (home / ".config" / "tool" / "rc").write_text("x\n")
    (home / ".secret").write_text("s\n")
    os.chmod(home / ".secret", 0o600)
    (home / ".local" / "bin").mkdir(parents=True)
    (home / ".local" / "bin" / "tool").write_text("#!/bin/sh\n")
    os.chmod(home / ".local" / "bin" / "tool", 0o755)
    out = run(home, src, "add", str(home / ".config/tool/rc"), str(home / ".secret"),
              str(home / ".local/bin/tool")).stdout
    assert "add       .config/tool/rc  ->  dot_config/tool/rc" in out
    assert "add       .secret  ->  private_dot_secret" in out
    assert "add       .local/bin/tool  ->  dot_local/bin/executable_tool" in out
    assert (src / "dot_config" / "tool" / "rc").read_text() == "x\n"
    assert os.readlink(home / ".config" / "tool" / "rc") == str(src / "dot_config" / "tool" / "rc")
    assert run(home, src, "status", check=False).stdout.strip().endswith("ok: 3")


def test_add_skips_symlinks_directories_and_outsiders(home, src, tmp_path):
    run(home, src, "apply")
    (home / "dir").mkdir()
    outside = tmp_path / "outside"
    outside.write_text("o\n")
    out = run(home, src, "add", str(home / ".bashrc"), str(home / "dir"), str(outside)).stdout
    assert "skip      .bashrc: already a symlink" in out
    assert "skip      dir: not a regular file" in out
    assert f"skip      {outside}: not under" in out


def test_forget_leaves_a_real_copy_and_removes_the_source(home, src):
    run(home, src, "apply")
    run(home, src, "forget", str(home / ".bashrc"))
    assert not (home / ".bashrc").is_symlink()
    assert (home / ".bashrc").read_text() == "# bashrc\n"
    assert not (src / "dot_bashrc").exists()
    assert ".bashrc" not in run(home, src, "managed").stdout


def test_missing_source_dir_is_an_error(home, tmp_path):
    proc = run(home, tmp_path / "nope", "managed", check=False)
    assert proc.returncode != 0
    assert "does not exist" in proc.stderr


# ── the shipped configuration ─────────────────────────────────────────────


@pytest.fixture
def linked_home(home):
    """The real repository applied into a temporary HOME."""
    run(home, REPO, "apply")
    return home


def shell(home, script):
    env = dict(os.environ, HOME=str(home), TERM="xterm-256color")
    for var in ("DOTFILES_DIR", "DOTFILES_BASH_DIR", "XDG_CONFIG_HOME"):
        env.pop(var, None)
    return subprocess.run(["bash", "--rcfile", str(home / ".bashrc"), "-i", "-c", script],
                          env=env, capture_output=True, text=True)


def test_shipped_bashrc_loads_every_module(linked_home):
    proc = shell(linked_home, "echo ok")
    assert proc.returncode == 0
    assert "ok" in proc.stdout
    assert not [l for l in proc.stderr.splitlines() if "job control" not in l and "process group" not in l], proc.stderr


def test_shipped_bashrc_defines_aliases_functions_and_prompt(linked_home):
    proc = shell(linked_home, "alias ll; type -t mkcd; type -t prompt_build; echo \"${#PS1}\"")
    assert "alias ll=" in proc.stdout
    assert "function\nfunction" in proc.stdout
    assert int(proc.stdout.splitlines()[-1]) > 10


def test_shipped_bashrc_honors_disabled_file(linked_home):
    bash_dir = linked_home / ".config" / "bash"
    (bash_dir / "disabled").write_text("functions  # no shell functions here\n")
    proc = shell(linked_home, "type -t mkcd || echo absent")
    assert "absent" in proc.stdout


def test_shipped_bashrc_debug_lists_modules(linked_home):
    env_line = "DOTFILES_DEBUG=1"
    proc = subprocess.run(["env", f"HOME={linked_home}", env_line, "bash", "--rcfile",
                           str(linked_home / ".bashrc"), "-i", "-c", "true"],
                          capture_output=True, text=True)
    names = [l.split()[1] for l in proc.stderr.splitlines() if l.startswith("bashrc:")]
    assert names[:3] == ["env", "options", "path"] and names[-1] == "local"


def test_shipped_bashrc_local_override_wins(linked_home):
    (linked_home / ".bashrc.local").write_text("alias ll='echo local'\n")
    proc = shell(linked_home, "alias ll")
    assert "echo local" in proc.stdout


@pytest.mark.skipif(shutil.which("vim") is None, reason="vim not installed")
def test_shipped_vimrc_loads_modules(linked_home):
    proc = subprocess.run(["vim", "-es", "-u", str(linked_home / ".vimrc"),
                           "-c", "set shiftwidth? hlsearch?", "-c", "qall!"],
                          env=dict(os.environ, HOME=str(linked_home)), capture_output=True, text=True)
    assert "shiftwidth=2" in proc.stdout and "hlsearch" in proc.stdout
    assert (linked_home / ".vim" / "tmp" / "undo").is_dir()


@pytest.mark.skipif(shutil.which("tmux") is None, reason="tmux not installed")
def test_shipped_tmux_conf_parses(linked_home):
    sock = f"dots-test-{os.getpid()}"
    env = dict(os.environ, HOME=str(linked_home))
    env.pop("TMUX", None)
    proc = subprocess.run(["tmux", "-L", sock, "-f", str(linked_home / ".tmux.conf"),
                           "start-server", ";", "show", "-g", "mouse", ";", "kill-server"],
                          env=env, capture_output=True, text=True)
    assert proc.returncode == 0, proc.stderr
    assert "mouse on" in proc.stdout


def test_shipped_gitconfig_includes_resolve(linked_home):
    env = dict(os.environ, HOME=str(linked_home))
    env.pop("GIT_CONFIG_GLOBAL", None)
    out = subprocess.run(["git", "config", "--includes", "--global", "alias.lg"], env=env,
                         capture_output=True, text=True).stdout
    assert out.startswith("log --graph")
