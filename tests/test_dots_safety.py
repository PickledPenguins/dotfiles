"""Safety and pathological-input tests: the paths where a wrong move loses
the user's files, and inputs the naming scheme was not written for."""

import os
import stat
import time

import pytest


# ── nothing outside the plan is ever deleted ──────────────────────────────


def test_apply_never_deletes_a_real_file_without_force(run, home):
    (home / ".bashrc").write_text("mine\n")
    (home / ".ssh").mkdir()
    (home / ".ssh" / "config").write_text("Host me\n")
    run("apply")
    run("apply", "-n")
    assert (home / ".bashrc").read_text() == "mine\n"
    assert (home / ".ssh" / "config").read_text() == "Host me\n"


def test_force_keeps_every_replaced_file_in_the_backup_tree(run, home):
    (home / ".bashrc").write_text("mine\n")
    (home / ".ssh").mkdir()
    (home / ".ssh" / "config").write_text("Host me\n")
    run("apply", "--force")
    backup = next((home / ".dotfiles-backup").iterdir())
    assert (backup / ".bashrc").read_text() == "mine\n"
    assert (backup / ".ssh" / "config").read_text() == "Host me\n"


def test_force_replaces_a_directory_in_the_way_by_moving_it_whole(run, src, home):
    (home / ".bashrc").mkdir()                      # a directory where a file should be
    (home / ".bashrc" / "inner").write_text("i\n")
    code, _, _ = run("apply", "--force")
    assert code == 0
    assert os.readlink(home / ".bashrc") == str(src / "dot_bashrc")
    assert next((home / ".dotfiles-backup").glob("*/.bashrc/inner")).read_text() == "i\n"


def test_unlink_never_touches_real_files_or_foreign_links(run, home):
    (home / ".bashrc").write_text("mine\n")
    (home / "elsewhere").write_text("e\n")
    (home / ".ssh").mkdir()
    os.symlink(home / "elsewhere", home / ".ssh" / "config")
    code, out, _ = run("unlink")
    assert (code, out) == (0, "0 link(s) removed\n")
    assert (home / ".bashrc").read_text() == "mine\n"
    assert os.readlink(home / ".ssh" / "config") == str(home / "elsewhere")


def test_forget_on_a_conflicting_target_keeps_the_users_file(run, src, home):
    (home / ".bashrc").write_text("mine\n")
    code, out, _ = run("forget", str(home / ".bashrc"))
    assert (code, out) == (0, "forget    .bashrc\n")
    assert (home / ".bashrc").read_text() == "mine\n"      # not overwritten by the source copy
    assert not (src / "dot_bashrc").exists()


def test_add_refuses_a_symlink_that_points_outside_home(run, src, home, tmp_path):
    outside = tmp_path / "outside"
    outside.write_text("o\n")
    os.symlink(outside, home / ".link")
    code, out, _ = run("add", str(home / ".link"))
    assert (code, out) == (0, "skip      .link: already a symlink\n")
    assert outside.read_text() == "o\n" and not (src / "dot_link").exists()


def test_add_refuses_paths_that_escape_home_via_dotdot(run, src, home, tmp_path):
    outside = tmp_path / "outside"
    outside.write_text("o\n")
    code, out, _ = run("add", str(home / ".." / "outside"))
    assert code == 0 and out.startswith("skip      ") and "not under" in out
    assert outside.read_text() == "o\n"


# ── the home directory itself is never a target ───────────────────────────


@pytest.mark.parametrize("name", ["dot_", "private_", "executable_"])
def test_a_source_name_that_maps_to_home_is_ignored_with_a_warning(run, src, home, name):
    (src / name).write_text("bad\n")
    (home / "precious").write_text("p\n")
    code, out, err = run("apply", "--force")
    assert code == 0
    assert f"dots: ignoring {name}: maps to " in err
    assert (home / "precious").read_text() == "p\n"        # home was not moved into a backup
    assert not (home / ".dotfiles-backup").exists()


