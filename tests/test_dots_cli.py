"""Interface tests: every subcommand's output, state change and exit code.

Most call main() in-process through the `run` fixture; the argparse and
process-level behavior (usage errors, --help, $DOTS_SOURCE) run the script
as a subprocess.
"""

import os
import re
import shutil
import stat

import pytest

from conftest import DOTS, REPO, run_subprocess

# ----------------------------------------------------------------------
# managed
# ----------------------------------------------------------------------


def test_managed_lists_targets_in_order(run, home):
    code, out, err = run("managed")
    assert code == 0 and err == ""
    assert out.splitlines() == [".bashrc", ".config/app/settings.ini", ".local/bin/hello", ".ssh/config"]


def test_managed_show_source(run, src, home):
    code, out, _ = run("managed", "--show-source")
    assert code == 0
    assert out.splitlines()[0] == str(src / "dot_bashrc")
    assert out.splitlines()[-1] == str(src / "private_dot_ssh" / "config")


# ----------------------------------------------------------------------
# apply
# ----------------------------------------------------------------------


def test_apply_links_everything_and_reports_count(run, src, home):
    code, out, _ = run("apply")
    assert code == 0
    assert out.splitlines() == [
        f"link      .bashrc  ->  {src / 'dot_bashrc'}",
        f"link      .config/app/settings.ini  ->  {src / 'dot_config/app/settings.ini'}",
        f"link      .local/bin/hello  ->  {src / 'dot_local/bin/executable_hello'}",
        f"link      .ssh/config  ->  {src / 'private_dot_ssh/config'}",
        "4 change(s)",
    ]
    assert os.readlink(home / ".bashrc") == str(src / "dot_bashrc")
    assert (home / ".config" / "app").is_dir() and not (home / ".config" / "app").is_symlink()
    assert stat.S_IMODE((home / ".ssh").stat().st_mode) == 0o700
    assert stat.S_IMODE((src / "private_dot_ssh" / "config").stat().st_mode) & 0o077 == 0
    assert (src / "dot_local" / "bin" / "executable_hello").stat().st_mode & stat.S_IXUSR


def test_apply_second_run_changes_nothing(run, home):
    run("apply")
    code, out, _ = run("apply")
    assert (code, out) == (0, "0 change(s)\n")


def test_apply_dry_run_prints_plan_and_touches_nothing(run, home):
    code, out, _ = run("apply", "--dry-run")
    assert code == 0
    assert out.startswith("link      .bashrc  ->  ")
    assert out.endswith("4 change(s) (dry run)\n")
    assert list(home.iterdir()) == []


def test_apply_conflict_without_force_is_reported_and_exits_1(run, home):
    (home / ".bashrc").write_text("mine\n")
    code, out, _ = run("apply")
    assert code == 1
    assert "conflict  .bashrc  (use --force to back it up and replace)" in out
    assert out.endswith("3 change(s), 1 conflict(s) left\n")
    assert (home / ".bashrc").read_text() == "mine\n"


def test_apply_force_backs_up_then_links(run, src, home):
    (home / ".bashrc").write_text("mine\n")
    code, out, _ = run("apply", "--force")
    assert code == 0
    lines = out.splitlines()
    assert lines[0] == f"replace   .bashrc  ->  {src / 'dot_bashrc'}"
    assert lines[1].startswith(f"backup    .bashrc  ->  {home / '.dotfiles-backup'}/")
    assert lines[1].endswith("/.bashrc")
    assert os.readlink(home / ".bashrc") == str(src / "dot_bashrc")
    backups = list((home / ".dotfiles-backup").glob("*/.bashrc"))
    assert len(backups) == 1 and backups[0].read_text() == "mine\n"


def test_apply_force_dry_run_shows_replace_but_keeps_file(run, home):
    (home / ".bashrc").write_text("mine\n")
    code, out, _ = run("apply", "--force", "-n")
    assert code == 0
    assert "replace   .bashrc" in out and "backup" not in out
    assert (home / ".bashrc").read_text() == "mine\n"


def test_apply_foreign_symlink_is_a_conflict_and_the_link_is_what_gets_backed_up(run, src, home):
    (home / "elsewhere").write_text("other\n")
    os.symlink(home / "elsewhere", home / ".bashrc")
    code, out, _ = run("apply")
    assert code == 1 and "conflict  .bashrc" in out
    code, _, _ = run("apply", "--force")
    assert code == 0
    assert os.readlink(home / ".bashrc") == str(src / "dot_bashrc")
    assert (home / "elsewhere").read_text() == "other\n"
    backed = next((home / ".dotfiles-backup").glob("*/.bashrc"))
    assert backed.is_symlink() and os.readlink(backed) == str(home / "elsewhere")


