"""Unit tests for the functions in `dots`, called directly."""

import os
import random
import stat
import string
from pathlib import Path

import pytest

# ── naming ────────────────────────────────────────────────────────────────


@pytest.mark.parametrize("name, expected", [
    ("dot_bashrc", (".bashrc", False, False)),
    ("bashrc", ("bashrc", False, False)),
    ("private_dot_ssh", (".ssh", True, False)),
    ("executable_dot_run", (".run", False, True)),
    ("private_executable_dot_x", (".x", True, True)),
    ("executable_private_x", ("x", True, True)),
    ("dot_", (".", False, False)),
    ("dot_dot_x", (".dot_x", False, False)),      # dot_ is consumed once
    ("private_", ("", True, False)),
    ("", ("", False, False)),
])
def test_parse_name(dots, name, expected):
    assert dots.parse_name(name) == expected


@pytest.mark.parametrize("rel, private, executable, expected", [
    (".bashrc", False, False, "dot_bashrc"),
    (".config/git/config", False, False, "dot_config/git/config"),
    (".ssh/config", True, False, "dot_ssh/private_config"),
    (".local/bin/tool", False, True, "dot_local/bin/executable_tool"),
    (".x", True, True, "private_executable_dot_x"),
    ("plain", False, False, "plain"),
])
def test_source_name(dots, rel, private, executable, expected):
    assert str(dots.source_name(rel, private, executable)) == expected


def test_source_name_then_parse_name_round_trips_generated_paths(dots):
    """Property: every target path survives source_name -> parse_name unchanged."""
    rng = random.Random(1234)
    alphabet = string.ascii_letters + string.digits + "-_."
    for _ in range(500):
        parts = []
        for _ in range(rng.randint(1, 4)):
            body = "".join(rng.choice(alphabet) for _ in range(rng.randint(1, 8))).strip(".") or "x"
            parts.append(("." if rng.random() < 0.5 else "") + body)
        rel = "/".join(parts)
        private, executable = rng.random() < 0.3, rng.random() < 0.3
        source = dots.source_name(rel, private, executable)
        back, got_private, got_executable = [], False, False
        for component in source.parts:
            name, p, e = dots.parse_name(component)
            back.append(name)
            got_private |= p
            got_executable |= e
        assert "/".join(back) == rel, source
        assert (got_private, got_executable) == (private, executable), source


# ── ignores ───────────────────────────────────────────────────────────────


def test_load_ignores_strips_comments_and_blanks(dots, tmp_path):
    (tmp_path / ".dotsignore").write_text("# top\n\nREADME.md  \n  tests\n# tail\n")
    assert dots.load_ignores(tmp_path) == ["README.md", "tests"]


def test_load_ignores_absent_file_means_nothing_ignored(dots, tmp_path):
    assert dots.load_ignores(tmp_path) == []


@pytest.mark.parametrize("rel, patterns, expected", [
    ("README.md", ["README.md"], True),
    ("docs/README.md", ["README.md"], False),          # anchored at the top
    ("tests/unit/test_a.py", ["tests"], True),          # a parent matches
    ("tests/unit/test_a.py", ["tests/*"], True),        # * crosses / in fnmatch
    (".config/app/x.local", ["*.local"], True),
    (".config/app/x.locally", ["*.local"], False),
    (".bashrc", [], False),
    ("a/b/c", ["a/b"], True),
    ("ab/c", ["a"], False),
])
def test_ignored(dots, rel, patterns, expected):
    assert dots.ignored(rel, patterns) is expected


# ── entries ───────────────────────────────────────────────────────────────


def test_entry_maps_components_and_collects_private_dirs(dots, tmp_path):
    home = tmp_path / "h"
    e = dots.Entry(tmp_path / "s", home, "private_dot_ssh/keys/executable_run")
    assert e.rel == ".ssh/keys/run"
    assert e.target == home / ".ssh" / "keys" / "run"
    assert e.source == tmp_path / "s" / "private_dot_ssh" / "keys" / "executable_run"
    assert (e.private, e.executable) == (True, True)
    assert e.private_dirs == [home / ".ssh", home / ".ssh" / "keys"]     # everything below is 700 too


def test_entry_private_on_the_file_itself_is_not_a_private_dir(dots, tmp_path):
    e = dots.Entry(tmp_path / "s", tmp_path / "h", "private_dot_netrc")
    assert e.private and e.private_dirs == []


def test_managed_entries_sorted_by_target_and_skipping_root_dotfiles(dots, src, home):
    rels = [e.rel for e in dots.managed_entries(src, home)]
    assert rels == [".bashrc", ".config/app/settings.ini", ".local/bin/hello", ".ssh/config"]


def test_managed_entries_ignore_patterns_apply_to_target_paths(dots, src, home):
    (src / ".dotsignore").write_text(".config\n")
    rels = [e.rel for e in dots.managed_entries(src, home)]
    assert ".config/app/settings.ini" not in rels and ".bashrc" in rels


