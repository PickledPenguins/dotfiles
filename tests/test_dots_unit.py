"""Unit tests for the functions in `dots`, called directly."""

import os
import random
import stat
import string
from pathlib import Path

import pytest

# ----------------------------------------------------------------------
# naming
# ----------------------------------------------------------------------


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


RESERVED = ("dot_", "private_", "executable_")


def test_source_name_then_parse_name_round_trips_generated_paths(dots):
    """Property: every target path survives source_name -> parse_name unchanged,
    except one with a component that starts with a reserved prefix, which
    is exactly the case add refuses."""
    rng = random.Random(1234)
    alphabet = string.ascii_letters + string.digits + "-_."
    reserved_seen = 0
    for _ in range(500):
        parts = []
        for _ in range(rng.randint(1, 4)):
            body = "".join(rng.choice(alphabet) for _ in range(rng.randint(1, 8))).strip(".") or "x"
            if rng.random() < 0.1:
                body = rng.choice(RESERVED) + body
            parts.append(("." if rng.random() < 0.5 else "") + body)
        rel = "/".join(parts)
        if any(p.startswith(RESERVED) for p in parts):
            reserved_seen += 1
            source = dots.source_name(rel, False, False)
            assert "/".join(dots.parse_name(c)[0] for c in source.parts) != rel, source
            continue
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
    assert reserved_seen > 20


# ----------------------------------------------------------------------
# ignores
# ----------------------------------------------------------------------


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


# ----------------------------------------------------------------------
# entries
# ----------------------------------------------------------------------


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


def test_managed_entries_refuses_two_sources_with_one_target(dots, src, home, capsys):
    (src / "private_dot_bashrc").write_text("")
    with pytest.raises(SystemExit) as raised:
        dots.managed_entries(src, home)
    assert raised.value.code == 2
    assert capsys.readouterr().err == "dots: dot_bashrc and private_dot_bashrc both map to .bashrc; remove one\n"


def test_managed_entries_empty_source(dots, tmp_path, home):
    assert dots.managed_entries(tmp_path, home) == []


# ----------------------------------------------------------------------
# state
# ----------------------------------------------------------------------


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


# ----------------------------------------------------------------------
# modes
# ----------------------------------------------------------------------


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


# ----------------------------------------------------------------------
# backup
# ----------------------------------------------------------------------


def test_backup_moves_target_keeping_home_relative_path(dots, src, home):
    e = dots.Entry(src, home, "dot_config/app/settings.ini")
    e.target.parent.mkdir(parents=True)
    e.target.write_text("mine")
    root = home / ".dotfiles-backup" / "ts"
    dest = dots.backup(e.target, e.rel, root)
    assert dest == root / ".config" / "app" / "settings.ini"
    assert dest.read_text() == "mine" and not e.target.exists()


def test_backup_moves_a_symlink_not_its_referent(dots, src, home):
    e = dots.Entry(src, home, "dot_bashrc")
    (home / "real").write_text("keep")
    os.symlink(home / "real", e.target)
    dest = dots.backup(e.target, e.rel, home / "bk")
    assert dest.is_symlink() and (home / "real").read_text() == "keep"


# ----------------------------------------------------------------------
# selection and source resolution
# ----------------------------------------------------------------------


def test_selected_matches_exact_target_or_ancestor(dots, src, home):
    e = dots.Entry(src, home, "dot_config/app/settings.ini")
    assert dots.selected(e, [])
    assert dots.selected(e, [str(home / ".config")])
    assert dots.selected(e, [str(home / ".config" / "app" / "settings.ini")])
    assert not dots.selected(e, [str(home / ".ssh")])
    assert not dots.selected(e, [str(home / ".config" / "app" / "settings")])   # prefix, not parent


def test_source_dir_prefers_env_then_own_tree_then_home_then_script(dots, home, monkeypatch, tmp_path):
    monkeypatch.setenv("DOTS_SOURCE", str(tmp_path / "env-src"))
    assert dots.source_dir() == (tmp_path / "env-src").resolve()   # even when absent: caller reports it
    monkeypatch.delenv("DOTS_SOURCE")
    real = tmp_path / "real"
    real.mkdir()
    os.symlink(real, home / ".dotfiles")
    assert dots.source_dir() == Path(dots.__file__).resolve().parent   # a checkout manages itself
    lone = tmp_path / "lone"
    lone.mkdir()
    monkeypatch.setattr(dots, "__file__", str(lone / "dots"))       # no .dotsignore beside it
    assert dots.source_dir() == real                                # symlink resolved
    (home / ".dotfiles").unlink()
    assert dots.source_dir() == lone


# ----------------------------------------------------------------------
# the options format
# ----------------------------------------------------------------------