def test_apply_relinks_a_stale_link(run, src, home):
    run("apply")
    shutil.move(str(src / "dot_bashrc"), str(src / "dot_bashrc.old"))
    (src / "dot_bashrc").write_text("# new\n")
    os.remove(home / ".bashrc")
    os.symlink(src / "dot_bashrc.old", home / ".bashrc")
    code, out, _ = run("apply")
    assert code == 0
    assert out.splitlines()[0] == f"relink    .bashrc  ->  {src / 'dot_bashrc'}"
    assert os.readlink(home / ".bashrc") == str(src / "dot_bashrc")


def test_apply_restricted_to_paths(run, home):
    code, out, _ = run("apply", str(home / ".config"), str(home / ".ssh/config"))
    assert code == 0 and out.endswith("2 change(s)\n")
    assert (home / ".config" / "app" / "settings.ini").is_symlink()
    assert (home / ".ssh" / "config").is_symlink()
    assert not (home / ".bashrc").exists()


def test_apply_reasserts_modes_on_already_linked_files(run, src, home):
    run("apply")
    os.chmod(src / "private_dot_ssh" / "config", 0o644)
    run("apply")
    assert stat.S_IMODE((src / "private_dot_ssh" / "config").stat().st_mode) == 0o600


# ----------------------------------------------------------------------
# status
# ----------------------------------------------------------------------


def test_status_lists_problems_with_summary_and_exit_1(run, home):
    (home / ".bashrc").write_text("mine\n")
    code, out, _ = run("status")
    assert code == 1
    assert out.splitlines() == [
        "conflict    .bashrc",
        "missing     .config/app/settings.ini",
        "missing     .local/bin/hello",
        "missing     .ssh/config",
        "conflict: 1  missing: 3",
    ]


def test_status_all_ok_is_one_line_and_exit_0(run, home):
    run("apply")
    assert run("status") == (0, "ok: 4\n", "")


def test_status_all_flag_lists_ok_targets_too(run, home):
    run("apply")
    code, out, _ = run("status", "--all")
    assert code == 0
    assert out.splitlines()[:2] == ["ok          .bashrc", "ok          .config/app/settings.ini"]


def test_status_nothing_managed(run, tmp_path, home):
    empty = tmp_path / "empty"
    empty.mkdir()
    assert run("status", source=empty) == (0, "nothing managed\n", "")


def test_status_restricted_to_a_path(run, home):
    assert run("status", str(home / ".ssh")) == (1, "missing     .ssh/config\nmissing: 1\n", "")


# ----------------------------------------------------------------------
# unlink
# ----------------------------------------------------------------------


def test_unlink_removes_only_our_links(run, src, home):
    run("apply")
    (home / "elsewhere").write_text("other\n")
    os.remove(home / ".bashrc")
    os.symlink(home / "elsewhere", home / ".bashrc")
    code, out, _ = run("unlink")
    assert code == 0
    assert out.splitlines() == [
        "unlink    .config/app/settings.ini",
        "unlink    .local/bin/hello",
        "unlink    .ssh/config",
        "3 link(s) removed",
    ]
    assert (home / ".bashrc").is_symlink()
    assert not (home / ".ssh" / "config").exists() and (home / ".ssh").is_dir()
    assert (src / "private_dot_ssh" / "config").exists()


def test_unlink_dry_run(run, home):
    run("apply")
    code, out, _ = run("unlink", "-n", str(home / ".bashrc"))
    assert (code, out) == (0, "unlink    .bashrc\n1 link(s) removed (dry run)\n")
    assert (home / ".bashrc").is_symlink()


# ----------------------------------------------------------------------
# add
# ----------------------------------------------------------------------