def test_managed_entries_dotfiles_below_the_root_are_managed(dots, src, home):
    (src / "dot_config" / ".hidden").write_text("")
    assert ".config/.hidden" in [e.rel for e in dots.managed_entries(src, home)]


def test_managed_entries_empty_source(dots, tmp_path, home):
    assert dots.managed_entries(tmp_path, home) == []


# ── state ─────────────────────────────────────────────────────────────────


@pytest.fixture
def entry(dots, src, home):
    return dots.Entry(src, home, "dot_bashrc")


def test_state_missing(dots, entry, src):
    assert dots.state(entry, src) == "missing"


def test_state_ok(dots, entry, src):
    os.symlink(entry.source, entry.target)
    assert dots.state(entry, src) == "ok"


def test_state_stale_link_points_inside_source_tree(dots, entry, src):
    os.symlink(src / "dot_bashrc.old", entry.target)
    assert dots.state(entry, src) == "stale-link"


def test_state_stale_link_requires_a_path_separator_after_src(dots, entry, src, tmp_path):
    sibling = Path(str(src) + "2") / "dot_bashrc"        # /tmp/src2/... is not inside /tmp/src
    os.symlink(sibling, entry.target)
    assert dots.state(entry, src) == "conflict"


def test_state_conflict_real_file(dots, entry, src):
    entry.target.write_text("x")
    assert dots.state(entry, src) == "conflict"


def test_state_conflict_foreign_symlink(dots, entry, src, home):
    os.symlink(home / "elsewhere", entry.target)
    assert dots.state(entry, src) == "conflict"


def test_state_conflict_directory(dots, entry, src):
    entry.target.mkdir()
    assert dots.state(entry, src) == "conflict"


# ── modes ─────────────────────────────────────────────────────────────────


def test_set_mode_private_strips_group_and_other(dots, src, home):
    e = dots.Entry(src, home, "private_dot_ssh/config")
    os.chmod(e.source, 0o664)
    (home / ".ssh").mkdir()
    dots.set_mode(e)
    assert stat.S_IMODE(e.source.stat().st_mode) == 0o600
    assert stat.S_IMODE((home / ".ssh").stat().st_mode) == 0o700


def test_set_mode_executable_adds_user_x_only(dots, src, home):
    e = dots.Entry(src, home, "dot_local/bin/executable_hello")
    os.chmod(e.source, 0o644)
    dots.set_mode(e)
    assert stat.S_IMODE(e.source.stat().st_mode) == 0o744


def test_set_mode_plain_entry_leaves_mode_alone(dots, src, home):
    e = dots.Entry(src, home, "dot_bashrc")
    os.chmod(e.source, 0o640)
    dots.set_mode(e)
    assert stat.S_IMODE(e.source.stat().st_mode) == 0o640


# ── backup ────────────────────────────────────────────────────────────────


def test_backup_moves_target_keeping_home_relative_path(dots, src, home):
    e = dots.Entry(src, home, "dot_config/app/settings.ini")
    e.target.parent.mkdir(parents=True)
    e.target.write_text("mine")
    root = home / ".dotfiles-backup" / "ts"
    dest = dots.backup(e, root)
    assert dest == root / ".config" / "app" / "settings.ini"
    assert dest.read_text() == "mine" and not e.target.exists()


def test_backup_moves_a_symlink_not_its_referent(dots, src, home):
    e = dots.Entry(src, home, "dot_bashrc")
    (home / "real").write_text("keep")
    os.symlink(home / "real", e.target)
    dest = dots.backup(e, home / "bk")
    assert dest.is_symlink() and (home / "real").read_text() == "keep"


# ── selection and source resolution ───────────────────────────────────────


def test_selected_matches_exact_target_or_ancestor(dots, src, home):
    e = dots.Entry(src, home, "dot_config/app/settings.ini")
    assert dots.selected(e, [], home)
    assert dots.selected(e, [str(home / ".config")], home)
    assert dots.selected(e, [str(home / ".config" / "app" / "settings.ini")], home)
    assert not dots.selected(e, [str(home / ".ssh")], home)
    assert not dots.selected(e, [str(home / ".config" / "app" / "settings")], home)   # prefix, not parent


def test_source_dir_prefers_env_then_home_then_script(dots, home, monkeypatch, tmp_path):
    monkeypatch.setenv("DOTS_SOURCE", str(tmp_path / "env-src"))
    assert dots.source_dir() == (tmp_path / "env-src").resolve()   # even when absent: caller reports it
    monkeypatch.delenv("DOTS_SOURCE")
    real = tmp_path / "real"
    real.mkdir()
    os.symlink(real, home / ".dotfiles")
    assert dots.source_dir() == real                                # symlink resolved
    (home / ".dotfiles").unlink()
    assert dots.source_dir() == Path(dots.__file__).resolve().parent