@pytest.mark.parametrize("rel, marker", [
    (".vimrc", '"'), (".vim/rc/10-ui.vim", '"'), (".vim/rc/60-plugins.vim.off", '"'), (".Xresources", "!"),
    (".bashrc", "#"), (".config/git/core.gitconfig", "#"), (".vimrc.local", "#"), ("vim", "#"),
])
def test_comment_marker(dots, rel, marker):
    assert dots.comment_marker(rel) == marker


def options(dots, text, marker="#"):
    return [(o.line, o.state, o.doc, o.code) for o in dots.parse_options(text, marker)]


def test_parse_options_description_attaches_to_the_code_below(dots):
    text = "# Append, never overwrite.\n#   Details.\nshopt -s histappend\n"
    assert options(dots, text) == [(3, "on", ["Append, never overwrite.", "Details."], ["shopt -s histappend"])]


def test_parse_options_marker_then_code_is_off_marker_then_space_is_description(dots):
    text = "# Verify expansions.\n#shopt -s histverify\n"
    assert options(dots, text) == [(2, "off", ["Verify expansions."], ["#shopt -s histverify"])]


def test_parse_options_multi_line_setting_keeps_its_indented_lines(dots):
    text = "# A function.\n#f() {\n    #echo hi\n#}\n\n# On.\nif x; then\n    y\nfi\n"
    assert options(dots, text) == [
        (2, "off", ["A function."], ["#f() {", "    #echo hi", "#}"]),
        (7, "on", ["On."], ["if x; then", "    y", "fi"]),
    ]


def test_parse_options_blank_line_ends_an_option_and_drops_a_dangling_description(dots):
    text = "# Section header.\n\n# Real.\nset a\n\nset b\n"
    assert options(dots, text) == [(4, "on", ["Real."], ["set a"]), (6, "on", [], ["set b"])]


def test_parse_options_state_change_without_description_starts_an_undescribed_option(dots):
    text = "# On.\nset a\n#set b\nset c\n"
    assert options(dots, text) == [(2, "on", ["On."], ["set a"]), (3, "off", [], ["#set b"]),
                                   (4, "on", [], ["set c"])]


def test_parse_options_description_between_two_settings_starts_a_new_one(dots):
    text = "[merge]\n    # Base in conflicts.\n    conflictStyle = zdiff3\n    # Refuse non-ff.\n    #ff = only\n"
    assert options(dots, text) == [(1, "on", [], ["[merge]"]),
                                   (3, "on", ["Base in conflicts."], ["    conflictStyle = zdiff3"]),
                                   (5, "off", ["Refuse non-ff."], ["    #ff = only"])]


def test_parse_options_bare_and_doubled_markers_are_description_and_shebang_is_skipped(dots):
    text = "#!/bin/bash\n#\n## Heading\n# Text.\ncode\n"
    assert options(dots, text) == [(5, "on", ["", "# Heading", "Text."], ["code"])]


def test_parse_options_shebang_only_counts_on_the_first_line(dots):
    assert options(dots, "# A bang.\n#!x\n") == [(2, "off", ["A bang."], ["#!x"])]


def test_parse_options_other_markers(dots):
    assert options(dots, '" Relative.\n"set rnu\n', '"') == [(2, "off", ["Relative."], ['"set rnu'])]
    assert options(dots, "! Size.\n!XTerm*faceSize: 12\n#define X 1\n", "!") == [
        (2, "off", ["Size."], ["!XTerm*faceSize: 12"]), (3, "on", [], ["#define X 1"])]


def test_option_summary_skips_blank_and_needs_lines(dots):
    option = dots.Option(1, ["", "Needs: delta", "Use delta.", "More."], "off")
    assert option.summary == "Use delta."
    assert dots.Option(1, ["", "Needs: delta"], "off").summary == ""
    assert dots.Option(1, ["Needs: x"], "off").summary == ""


@pytest.mark.parametrize("doc, summary", [
    (["Append.  More here."], "Append."),
    (["Wraps across", "two lines.  Then more."], "Wraps across two lines."),
    ([".. ... go up one to four directories."], ".. ... go up one to four directories."),
    (["Reads ~/.inputrc (vim's 10-ui.vim, bat) as well."], "Reads ~/.inputrc (vim's 10-ui.vim, bat) as well."),
    (["No full stop at all"], "No full stop at all"),
    (["Ends in a bracket (like this).", "Next."], "Ends in a bracket (like this)."),
    (["word " * 30], ("word " * 19).strip() + "..."),
])
def test_option_summary_is_the_first_sentence(dots, doc, summary):
    assert dots.Option(1, doc, "on").summary == summary