def test_add_moves_files_and_infers_attributes(run, src, home):
    (home / ".config" / "tool").mkdir(parents=True)
    (home / ".config" / "tool" / "rc").write_text("x\n")
    (home / ".secret").write_text("s\n")
    os.chmod(home / ".secret", 0o600)
    (home / ".local" / "bin").mkdir(parents=True)
    (home / ".local" / "bin" / "tool").write_text("#!/bin/sh\n")
    os.chmod(home / ".local" / "bin" / "tool", 0o755)
    code, out, _ = run("add", str(home / ".config/tool/rc"), str(home / ".secret"),
                       str(home / ".local/bin/tool"))
    assert code == 0
    assert out.splitlines() == [
        "add       .config/tool/rc  ->  dot_config/tool/rc",
        "add       .secret  ->  private_dot_secret",
        "add       .local/bin/tool  ->  dot_local/bin/executable_tool",
    ]
    assert (src / "dot_config" / "tool" / "rc").read_text() == "x\n"
    assert os.readlink(home / ".config" / "tool" / "rc") == str(src / "dot_config" / "tool" / "rc")
    assert (home / ".secret").is_symlink() and (home / ".local/bin/tool").is_symlink()
    code, out, _ = run("status")
    assert code == 1 and out.endswith("missing: 4  ok: 3\n")


def test_add_infers_private_under_a_umask_closed_to_others(run, src, home):
    # under umask 027 a new file is rw-r-----: no bits for others, so private_
    os.umask(0o027)
    (home / ".token").write_text("t\n")
    assert run("add", str(home / ".token")) == (0, "add       .token  ->  private_dot_token\n", "")


def test_add_under_a_private_directory_goes_into_that_source_directory(run, src, home):
    # ~/.ssh is private_dot_ssh/ in the source; a new dot_ssh/ beside it
    # would be a second source directory for the same target
    (home / ".ssh").mkdir()
    (home / ".ssh" / "known_hosts").write_text("h\n")
    os.chmod(home / ".ssh" / "known_hosts", 0o644)
    code, out, _ = run("add", str(home / ".ssh/known_hosts"))
    assert (code, out) == (0, "add       .ssh/known_hosts  ->  private_dot_ssh/known_hosts\n")
    assert (src / "private_dot_ssh" / "known_hosts").read_text() == "h\n"
    assert not (src / "dot_ssh").exists()


def test_add_refuses_names_that_start_with_an_attribute_prefix(run, src, home):
    # stored under its own name, ~/private_notes would be the source of ~/notes
    (home / "private_notes").write_text("n\n")
    (home / "bin").mkdir()
    (home / "bin" / "dot_env").write_text("e\n")
    code, out, _ = run("add", str(home / "private_notes"), str(home / "bin/dot_env"))
    assert (code, out) == (0, "skip      private_notes: a name starts with dot_, private_ or executable_\n"
                              "skip      bin/dot_env: a name starts with dot_, private_ or executable_\n")
    assert sorted(p.name for p in src.iterdir()) == [".dotsignore", ".git", "README.md", "dot_bashrc",
                                                     "dot_config", "dot_local", "private_dot_ssh"]
    assert not (home / "private_notes").is_symlink()


def test_add_refuses_paths_the_dotsignore_excludes(run, src, home):
    # stored there, ~/docs/plan.txt would sit in the repository's docs/ and never be linked
    (src / ".dotsignore").write_text("README.md\ndocs\n")
    (home / "docs").mkdir()
    (home / "docs" / "plan.txt").write_text("p\n")
    code, out, _ = run("add", str(home / "docs" / "plan.txt"))
    assert (code, out) == (0, "skip      docs/plan.txt: ignored by .dotsignore\n")
    assert not (src / "docs").exists()
    assert not (home / "docs" / "plan.txt").is_symlink()


def test_add_private_flag_forces_the_attribute(run, src, home):
    (home / ".token").write_text("t\n")          # 644: would not be private on its own
    code, out, _ = run("add", "--private", str(home / ".token"))
    assert (code, out) == (0, "add       .token  ->  private_dot_token\n")
    assert (src / "private_dot_token").exists()


def test_add_dry_run_moves_nothing(run, src, home):
    (home / ".token").write_text("t\n")
    code, out, _ = run("add", "-n", str(home / ".token"))
    assert (code, out) == (0, "add       .token  ->  dot_token\n")
    assert not (home / ".token").is_symlink() and not (src / "dot_token").exists()


def test_add_relative_path_is_resolved_against_cwd(run, src, home, monkeypatch):
    (home / ".token").write_text("t\n")
    monkeypatch.chdir(home)
    assert run("add", ".token") == (0, "add       .token  ->  dot_token\n", "")