def test_a_directory_named_dot_is_ignored_with_its_contents(run, src, home):
    (src / "dot_").mkdir()
    (src / "dot_" / "x").write_text("x\n")
    code, out, err = run("managed")
    assert code == 0 and "dots: ignoring dot_/x: maps to './x'" in err
    assert "./x" not in out


# ── modes ─────────────────────────────────────────────────────────────────


def test_private_file_is_unreadable_by_others_after_apply(run, src, home):
    os.chmod(src / "private_dot_ssh" / "config", 0o666)
    run("apply")
    assert stat.S_IMODE((src / "private_dot_ssh" / "config").stat().st_mode) == 0o600
    assert stat.S_IMODE((home / ".ssh").stat().st_mode) == 0o700


@pytest.mark.parametrize("mode, prefix", [(0o644, "dot_"), (0o640, "private_dot_"), (0o600, "private_dot_")])
def test_add_infers_private_from_the_absence_of_other_bits(run, src, home, mode, prefix):
    (home / ".f").write_text("s\n")
    os.chmod(home / ".f", mode)
    code, out, _ = run("add", str(home / ".f"))
    assert out == f"add       .f  ->  {prefix}f\n"


# ── pathological names ────────────────────────────────────────────────────


def test_names_with_spaces_unicode_and_odd_characters(run, src, home):
    (src / "dot_config" / "odd dir").mkdir()
    (src / "dot_config" / "odd dir" / "naïve file (1).txt").write_text("x\n")
    (src / "dot_config" / "odd dir" / "dot_hidden's").write_text("y\n")
    code, out, _ = run("apply")
    assert code == 0
    assert (home / ".config" / "odd dir" / "naïve file (1).txt").is_symlink()
    assert (home / ".config" / "odd dir" / ".hidden's").is_symlink()


def test_deeply_nested_source(run, src, home):
    deep = src / "dot_a" / "b" / "c" / "d" / "e" / "f" / "g" / "h"
    deep.mkdir(parents=True)
    (deep / "dot_leaf").write_text("l\n")
    run("apply")
    assert (home / ".a/b/c/d/e/f/g/h/.leaf").is_symlink()


def test_empty_source_file_and_large_source_file(run, src, home):
    (src / "dot_empty").write_text("")
    (src / "dot_big").write_bytes(b"x" * (4 << 20))
    run("apply")
    assert (home / ".empty").stat().st_size == 0
    assert (home / ".big").stat().st_size == 4 << 20


def test_repeated_attribute_prefixes_are_all_consumed(run, src, home):
    (src / "private_private_dot_x").write_text("x\n")
    code, out, _ = run("managed")
    assert ".x" in out.splitlines()


def test_ignore_file_with_only_comments(run, src, home):
    (src / ".dotsignore").write_text("# nothing here\n\n")
    code, out, _ = run("managed")
    assert "README.md" in out.splitlines()


def test_unreadable_ignore_file_is_an_error_not_a_silent_apply(run, src, home):
    if os.geteuid() == 0:
        pytest.skip("root reads everything")
    os.chmod(src / ".dotsignore", 0)
    try:
        with pytest.raises(PermissionError):
            run("managed")
    finally:
        os.chmod(src / ".dotsignore", 0o644)


def test_two_forced_applies_within_one_second_do_not_collide(run, src, home, monkeypatch):
    monkeypatch.setattr(time, "strftime", lambda fmt: "fixed")
    (home / ".bashrc").write_text("one\n")
    run("apply", "--force")
    os.remove(home / ".ssh" / "config")
    (home / ".ssh" / "config").write_text("two\n")
    code, _, _ = run("apply", "--force")
    assert code == 0
    root = home / ".dotfiles-backup" / "fixed"
    assert (root / ".bashrc").read_text() == "one\n"
    assert (root / ".ssh" / "config").read_text() == "two\n"