def test_add_skips_symlinks_directories_outsiders_and_existing(run, src, home, tmp_path):
    run("apply")
    (home / "dir").mkdir()
    outside = tmp_path / "outside"
    outside.write_text("o\n")
    (home / ".bashrc.new").write_text("n\n")
    (src / "dot_bashrc.new").write_text("already\n")
    code, out, _ = run("add", str(home / ".bashrc"), str(home / "dir"), str(outside),
                       str(home / ".bashrc.new"))
    assert code == 0
    assert out.splitlines() == [
        "skip      .bashrc: already a symlink",
        "skip      dir: not a regular file (add files, not directories)",
        f"skip      {outside}: not under {home}",
        f"skip      .bashrc.new: {src / 'dot_bashrc.new'} already exists",
    ]
    assert (src / "dot_bashrc.new").read_text() == "already\n"


# ----------------------------------------------------------------------
# forget
# ----------------------------------------------------------------------


def test_forget_leaves_a_real_copy_and_removes_the_source(run, src, home):
    run("apply")
    code, out, _ = run("forget", str(home / ".bashrc"))
    assert (code, out) == (0, "forget    .bashrc\n")
    assert not (home / ".bashrc").is_symlink()
    assert (home / ".bashrc").read_text() == "# bashrc\n"
    assert not (src / "dot_bashrc").exists()
    assert ".bashrc" not in run("managed")[1]


def test_forget_missing_target_gets_the_copy(run, src, home):
    code, out, _ = run("forget", str(home / ".bashrc"), str(home / ".ssh" / "config"))
    assert (code, out) == (0, "forget    .bashrc\nforget    .ssh/config\n")
    assert (home / ".bashrc").read_text() == "# bashrc\n"
    assert not (src / "dot_bashrc").exists()
    assert stat.S_IMODE((home / ".ssh").stat().st_mode) == 0o700
    assert stat.S_IMODE((home / ".ssh" / "config").stat().st_mode) & 0o077 == 0


def test_forget_stale_link_is_replaced_by_the_copy(run, src, home):
    (home / ".bashrc").symlink_to(src / "dot_bashrc.old")
    code, out, _ = run("forget", str(home / ".bashrc"))
    assert (code, out) == (0, "forget    .bashrc\n")
    assert not (home / ".bashrc").is_symlink()
    assert (home / ".bashrc").read_text() == "# bashrc\n"
    assert not (src / "dot_bashrc").exists()



def test_forget_dry_run(run, src, home):
    run("apply")
    code, out, _ = run("forget", "-n", str(home / ".bashrc"))
    assert (code, out) == (0, "forget    .bashrc\n")
    assert (home / ".bashrc").is_symlink() and (src / "dot_bashrc").exists()


def test_forget_unmanaged_path_is_skipped_with_exit_1(run, src, home):
    code, out, _ = run("forget", str(home / ".nope"), str(home / ".bashrc"))
    assert code == 1
    assert out == f"forget    .bashrc\nskip      {home / '.nope'}: not managed\n"


@pytest.mark.parametrize("cmd, last", [("apply", "1 change(s)"), ("status", "missing: 1"),
                                       ("unlink", "0 link(s) removed")])
def test_a_path_that_selects_nothing_is_skipped_with_exit_1(run, home, cmd, last):
    code, out, _ = run(cmd, str(home / ".bashrcx"), str(home / ".bashrc"))
    skip = f"skip      {home / '.bashrcx'}: not managed"
    assert (code, out.splitlines()[-2:]) == (1, [skip, last])


def test_status_of_an_ok_target_and_a_typo_exits_1(run, home):
    run("apply")
    code, out, _ = run("status", str(home / ".bashrcx"), str(home / ".bashrc"))
    assert (code, out) == (1, f"skip      {home / '.bashrcx'}: not managed\nok: 1\n")


def test_a_directory_path_that_holds_a_target_is_not_skipped(run, home):
    code, out, _ = run("apply", "-n", str(home / ".config") + "/")
    assert (code, "skip" in out) == (0, False)


# ----------------------------------------------------------------------
# process-level behavior
# ----------------------------------------------------------------------


def test_no_subcommand_is_a_usage_error(home, src):
    proc = run_subprocess(home, src)
    assert proc.returncode == 2
    assert "usage: dots" in proc.stderr and "required: cmd" in proc.stderr


def test_unknown_subcommand(home, src):
    proc = run_subprocess(home, src, "frobnicate")
    assert proc.returncode == 2
    assert "invalid choice: 'frobnicate'" in proc.stderr


def test_add_and_forget_require_a_path(home, src):
    for cmd in ("add", "forget"):
        proc = run_subprocess(home, src, cmd)
        assert proc.returncode == 2, cmd
        assert "the following arguments are required: paths" in proc.stderr


def test_help_lists_every_subcommand(home, src):
    proc = run_subprocess(home, src, "--help")
    assert proc.returncode == 0
    assert "{apply,status,managed,add,forget,unlink,prune,options,fast}" in proc.stdout
    assert "dot_config/git/config" in proc.stdout           # the naming spec from the docstring


def test_missing_source_directory_in_process(dots, home, tmp_path, capsys):
    assert dots.main(["-S", str(tmp_path / "nope"), "managed"]) == 2
    assert capsys.readouterr().err == f"dots: source directory {tmp_path / 'nope'} does not exist\n"


def test_missing_source_directory_exits_2(home, tmp_path):
    proc = run_subprocess(home, tmp_path / "nope", "managed")
    assert proc.returncode == 2
    assert proc.stderr == f"dots: source directory {tmp_path / 'nope'} does not exist\n"


def test_dots_source_env_selects_the_source(home, src):
    proc = run_subprocess(home, src, "managed")
    assert proc.returncode == 0 and proc.stdout.splitlines()[0] == ".bashrc"


def test_a_checkout_manages_its_own_tree_even_with_a_home_dotfiles(home, src):
    os.symlink(src, home / ".dotfiles")
    proc = run_subprocess(home, src, "managed", "--show-source", env={"DOTS_SOURCE": ""})
    assert proc.returncode == 0
    assert proc.stdout.splitlines()[0] == str(DOTS.resolve().parent / "dot_Xresources")


def test_a_lone_dots_uses_the_home_dotfiles_symlink(home, src, tmp_path):
    import subprocess
    import sys

    lone = tmp_path / "lone"
    lone.mkdir()
    shutil.copy2(DOTS, lone / "dots")
    os.symlink(src, home / ".dotfiles")
    proc = subprocess.run([sys.executable, str(lone / "dots"), "managed", "--show-source"],
                          env=dict(os.environ, HOME=str(home), DOTS_SOURCE=""), capture_output=True, text=True)
    assert proc.returncode == 0
    assert proc.stdout.splitlines()[0] == str(src / "dot_bashrc")     # resolved through the link


def test_script_directory_is_the_last_resort_source(home, tmp_path):
    proc = run_subprocess(home, tmp_path, "managed", env={"DOTS_SOURCE": ""})
    assert proc.returncode == 0
    assert ".bashrc" in proc.stdout.splitlines()       # the repository's own tree


def test_exit_status_propagates_from_main(home, src):
    (home / ".bashrc").write_text("mine\n")
    assert run_subprocess(home, src, "status").returncode == 1
    assert run_subprocess(home, src, "apply").returncode == 1
    assert run_subprocess(home, src, "apply", "--force").returncode == 0


# ----------------------------------------------------------------------
# prune
# ----------------------------------------------------------------------


@pytest.fixture
def reorganized(run, src, home):
    """A linked home after the source moved a directory and deleted a file."""
    run("apply")
    shutil.move(str(src / "dot_config" / "app"), str(src / "dot_config" / "app2"))
    (src / "dot_bashrc").unlink()
    return home


def test_prune_removes_dangling_links_into_the_source_tree(run, src, reorganized):
    home = reorganized
    code, out, _ = run("prune")
    assert code == 0
    assert out.splitlines() == [
        f"prune     .bashrc  ->  {src / 'dot_bashrc'}",
        f"prune     .config/app/settings.ini  ->  {src / 'dot_config/app/settings.ini'}",
        "2 dangling link(s) removed",
    ]
    assert not (home / ".bashrc").is_symlink() and not (home / ".config/app/settings.ini").is_symlink()
    assert (home / ".ssh" / "config").is_symlink()             # still a valid target


def test_prune_dry_run(run, src, reorganized):
    home = reorganized
    code, out, _ = run("prune", "-n")
    assert code == 0 and out.endswith("2 dangling link(s) removed (dry run)\n")
    assert (home / ".bashrc").is_symlink()


def test_prune_leaves_links_that_resolve_or_point_elsewhere(run, src, home):
    run("apply")
    (src / "README.md").write_text("docs\n")                    # ignored, but someone linked it by hand
    os.symlink(src / "README.md", home / "README-link")
    os.symlink(home / "gone", home / ".config" / "broken-foreign")   # dangling, not ours
    code, out, _ = run("prune")
    assert (code, out) == (0, "0 dangling link(s) removed\n")
    assert (home / "README-link").is_symlink() and (home / ".config" / "broken-foreign").is_symlink()


def test_prune_does_not_descend_into_unmanaged_top_level_directories(run, src, home):
    run("apply")
    (home / ".cache").mkdir()
    os.symlink(src / "nope", home / ".cache" / "stale")
    assert run("prune")[1] == "0 dangling link(s) removed\n"
    assert (home / ".cache" / "stale").is_symlink()


def test_prune_with_nothing_managed(run, tmp_path, home):
    empty = tmp_path / "empty"
    empty.mkdir()
    assert run("prune", source=empty) == (0, "0 dangling link(s) removed\n", "")


# ----------------------------------------------------------------------
# options
# ----------------------------------------------------------------------


@pytest.fixture
def configured(src):
    """Two files in the options format and one that does not declare it."""
    (src / "dot_bashrc").write_text(
        "# dots options\n\n# Append to history.\nshopt -s histappend\n\n"
        "# Verify history expansions.\n#   Costs an extra Enter.\n#shopt -s histverify\n\n#shopt -s bare\n")
    (src / "dot_vimrc").write_text('" dots options\n\n" Relative numbers.\n"set relativenumber\n')
    (src / "dot_config" / "app" / "settings.ini").write_text("# Not in the format.\nx = 1\n")
    return src


def test_options_lists_every_described_setting_by_file(run, configured):
    code, out, err = run("options")
    assert (code, err) == (0, "")
    assert out.splitlines() == [
        "~/.bashrc",
        "     4  on   Append to history.",
        "     8  off  Verify history expansions.",
        "~/.vimrc",
        "     4  off  Relative numbers.",
    ]


def test_options_words_must_all_match_file_description_or_code(run, configured):
    assert run("options", "HISTORY", "extra")[1] == "~/.bashrc\n     8  off  Verify history expansions.\n"
    assert run("options", "vimrc")[1] == "~/.vimrc\n     4  off  Relative numbers.\n"
    assert run("options", "histappend")[1] == "~/.bashrc\n     4  on   Append to history.\n"


def test_options_state_filters(run, configured):
    assert run("options", "--on")[1] == "~/.bashrc\n     4  on   Append to history.\n"
    assert [l for l in run("options", "--off")[1].splitlines() if " on " in l] == []


def test_options_full_prints_the_rest_of_the_description_and_the_code(run, configured):
    code, out, _ = run("options", "--full", "verify")
    assert out.splitlines() == [
        "~/.bashrc",
        "     8  off  Verify history expansions.",
        "             Costs an extra Enter.",
        "             #shopt -s histverify",
    ]


def test_options_nothing_matched_exits_1(run, configured):
    assert run("options", "no-such-word") == (1, "", "")


def test_options_skips_binary_files(run, configured):
    (configured / "dot_blob").write_bytes(b"\xff\xfe dots options \x00")
    assert run("options", "--off")[0] == 0


def test_options_on_and_off_together_is_a_usage_error(home, src):
    proc = run_subprocess(home, src, "options", "--on", "--off")
    assert proc.returncode == 2 and "not allowed with argument" in proc.stderr


# ----------------------------------------------------------------------
# fast
# ----------------------------------------------------------------------


@pytest.fixture
def no_fast_env(monkeypatch, tmp_path):
    """No DOTS_FAST* from the caller, and samples kept in the test's own tmpfs stand-in"""
    for var in [v for v in os.environ if v.startswith("DOTS_FAST")]:
        monkeypatch.delenv(var)
    run_dir = tmp_path / "run"
    run_dir.mkdir(mode=0o700)
    monkeypatch.setenv("XDG_RUNTIME_DIR", str(run_dir))


def test_fast_writes_the_mode_and_reset_removes_it(run, home, no_fast_env):
    setting = home / ".config/bash/fast"
    assert run("fast", "auto") == (0, f"fast mode: auto in {setting}\n", "")
    assert setting.read_text() == "auto\n"
    assert run("fast", "on")[0] == 0 and setting.read_text() == "on\n"
    assert run("fast", "reset") == (0, f"fast mode: {setting} removed\n", "")
    assert not setting.exists()
    assert run("fast", "reset")[0] == 0


def test_fast_keeps_the_setting_under_xdg_config_home(run, home, tmp_path, monkeypatch, no_fast_env):
    monkeypatch.setenv("XDG_CONFIG_HOME", str(tmp_path / "xdg"))
    run("fast", "off")
    assert (tmp_path / "xdg/bash/fast").read_text() == "off\n"
    assert not (home / ".config").exists()
    lines = run_subprocess(home, REPO, "fast").stdout.splitlines()
    assert lines[0] == f"fast mode  off ({tmp_path}/xdg/bash/fast)"


def test_fast_says_when_the_environment_overrides_the_file(run, home, monkeypatch, no_fast_env):
    monkeypatch.setenv("DOTS_FAST", "off")
    out = run("fast", "on")[1]
    assert out.splitlines()[1] == "fast mode: DOTS_FAST=off in the environment overrides it"


def test_fast_rejects_a_mode_it_does_not_know(home, src):
    proc = run_subprocess(home, src, "fast", "maybe")
    assert proc.returncode == 2 and "invalid choice: 'maybe'" in proc.stderr


def test_fast_with_no_mode_reports_the_mode_and_each_signal(home, no_fast_env):
    proc = run_subprocess(home, REPO, "fast")
    assert proc.returncode == 0, proc.stderr
    lines = proc.stdout.splitlines()
    assert lines[0] == f"fast mode  off (default: no {home}/.config/bash/fast)"
    assert [line.split()[0] for line in lines[1:7]] == ["blocked", "iowait", "load", "steal", "mem", "swapin"]
    assert lines[7] == "paths      none (DOTS_FAST_PATHS)"
    assert lines[8] == "samples    none yet on " + os.uname().nodename.split(".")[0]


def test_fast_report_lists_the_samples_and_why_auto_stays_on(home, no_fast_env):
    calm = ("DOTS_FAST_BLOCKED=99999 DOTS_FAST_IOWAIT=101 DOTS_FAST_LOAD=99999 DOTS_FAST_STEAL=101 "
            "DOTS_FAST_MEM=0 DOTS_FAST_SWAPIN=99999999\n")
    (home / ".bashrc.before").write_text(calm)
    (home / ".config/bash").mkdir(parents=True)
    (home / ".config/bash/fast").write_text("auto\n")
    files = home.parent / "xdg-run" / f"dots-fast.{os.uname().nodename.split('.')[0]}"   # fast_mode_apart's
    files.parent.mkdir(mode=0o700, exist_ok=True)
    files.with_name(files.name + ".ring").write_text("git 340 1\nstartup 100 0\ngit 10 0\n")
    files.with_name(files.name + ".state").write_text("on\n")
    lines = run_subprocess(home, REPO, "fast").stdout.splitlines()
    assert lines[:2] == [f"fast mode  auto, on now ({home}/.config/bash/fast)",
                         "reason     staying on: 1 of the last 3 samples slow, off once 10 in a row are fast"]
    assert not any(line.endswith("!") for line in lines[2:8])
    assert lines[9:] == ["samples    1 of the last 5 slow (on at 2), 1 of the last 3 (off at 0 of 10)",
                         "  git         340 ms  !",
                         "  startup     100 ms",
                         "  git          10 ms",
                         "           startup at 300 ms (DOTS_FAST_STARTUP_MS), git at 200 ms (DOTS_FAST_GIT_MS)"]


def test_fast_report_says_when_the_directory_is_under_dots_fast_paths(home, no_fast_env):
    (home / ".bashrc.before").write_text('DOTS_FAST_PATHS="~/none:$PWD/"\n')
    lines = run_subprocess(home, REPO, "fast").stdout.splitlines()
    assert lines[7:9] == [f"paths      ~/none:{os.getcwd()}/ (DOTS_FAST_PATHS)",
                          f"           {os.getcwd()} is under one: fast-dir"]
    (home / ".bashrc.before").write_text('DOTS_FAST_PATHS="$PWD/elsewhere"\n')
    lines = run_subprocess(home, REPO, "fast").stdout.splitlines()
    assert lines[8].startswith("samples ")


def test_fast_report_exits_with_the_status_of_its_bash(dots, home, no_fast_env, capfd):
    assert dots.main(["-S", str(REPO), "fast"]) == 0
    assert capfd.readouterr().out.startswith("fast mode  off (default: ")
    assert dots.main(["-S", str(home), "fast"]) == 1          # no module there: source fails
    assert "05-fast.sh: No such file or directory" in capfd.readouterr().err


def test_fast_auto_reports_a_threshold_from_bashrc_before_as_the_reason(home, no_fast_env):
    (home / ".bashrc.before").write_text("DOTS_FAST_MEM=100\n")
    run_subprocess(home, REPO, "fast", "auto")
    proc = run_subprocess(home, REPO, "fast")
    lines = proc.stdout.splitlines()
    assert lines[0] == f"fast mode  auto, on now ({home}/.config/bash/fast)"
    assert re.fullmatch(r"reason     mem \d+% <= 100", lines[1])
    mem = next(line for line in lines if line.startswith("mem "))
    assert mem.endswith("at 100% or less (DOTS_FAST_MEM)  !")


# ----------------------------------------------------------------------
# dots on PATH, and its completion
# ----------------------------------------------------------------------

COMPLETION = REPO / "dot_local/share/bash-completion/completions/dots"


def apply_local(home):
    """`dots apply ~/.local` from the repository, as a first install runs it."""
    import subprocess

    return subprocess.run([str(REPO / "dots"), "-S", str(REPO), "apply", ".local"],
                          env={"HOME": str(home), "PATH": "/usr/bin:/bin"},
                          capture_output=True, text=True, cwd=home)


def linked_dots(home, *args):
    """The installed link run by name, with no DOTS_SOURCE and no ~/.dotfiles."""
    import subprocess
    import sys

    path = f"{home}/.local/bin:{os.path.dirname(sys.executable)}:/usr/bin:/bin"
    return subprocess.run(["dots", *args], env={"HOME": str(home), "PATH": path},
                          capture_output=True, text=True)


def test_apply_links_dots_into_local_bin_and_it_runs_this_checkout(home):
    proc = apply_local(home)
    assert proc.returncode == 0, proc.stderr
    assert os.readlink(home / ".local/bin/dots") == str(REPO / "dot_local/bin/dots")
    assert os.readlink(home / ".local/share/bash-completion/completions/dots") == str(COMPLETION)
    managed = linked_dots(home, "managed")
    assert (managed.returncode, managed.stdout.splitlines()[0]) == (0, ".Xresources")


def test_apply_repairs_the_link_an_old_install_sh_made(home):
    (home / ".local/bin").mkdir(parents=True)
    os.symlink(REPO / "dots", home / ".local/bin/dots")
    assert apply_local(home).returncode == 0
    assert os.readlink(home / ".local/bin/dots") == str(REPO / "dot_local/bin/dots")


def test_unlink_uninstalls_dots_and_its_completion(home):
    apply_local(home)
    proc = linked_dots(home, "unlink", str(home / ".local"))
    assert proc.returncode == 0, proc.stderr
    assert not (home / ".local/bin/dots").is_symlink()
    assert not (home / ".local/share/bash-completion/completions/dots").is_symlink()


def complete(tmp_path, *words):
    """What _dots offers for the command line WORDS, the last being the one
    under the cursor."""
    import subprocess

    script = (f"source {COMPLETION}\nCOMP_WORDS=(\"$@\"); COMP_CWORD=$(($# - 1))\n"
              "_dots; printf '%s\\n' \"${COMPREPLY[@]}\"\n")
    proc = subprocess.run(["bash", "-c", script, "bash", "dots", *words], capture_output=True,
                          text=True, cwd=tmp_path)
    assert proc.stderr == ""
    return proc.stdout.split()


@pytest.mark.parametrize("words, offered", [
    ((""), ["apply", "status", "managed", "add", "forget", "unlink", "prune", "options", "fast"]),
    (("ap",), ["apply"]),
    (("-",), ["-S", "--source", "-h", "--help"]),
    (("apply", "-"), ["-n", "--dry-run", "--force", "-h", "--help"]),
    (("options", "--o"), ["--on", "--off"]),
    (("-S", "somewhere", "a"), ["apply", "add"]),
    (("--source", "s"), ["srcdir"]),
    (("managed", ""), ["-s", "--show-source", "-h", "--help"]),
    (("apply", ""), []),
    (("nosuch", "-"), []),
    (("fast", ""), ["on", "off", "auto", "reset"]),
    (("fast", "-"), ["-h", "--help"]),
], ids=lambda value: " ".join(value) if isinstance(value, tuple) else None)
def test_completion_offers(tmp_path, words, offered):
    (tmp_path / "srcdir").mkdir()
    (tmp_path / "somefile").write_text("")
    words = words if isinstance(words, tuple) else (words,)
    assert complete(tmp_path, *words) == offered
