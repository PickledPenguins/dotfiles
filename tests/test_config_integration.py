"""The shipped configuration, applied into a temporary HOME and read by the
real programs: bash, vim, tmux, git, ssh, readline, gdb, curl, wget, python.

Each test asserts a setting that only the module under test provides, so a
module that silently fails to load is caught. Programs not installed on
the test machine skip their tests by name.
"""

import email.utils
import http.server
import os
import pty
import re
import select
import shutil
import socket
import subprocess
import threading
import time
from pathlib import Path

import pytest

from conftest import REPO, fast_mode_apart

pytestmark = pytest.mark.long

BASH_MODULES = ["env", "fast", "options", "history", "tmux-env", "path", "aliases", "functions", "arrays", "dirs",
                "completion", "prompt", "title", "conda", "python", "tools", "hpc", "local", "override"]
VIM_MODULES = ["00-general", "10-ui", "15-statusline", "20-search", "25-completion", "30-indent",
               "35-folding", "40-files", "45-filetypes", "50-keys", "52-tags", "55-netrw"]


# The runner's PATH without this checkout: a shell started before 20-path.sh
# stopped adding it still has it, and the tests check that nothing adds it.
RUNNER_PATH = ":".join(p for p in os.environ["PATH"].split(":") if p != str(REPO))


def shell_env(home, env=None):
    environment = dict(os.environ, HOME=str(home), TERM="xterm-256color", PATH=RUNNER_PATH)
    # The runner's own session (tmux pane, display, conda or venv, ssh) would
    # otherwise show in the prompt and the modules under test.
    for var in list(environment):
        if var in ("DOTFILES_DIR", "DOTFILES_BASH_DIR", "XDG_CONFIG_HOME", "XDG_STATE_HOME", "XDG_DATA_HOME",
                   "XDG_CACHE_HOME", "PROMPT_COMMAND", "TMUX",
                   "TMUX_PANE", "DISPLAY", "CONDA_DEFAULT_ENV", "CONDA_PREFIX", "VIRTUAL_ENV",
                   "SHLVL") or var.startswith("SSH_"):
            environment.pop(var)
    fast_mode_apart(environment, home)
    environment.update(env or {})
    return environment


def bash(home, script, env=None, before=None, local=None):
    if before is not None:
        (home / ".bashrc.before").write_text(before)
    if local is not None:
        (home / ".bashrc.local").write_text(local)
    proc = subprocess.run(["bash", "--rcfile", str(home / ".bashrc"), "-i", "-c", script],
                          env=shell_env(home, env), capture_output=True, text=True, cwd=str(home), errors="replace")
    proc.stderr = "\n".join(l for l in proc.stderr.splitlines()
                            if "job control" not in l and "process group" not in l)
    return proc


def needs(program):
    return pytest.mark.skipif(shutil.which(program) is None, reason=f"{program} not installed")


def stubs(tmp_path, **scripts):
    """A directory of sh scripts standing in for programs, for PATH."""
    fake = tmp_path / "fakebin"
    fake.mkdir(exist_ok=True)
    for name, body in scripts.items():
        (fake / name).write_text("#!/bin/sh\n" + body)
        os.chmod(fake / name, 0o755)
    return fake


# ----------------------------------------------------------------------
# bash
# ----------------------------------------------------------------------


def test_bashrc_loads_every_module_in_order(linked):
    proc = bash(linked, "true", env={"DOTFILES_DEBUG": "1"})
    names = [l.split()[1] for l in proc.stderr.splitlines() if l.startswith("bashrc:")]
    assert names == BASH_MODULES


def test_bashrc_loads_silently_without_debug(linked):
    proc = bash(linked, "echo ok")
    assert (proc.returncode, proc.stdout, proc.stderr) == (0, "ok\n", "")


def test_bashrc_sources_again_silently(linked):
    proc = bash(linked, "source ~/.bashrc && echo ok")
    assert (proc.returncode, proc.stdout, proc.stderr) == (0, "ok\n", "")


def test_bashrc_sourced_again_leaves_prompt_command_as_it_was(linked):
    # Stdout on a terminal, so 65-title adds its hook too. Each hook added a
    # second time put a `history -a` before the second prompt_build, which
    # then showed its 0 as the last command's exit status.
    main, side = pty.openpty()
    script = 'a=$PROMPT_COMMAND; source ~/.bashrc; printf "%s\\n" "$a" "$PROMPT_COMMAND"'
    proc = subprocess.run(["bash", "--rcfile", str(linked / ".bashrc"), "-i", "-c", script],
                          env=shell_env(linked), stdin=side, stdout=side, stderr=subprocess.PIPE,
                          cwd=str(linked))
    os.close(side)
    out = b""
    while select.select([main], [], [], 0)[0]:
        try:
            out += os.read(main, 4096)
        except OSError:                 # EIO: the terminal's other side is closed
            break
    os.close(main)
    first = "_dots_fast_cwd; _title_prompt; prompt_build; _prompt_gap; history -a"
    assert (proc.returncode, out.decode().splitlines()) == (0, [first, first])


def test_bashrc_loads_silently_with_tree_installed(linked):
    tree = linked / "bin" / "tree"
    tree.parent.mkdir(exist_ok=True)
    tree.write_text("#!/bin/sh\necho real tree \"$@\"\n")
    tree.chmod(0o755)
    proc = bash(linked, "source ~/.bashrc && tree")
    assert (proc.returncode, proc.stdout, proc.stderr) == (0, "real tree -C\n", "")


def test_bashrc_non_interactive_shell_loads_nothing(linked):
    proc = subprocess.run(["bash", "--rcfile", str(linked / ".bashrc"), "-c", "type -t mkcd || echo none"],
                          env=dict(os.environ, HOME=str(linked)), capture_output=True, text=True)
    assert proc.stdout == "none\n"


def test_disabled_file_skips_named_modules(linked):
    (linked / ".config" / "bash" / "disabled").write_text("functions  # none\n\ndirs\n")
    proc = bash(linked, "type -t mkcd || echo no-mkcd; type -t mark || echo no-mark", env={"DOTFILES_DEBUG": "1"})
    assert proc.stdout == "no-mkcd\nno-mark\n"
    assert "bashrc: skip functions" in proc.stderr and "bashrc: skip dirs" in proc.stderr


def test_disabled_file_last_line_needs_no_newline_and_runs_no_program(linked):
    (linked / ".config" / "bash" / "disabled").write_text(" func tions\t#x\ndirs")
    proc = bash(linked, "type -t mkcd || echo no-mkcd; type -t mark || echo no-mark",
                before="grep() { echo GREP >&2; }; sed() { echo SED >&2; }\n")
    assert proc.stdout == "no-mkcd\nno-mark\n"
    assert "GREP" not in proc.stderr and "SED" not in proc.stderr


def test_off_suffix_module_is_linked_but_not_loaded(linked):
    assert (linked / ".config/bash/rc.d/61-prompt-simple.sh.off").is_symlink()
    proc = bash(linked, "type -t _ps_simple_git || echo absent")
    assert proc.stdout == "absent\n"


def test_before_sets_knobs_and_local_overrides(linked):
    proc = bash(linked, "echo $HISTSIZE; alias ll; shopt autocd | cut -f2",
                before="DOTFILES_HISTSIZE=123\n", local="alias ll='echo local'\nshopt -u autocd\n")
    assert proc.stdout == "123\nalias ll='echo local'\noff\n"


def test_env_module_sets_editor_pager_and_xdg(linked):
    proc = bash(linked, 'echo "$EDITOR $PAGER $LESS $XDG_CONFIG_HOME $RIPGREP_CONFIG_PATH"')
    assert proc.stdout == (f"vim less -FRXi --mouse --wheel-lines=3 {linked}/.config"
                           f" {linked}/.config/ripgrep/config\n")


def test_env_module_keeps_systemds_own_less_options(linked):
    proc = bash(linked, 'echo "$SYSTEMD_LESS"')
    assert proc.stdout == "-FRXi --mouse --wheel-lines=3 -SMK\n"


def test_env_module_editor_knob(linked):
    assert bash(linked, 'echo $EDITOR', before="DOTFILES_EDITOR=nano\n").stdout == "nano\n"


def test_options_module_history_and_shopts(linked):
    proc = bash(linked, "echo $HISTCONTROL; shopt globstar histappend cdspell | awk '{print $2}'; "
                        "[[ $PROMPT_COMMAND == *'history -a'* ]] && echo shared")
    assert proc.stdout == "ignoreboth:erasedups\non\non\non\nshared\n"


def test_options_module_opinionated_options_default_off(linked):
    proc = bash(linked, "set -o | grep -E '^pipefail' | awk '{print $2}'; shopt dotglob | awk '{print $2}'")
    assert proc.stdout == "off\noff\n"
    proc = bash(linked, "set -o | grep -E '^noclobber' | awk '{print $2}'", local="set +o noclobber\n")
    assert proc.stdout == "off\n"


def test_options_module_limits_stay_inside_the_hard_limit():
    # The ulimit settings, on or off, under hard limits a cluster might set
    text = (REPO / "dot_config/bash/rc.d/10-options.sh").read_text()
    no_core, all_core, stack = (line.lstrip("#") for line in text.splitlines() if re.match("#?ulimit ", line))
    proc = subprocess.run(["bash", "-c", f"ulimit -Sc 0; ulimit -Hc 100; ulimit -Ss 1024; ulimit -Hs 2048; {all_core}; {stack}; "
                           f"ulimit -Sc; ulimit -Ss; {no_core}; ulimit -Sc hard; ulimit -Sc"],
                          capture_output=True, text=True)
    assert (proc.stderr, proc.stdout) == ("", "100\n2048\n100\n")


def test_path_module_prepends_private_bins_once_and_leaves_the_repository_off(linked):
    (linked / ".local" / "bin").mkdir(parents=True, exist_ok=True)
    (linked / "bin").mkdir(exist_ok=True)
    proc = bash(linked, 'tr : "\\n" <<<"$PATH"', env={"PATH": f"{linked}/.local/bin:{RUNNER_PATH}"})
    entries = proc.stdout.splitlines()
    assert entries[:2] == [f"{linked}/.local/bin", f"{linked}/bin"]
    assert entries.count(f"{linked}/.local/bin") == 1
    assert str(REPO) not in entries  # dots comes from ~/.local/bin; run-tests.sh must not


def test_path_module_toolchain_lines_follow_the_moved_homes(linked, tmp_path):
    homes = {"CARGO_HOME": "", "GOPATH": "", "NPM_CONFIG_PREFIX": "", "DENO_INSTALL_ROOT": "",
             "BUN_INSTALL": "", "CABAL_DIR": "", "PIXI_HOME": "", "DOTNET_CLI_HOME": "/.dotnet/tools"}
    tools = tmp_path / "tools"
    for name, below in homes.items():
        (tools / name / (below.strip("/") or "bin")).mkdir(parents=True)
    source = (REPO / "dot_config/bash/rc.d/20-path.sh").read_text()
    switched_on = [line.lstrip("#") for line in source.splitlines() if re.match(r'#path_append .*\$\{', line)]
    proc = bash(linked, 'tr : "\\n" <<<"$PATH"', local="\n".join(switched_on) + "\n",
                env={name: str(tools / name) for name in homes})
    found = sorted(entry for entry in proc.stdout.splitlines() if entry.startswith(str(tools)))
    assert found == sorted(str(tools / name / (below.strip("/") or "bin")) for name, below in homes.items())


def test_path_helpers_are_idempotent_and_skip_missing_dirs(linked):
    proc = bash(linked, 'path_prepend /usr; path_prepend /usr; path_append /nope/x; path_prepend /nope/y; '
                        'tr : "\\n" <<<"$PATH" | grep -c "^/usr$"; [[ $PATH == */nope/* ]] || echo skipped')
    assert proc.stdout == "1\nskipped\n"


def test_path_remove_takes_its_argument_as_a_name_not_a_pattern(linked):
    proc = bash(linked, 'PATH="/a:/b:/usr/bin"; path_remove "/[ab]"; echo "$PATH"')
    assert proc.stdout == "/a:/b:/usr/bin\n"


def test_path_module_adds_the_man_directory_once_in_a_nested_shell(linked):
    (linked / ".local/share/man").mkdir(parents=True)
    proc = bash(linked, 'bash --rcfile ~/.bashrc -i -c \'echo "$MANPATH"\' 2>/dev/null')
    assert proc.stdout == f"{linked}/.local/share/man:\n"


def test_path_clash_names_what_runs_first_and_what_it_hides(linked, tmp_path):
    fake = stubs(tmp_path, ls="", echo="", mk="", only="")
    (tmp_path / "early").mkdir()
    (tmp_path / "early" / "only").write_text("#!/bin/sh\n")
    (tmp_path / "early" / "only").chmod(0o755)
    (tmp_path / "again").symlink_to(fake)
    proc = bash(linked, f"mk() {{ :; }}; PATH={tmp_path}/early:/usr/bin:/bin; path_clash {fake}; echo $?; "
                        f"path_clash {tmp_path}/early; echo $?; PATH+=:{fake}:{tmp_path}/again; "
                        f"path_clash {fake} | grep -c again; path_clash {fake} {tmp_path}/again | grep -c '^ls:'")
    ls = shutil.which("ls", path="/usr/bin:/bin")
    assert proc.stdout == (f"echo: builtin hides {shutil.which('echo', path='/usr/bin:/bin')}, {fake}/echo\n"
                           f"ls: {ls} hides {fake}/ls\nmk: function hides {fake}/mk\n"
                           f"only: {tmp_path}/early/only hides {fake}/only\n1\n0\n0\n1\n")


def test_path_helpers_warn_of_a_clash_only_after_startup(linked, tmp_path):
    fake = stubs(tmp_path, ls="")
    ls = shutil.which("ls", path="/usr/bin:/bin")
    # .bashrc.local adds it at startup, and again at the second load.
    proc = bash(linked, f"source ~/.bashrc; path_remove {fake}; path_append {fake}; path_prepend {fake}; echo $?",
                local=f"path_append {fake}\n")
    assert proc.stdout == "0\n"
    assert proc.stderr == f"path_append: ls: {ls} hides {fake}/ls\npath_prepend: ls: {fake}/ls hides {ls}"


def test_path_knobs(linked):
    (linked / "k1").mkdir()
    (linked / "k2").mkdir()
    proc = bash(linked, 'tr : "\\n" <<<"$PATH" | head -1; tr : "\\n" <<<"$PATH" | tail -1',
                before=f"DOTFILES_PATH_PREPEND={linked}/k1\nDOTFILES_PATH_APPEND={linked}/k2\n")
    assert proc.stdout == f"{linked}/k1\n{linked}/k2\n"


def test_aliases_module(linked):
    proc = bash(linked, "alias ll la .. rm gs | cut -d= -f2-")
    assert proc.stdout == "'ls -alFh'\n'ls -A'\n'cd ..'\n'rm -I'\n'git status -sb'\n"


def test_aliases_safe_rm_switched_off_per_machine(linked):
    proc = bash(linked, "alias rm cp mv 2>&1 | head -1", local="unalias rm cp mv\n")
    assert "not found" in proc.stdout


def test_functions_module_mkcd_and_up(linked):
    proc = bash(linked, "mkcd a/b/c && pwd && up 2 && pwd")
    assert proc.stdout == f"{linked}/a/b/c\n{linked}/a\n"


def test_functions_cdg_goes_to_the_repository_top_or_below_it(linked):
    proc = bash(linked, "git init -q r && command mkdir -p r/s/t && cd r/s/t && cdg && pwd && cdg s && pwd; "
                        "cd /; cdg; echo $?; pwd")
    assert proc.stdout == f"{linked}/r\n{linked}/r/s\n128\n/\n"
    assert "not a git repository" in proc.stderr


def test_functions_use_command_to_bypass_verbose_aliases(linked):
    proc = bash(linked, "mkcd q >/dev/null; echo done")
    assert proc.stdout == "done\n"          # no 'mkdir: created directory' from the -pv alias


def test_functions_bd_and_cdf_change_directory(linked):
    proc = bash(linked, "command mkdir -p one/two/three; echo f > one/two/three/f; cd one/two/three; bd on; pwd; "
                        "bd nothere; echo $?; cdf two/three/f; pwd")
    assert proc.stdout == f"{linked}/one\n1\n{linked}/one/two/three\n"
    assert proc.stderr == "bd: no parent directory starts with 'nothere'"


def test_functions_retry_and_timit_hand_on_the_exit_status(linked):
    proc = bash(linked, "retry 2 false; echo $?; retry 3 true; echo $?; timit bash -c 'exit 3'; echo $?")
    assert proc.stdout == "1\n0\n3\n"
    assert proc.stderr.splitlines()[:2] == ["retry: attempt 1/2 failed", "retry: attempt 2/2 failed"]
    assert re.fullmatch(r"timit: \d+\.\d{3} s \(exit 3\)", proc.stderr.splitlines()[2])


def test_functions_retry_sleeps_between_attempts_not_after_the_last(linked):
    proc = bash(linked, 'sleep() { echo "sleep $*"; }; retry 3 false; echo $?')
    assert proc.stdout == "sleep 1\nsleep 1\n1\n"


def test_functions_hr_fills_the_terminal_width(linked):
    proc = bash(linked, "COLUMNS=5 hr; COLUMNS=3 hr =; unset COLUMNS; hr x | wc -c")
    assert proc.stdout == "─────\n===\n81\n"


def test_arrays_slice_split_and_join_keep_empty_and_spaced_values(linked):
    proc = bash(linked, r"""
        a=(1 2 3 4 5 6 7 8 9 10)
        arr_slice -e b a 1::4; echo "${b[*]}"
        arr_slice b a 1::4; echo "${b[*]}"
        arr_slice a a -3:; echo "${a[*]}"
        arr_slice b a 3:2; echo "${#b[@]}"
        arr_slice b a 1:x; echo "rc=$?"
        arr_split p ', ' 'x, , y z, '; arr_show p
        arr_split p , ''; echo "${#p[@]}"
        arr_join p -; arr_split p "" x; echo "rc=$?"
        q=(a 'b c' $'d\ne'); arr_join q ' | '
    """)
    assert proc.stdout == ("1 5 9 10\n1 5 9\n8 9 10\n0\nrc=2\n"
                           "p (4)\n  [0] x\n  [1] ''\n  [2] y\\ z\n  [3] ''\n0\n\nrc=2\n"
                           "a | b c | d\ne\n")
    assert proc.stderr.splitlines() == ["arr_slice: bad slice '1:x' (START:END:STEP)",
                                        "arr_split: empty separator"]


def test_arrays_reshape_in_place_with_newlines_in_values(linked):
    proc = bash(linked, r"""
        x=(b 'a b' b $'c\nd')
        arr_uniq x x; arr_show x
        arr_sort s x -r; arr_show s
        arr_rev x x; arr_join x ,
        arr_has x 'a b' && echo has; arr_has x a || echo no
        arr_index x 'a b'; arr_index x zz || echo "rc=$?"
        n=(3 10 7); arr_filter n n test 5 -lt; arr_join n ,
        up() { printf '%s!\n' "${1^^}"; }; arr_map x x up; arr_join x ,
        arr_map x x false; echo "rc=$? ${#x[@]}"
        e=(); arr_to_lines e; arr_sort e e; arr_uniq e e; echo "empty ${#e[@]}"
    """)
    assert proc.stdout == ("x (3)\n  [0] b\n  [1] a\\ b\n  [2] $'c\\nd'\n"
                           "s (3)\n  [0] $'c\\nd'\n  [1] b\n  [2] a\\ b\n"
                           "c\nd,a b,b\nhas\nno\n1\nrc=1\n10,7\nC\nD!,A B!,B!\nrc=1 3\nempty 0\n")


def test_arrays_maps_and_strings(linked):
    proc = bash(linked, r"""
        declare -A h=(['k 2']=v [a]='x y')
        map_show h; map_keys k h; arr_join k /
        str_trim t $'  hi there \n'; echo "[$t]"

        str_starts foobar foo && str_ends foobar bar && ! str_starts foobar bar && echo ok
        printf 'one\n\nthree\n' | { arr_from_lines l; arr_show l; }
    """)
    assert proc.stdout == ("a=x\\ y\nk 2=v\na/k 2\n[hi there]\nok\n"
                           "l (3)\n  [0] one\n  [1] ''\n  [2] three\n")
def test_functions_man_falls_back_to_help_for_one_program_without_a_page(linked, tmp_path):
    fake = stubs(tmp_path, man='echo "No manual entry for $*" >&2; exit 16\n',
                 mytool='echo "usage: mytool $*"\n')
    proc = bash(linked, "man mytool; echo $?; man mytool other; echo $?",
                env={"PATH": f"{fake}:{os.environ['PATH']}", "PAGER": "cat"})
    assert proc.stdout == "usage: mytool --help\n0\n1\n"
    assert proc.stderr == "No manual entry for mytool\nNo manual entry for mytool other"


def test_dirs_module_marks(linked):
    proc = bash(linked, "command mkdir -p p/q; cd p/q; mark pq; cd; marks; jump pq; pwd; unmark pq; marks | wc -l")
    assert proc.stdout == f"pq               -> {linked}/p/q\n{linked}/p/q\n0\n"


def test_dirs_module_completes_the_word_under_the_cursor(linked):
    proc = bash(linked, "mark ab; mark cd; COMP_WORDS=(jump ab c); COMP_CWORD=2; _jump_complete jump c ab; "
                        'echo "${COMPREPLY[*]}"')
    assert (proc.stdout, proc.stderr) == ("cd\n", "")


def test_dirs_module_mark_asks_before_moving_a_bookmark(linked):
    proc = bash(linked, "command mkdir a b; cd a; mark m; mark m; echo same $?; cd ../b; "
                        "mark m </dev/null; echo eof $?; mark m <<< n; echo n $?; marks; "
                        "mark m <<< y; echo y $?; marks")
    assert proc.stdout == (f"same 0\neof 1\nn 1\nm                -> {linked}/a\n"
                           f"y 0\nm                -> {linked}/b\n")
    assert proc.stderr == f"mark: m -> {linked}/a; replace? [y/N] " * 3


DIRS = (REPO / "dot_config/bash/rc.d/45-dirs.sh").read_text()
CDPATH_ON = DIRS.split("\n#CDPATH=")[1].split("\n")[0]
NUMBERS_ON = DIRS.split("\n#for _i in 1 2 3")[1].split("\n")[0]


def test_dirs_module_cdpath_includes_home(linked):
    proc = bash(linked, 'echo "$CDPATH"', before="DOTFILES_CDPATH=/opt\n", local=f"CDPATH={CDPATH_ON}\n")
    assert proc.stdout == f":{linked}:/opt\n"


AUTO_PUSHD = DIRS.split("\n#cd() {\n")[1].split("\n#}\n")[0]


@pytest.mark.parametrize("local", ["", "cd() {\n" + AUTO_PUSHD.replace("    #", "    ") + "\n}\n"],
                         ids=["builtin-cd", "auto-pushd"])
def test_dirs_module_number_goes_to_that_stack_entry(linked, local):
    local += f"for _i in 1 2 3{NUMBERS_ON}\nunset _i\n"
    proc = bash(linked, "command mkdir -p a b; cd a; pushd ../b >/dev/null; 1; pwd", local=local)
    assert (proc.stdout, proc.stderr) == (f"{linked}/a\n", "")


def test_prompt_module_builds_ps1_with_the_toolkit(linked):
    proc = bash(linked, "type -t prompt_build; prompt_build; echo \"$PS1\" | head -1")
    assert proc.stdout.splitlines()[0] == "function"
    assert "╭" in proc.stdout.splitlines()[1]


def test_prompt_has_one_blank_line_above_it_however_often_it_is_drawn(linked):
    draw = 'eval "$PROMPT_COMMAND"; '
    proc = bash(linked, draw * 2 + 'source "$DOTFILES_BASH_DIR/prompt/layout.sh"; ' + draw
                + 'printf "%s" "${PS1@P}"')
    lines = proc.stdout.split("\n")
    assert lines[0] == "" and "╭" in lines[1]


@needs("script")
def test_prompt_leaves_promptvars_on_for_ps0_and_shows_a_hostile_directory_as_typed(linked):
    # kitty's shell integration puts $(...) in PS0; the prompt must not
    # switch promptvars off to keep a directory name from running.
    (linked / ".bashrc.local").write_text("PS0='$(printf \"<ps0 %s>\" ran)'\n")
    name = "x$(touch PWNED)`touch PWNED`"
    (linked / name).mkdir()
    proc = subprocess.run(["script", "-qec", f"bash --rcfile {linked}/.bashrc -i", "/dev/null"],
                          input=f"cd '{name}'\necho hi\nexit\n", env=shell_env(linked),
                          capture_output=True, text=True, cwd=str(linked), errors="replace")
    assert "<ps0 ran>" in proc.stdout
    assert "$(printf" not in proc.stdout
    assert f":~/{name}" in proc.stdout       # the prompt's user@host:directory, not the echoed cd
    assert list(linked.rglob("PWNED")) == []


def test_prompt_toolkit_links_only_the_code_bash_sources(linked):
    toolkit = linked / ".config/bash/prompt/toolkit"
    names = sorted(str(p.relative_to(toolkit)) for p in toolkit.rglob("*") if not p.is_dir())
    assert names[0] == "lib/cache.sh"
    assert all(n == "prompt.sh" or n.startswith(("lib/", "segments/")) for n in names), names


@needs("bats")
def test_prompt_toolkit_bats_suite_passes():
    # The toolkit's own suite (cache, escaping, collectors, nounset), so a
    # toolkit fix made here cannot ship with it failing. About 45 s.
    proc = subprocess.run(["bats", "tests"], cwd=REPO / "dot_config/bash/prompt/toolkit",
                          capture_output=True, text=True)
    plan = re.match(r"1\.\.(\d+)\n", proc.stdout)
    failed = [l for l in proc.stdout.splitlines() if l.startswith("not ok")]
    assert plan and failed == [] and proc.stdout.count("\nok ") == int(plan[1]), proc.stdout[-4000:]


def shown_prompt(home, setup="", env=None):
    # PS1 as the terminal shows it, colors and \001/\002 markers removed.
    proc = bash(home, setup + 'prompt_build; printf "%s\\n" "${PS1@P}"', env=env)
    assert proc.stderr == ""
    return re.sub(r"\x1b\[[0-9;]*m|[\x01\x02]", "", proc.stdout).splitlines()


def test_prompt_rows_outside_a_repository(linked):
    rows = shown_prompt(linked, env={"DISPLAY": ":9", "CONDA_DEFAULT_ENV": "e", "VIRTUAL_ENV": "/x/v"})
    assert rows[0].startswith("╭ ") and rows[0].endswith(":~")
    assert rows[1:] == ["│ :9 | (e) (v)", "╰ ✓ $ "]       # no git row; one space before $
    assert shown_prompt(linked, env={"CONDA_DEFAULT_ENV": "e"})[1] == "│ (e)"   # no bar alone


def test_prompt_env_row_spaces_the_tmux_pane_only_when_tmux_answers(linked, tmp_path):
    # TMUX is set after startup, so no module sees it but the prompt
    (tmp_path / "up").mkdir()
    (tmp_path / "down").mkdir()
    up = stubs(tmp_path / "up", tmux="echo 's:1.0'\n")
    down = stubs(tmp_path / "down", tmux="exit 1\n")
    def env_row(fake, display):
        return shown_prompt(linked, f"TMUX=/tmp/t,1,0; PATH={fake}:$PATH; ",
                            env={"DISPLAY": display, "CONDA_DEFAULT_ENV": "e"})[1]
    assert env_row(up, ":9") == "│ :9 ⧉ s:1.0 | (e)"
    assert env_row(up, "") == "│ ⧉ s:1.0 | (e)"
    assert env_row(down, ":9") == "│ :9 | (e)"
    assert env_row(down, "") == "│ (e)"


def test_prompt_git_row_leaves_out_a_missing_or_repeated_commit(linked):
    git = "git -c user.name=t -c user.email=t@t"
    rows = shown_prompt(linked, f"{git} init -q -b main r; cd r; ")
    assert rows[1] == "│ ⎇  (✓) main"                 # before the first commit: no ()
    rows = shown_prompt(linked, f"{git} init -q -b main d; cd d; {git} commit -q --allow-empty -m x; "
                                f"{git} checkout -q --detach; ")
    sha = rows[1].split()[-1]
    assert rows[1] == f"│ ⎇  (✓) {sha}"                # detached: the SHA once


def test_prompt_top_row_has_a_bar_only_after_depth_or_jobs(linked):
    user_host = f"{os.environ['USER']}@{socket.gethostname().split('.')[0]}:~"
    assert shown_prompt(linked)[0] == f"╭ {user_host}"
    # The braces take the "[1] PID" an interactive shell prints off stderr
    rows = shown_prompt(linked, 'SHLVL=3; { sleep 30 >/dev/null 2>&1 & } 2>/dev/null; trap "kill %1" EXIT; ')
    assert rows[0] == f"╭ ⬇3 ⚙1 | {user_host}"
    assert shown_prompt(linked, "SHLVL=3; ")[0] == f"╭ ⬇3 | {user_host}"


def test_prompt_git_row_with_an_upstream(linked):
    git = "git -c user.name=t -c user.email=t@t"
    rows = shown_prompt(linked, f"{git} init -q -b main u; {git} -C u commit -q --allow-empty -m x; "
                                f"git clone -q u c 2>/dev/null; cd c; {git} commit -q --allow-empty -m y; ")
    shas = re.findall(r"\(([0-9a-f]{7,})\)", rows[1])
    assert len(shas) == 2 and rows[1] == f"│ ⎇  (✓) main ({shas[0]}) → origin/main ({shas[1]}) (↑1)"


def fast_files(home):
    """Fast mode's sample files for this host, beside HOME as fast_mode_apart puts them"""
    return home.parent / "xdg-run" / f"dots-fast.{socket.gethostname().split('.')[0]}"


NOTICE = "\x1b[1;7m FAST MODE ON \x1b[0m  "


def test_fast_mode_is_off_by_default_and_each_start_is_a_sample(linked):
    proc = bash(linked, 'echo "${DOTS_FAST_ACTIVE-unset} $_dots_fast_mode $_dots_fast_from"')
    assert (proc.stdout, proc.stderr) == ("unset off default\n", "")
    ring = (fast_files(linked).parent / (fast_files(linked).name + ".ring")).read_text()
    assert re.fullmatch(r"startup \d+ [01]\n", ring)


@pytest.mark.parametrize("env, file, why", [
    ({"DOTS_FAST": "on"}, None, "forced: DOTS_FAST=on"),
    ({}, "on", "forced: dots fast on"),
    ({"DOTS_FAST": "on"}, "off", "forced: DOTS_FAST=on"),
])
def test_fast_mode_forced_on_says_so_and_by_what(linked, env, file, why):
    if file:
        (linked / ".config/bash/fast").write_text(file + "\n")
    proc = bash(linked, 'echo "$DOTS_FAST_ACTIVE $_GIT_BUDGET"', env=env)
    assert (proc.stdout, proc.stderr) == ("1 0.2\n", NOTICE + why)


def test_fast_mode_off_in_the_environment_overrules_the_file(linked):
    (linked / ".config/bash/fast").write_text("on\n")
    proc = bash(linked, 'echo "${DOTS_FAST_ACTIVE-unset} $_GIT_BUDGET"', env={"DOTS_FAST": "off"})
    assert (proc.stdout, proc.stderr) == ("unset 1\n", "")


def test_fast_mode_an_unknown_word_is_reported_and_taken_as_off(linked):
    proc = bash(linked, 'echo "${DOTS_FAST_ACTIVE-unset}"', env={"DOTS_FAST": "yes"})
    assert (proc.stdout, proc.stderr) == ("unset\n", "fast mode: yes is not on, off or auto; taking off")


def test_fast_mode_auto_turns_on_for_a_host_signal_over_its_threshold(linked):
    proc = bash(linked, 'echo "$DOTS_FAST_ACTIVE"', env={"DOTS_FAST": "auto", "DOTS_FAST_MEM": "100"})
    assert proc.stdout == "1\n"
    assert re.fullmatch(re.escape(NOTICE) + r"auto: mem \d+% <= 100", proc.stderr)
    assert Path(str(fast_files(linked)) + ".state").read_text() == "on\n"


def write_ring(home, *samples, state=None):
    files = str(fast_files(home))
    Path(files + ".ring").write_text("".join(f"{s}\n" for s in samples))
    if state:
        Path(files + ".state").write_text(state + "\n")


# The host thresholds out of reach, so only the samples decide; the start
# itself is a sample, so the threshold for it is out of reach too.
CALM = {"DOTS_FAST": "auto", "DOTS_FAST_STARTUP_MS": "99999", "DOTS_FAST_BLOCKED": "99999",
        "DOTS_FAST_IOWAIT": "101", "DOTS_FAST_LOAD": "99999", "DOTS_FAST_STEAL": "101",
        "DOTS_FAST_MEM": "0", "DOTS_FAST_SWAPIN": "99999999"}


def test_fast_mode_auto_turns_on_after_two_slow_samples_of_five(linked):
    write_ring(linked, *["git 10 0"] * 5, "git 340 1", "git 10 0", "git 250 1", "git 10 0")
    proc = bash(linked, 'echo "$DOTS_FAST_ACTIVE"', env=CALM)
    assert (proc.stdout, proc.stderr) == ("1\n", NOTICE + "auto: git 340 ms >= 200, git 250 ms >= 200")
    write_ring(linked, *["git 10 0"] * 5, "git 340 1", *["git 10 0"] * 3, state="off")
    assert bash(linked, 'echo "${DOTS_FAST_ACTIVE-unset}"', env=CALM).stdout == "unset\n"


def test_fast_mode_auto_turns_off_only_after_ten_fast_samples(linked):
    write_ring(linked, "git 340 1", *["git 10 0"] * 9, state="on")
    proc = bash(linked, 'echo "$DOTS_FAST_ACTIVE"', env=CALM)
    assert proc.stdout == "1\n"
    assert proc.stderr == NOTICE + ("auto: staying on: 1 of the last 10 samples slow, off once 10 in a row "
                                    "are fast")
    write_ring(linked, *["git 10 0"] * 10, state="on")
    proc = bash(linked, 'echo "${DOTS_FAST_ACTIVE-unset}"', env=CALM)
    assert (proc.stdout, proc.stderr) == ("unset\n", "")
    assert Path(str(fast_files(linked)) + ".state").read_text() == "off\n"


def test_fast_mode_auto_turns_on_mid_session_after_two_slow_git_refreshes(linked):
    # Every refresh is slow at 0 ms; the cache check is made to fail so each one runs git.
    # The sample files exist already, and noclobber (10-options.sh) is on by now
    write_ring(linked, "git 10 0", state="off")
    script = ('git init -q r; cd r; git_info_cache_valid() { return 1; }; '
              'for i in 1 2 3; do _dots_fast_collect_git; echo "$i ${DOTS_FAST_ACTIVE-unset} $_GIT_BUDGET"; done')
    proc = bash(linked, script, env=dict(CALM, DOTS_FAST_GIT_MS="0"))
    assert proc.stdout == "1 unset 1\n2 1 0.2\n3 1 0.2\n"
    assert re.fullmatch(re.escape(NOTICE) + r"auto: git \d+ ms >= 0, 2 of the last 5 prompts", proc.stderr)
    files = str(fast_files(linked))
    ring = Path(files + ".ring").read_text()
    assert re.fullmatch(r"git 10 0\nstartup \d+ 0\n(git \d+ 1\n){3}", ring)
    assert Path(files + ".state").read_text() == "on\n"


def test_fast_mode_dots_fast_applies_in_the_shell_that_ran_it(linked):
    proc = bash(linked, 'dots fast on >/dev/null; echo "$DOTS_FAST_ACTIVE"; '
                        'dots fast off >/dev/null; echo "${DOTS_FAST_ACTIVE-unset}"')
    assert proc.stdout == "1\nunset\n"
    assert proc.stderr == NOTICE + "forced: dots fast on\nfast mode off"


def test_fast_paths_switch_the_directory_hooks_at_the_prompt_after_a_cd(linked):
    # A trailing slash, ~ and a path that is only a prefix of another are all handled
    script = ('command mkdir -p slow/sub slower; on_dir() { echo "hook $1"; }; dots_fast_dir_hook on_dir; '
              'cd slow/sub; _dots_fast_cwd; _dots_fast_cwd; cd ~/slower; _dots_fast_cwd; '
              'cd ~/slow; _dots_fast_cwd; (exit 3); _dots_fast_cwd; echo "rc $?"')
    proc = bash(linked, script, env={"DOTS_FAST_PATHS": "/nowhere::~/slow/"})
    assert (proc.stdout, proc.stderr) == ("hook 0\nhook 1\nhook 0\nhook 1\nrc 3\n", "")


def test_fast_paths_hooks_follow_the_mode_too(linked):
    # In fast mode every directory is fast: a cd changes nothing; turning the mode
    # off outside DOTS_FAST_PATHS does
    (linked / ".config/bash/fast").write_text("on\n")
    script = ('command mkdir slow; on_dir() { told+=" $1"; }; dots_fast_dir_hook on_dir; cd slow; _dots_fast_cwd; '
              'cd ~; _dots_fast_cwd; dots fast off >/dev/null; echo "$told"; echo "$PROMPT_COMMAND"')
    proc = bash(linked, script, env={"DOTS_FAST_PATHS": "~/slow"})
    told, prompt_command = proc.stdout.splitlines()
    assert told == " 1 0"
    # Ahead of the prompt's collectors, so the git status of the new directory sees it
    assert prompt_command.index("_dots_fast_cwd") < prompt_command.index("prompt_build")
    user_host = f"{os.environ['USER']}@{socket.gethostname().split('.')[0]}:~"
    def top(env):
        proc = bash(linked, 'prompt_build; printf "%s\\n" "${PS1@P}"', env=env)
        return re.sub(r"\x1b\[[0-9;]*m|[\x01\x02]", "", proc.stdout).splitlines()[0]
    assert top({"DOTS_FAST": "on"}) == f"╭ FAST! | {user_host}"
    assert re.fullmatch(rf"╭ slow mem\d+% \| {re.escape(user_host)}", top({"DOTS_FAST_MEM": "100"}))
    assert re.fullmatch(rf"╭ FAST mem\d+% \| {re.escape(user_host)}",
                        top({"DOTS_FAST": "auto", "DOTS_FAST_MEM": "100"}))
    assert re.fullmatch(rf"╭ blk\d+ ld[\d.]+ mem\d+% git\d+ \| {re.escape(user_host)}",
                        top({"DOTS_FAST_PROMPT": "always"}))
    assert top({}) == f"╭ {user_host}"
    assert top({"DOTS_FAST_PATHS": str(linked)}) == f"╭ fast-dir | {user_host}"
    assert top({"DOTS_FAST_PATHS": str(linked), "DOTS_FAST": "on"}) == f"╭ FAST! | {user_host}"


def test_simple_prompt_module_when_enabled(linked):
    (linked / ".config" / "bash" / "disabled").write_text("prompt\n")
    off = linked / ".config/bash/rc.d/61-prompt-simple.sh.off"
    os.symlink(os.readlink(off), linked / ".config/bash/rc.d/61-prompt-simple.sh")
    proc = bash(linked, r'echo "$PS1"')
    assert proc.stdout.startswith(r"\[\e[1;32m\]\u@\h")
    proc = bash(linked, r'echo "$PS1"', before="DOTFILES_PROMPT_COLOR=0\n")
    assert proc.stdout == r"\u@\h \w$(_ps_simple_git) \$ " + "\n"


def test_title_module_only_on_a_tty(linked):
    proc = bash(linked, "[[ $PROMPT_COMMAND == *_title_prompt* ]] && echo title || echo no-title")
    assert proc.stdout == "no-title\n"          # stdout is a pipe here
    proc = bash(linked, "type -t _title_prompt || echo absent", env={"TERM": "dumb"})
    assert proc.stdout == "absent\n"


def test_conda_module_silent_without_conda(linked):
    proc = bash(linked, "type -t conda || echo none", before="DOTFILES_CONDA_ROOT=/nonexistent\n",
                env={"PATH": "/usr/bin:/bin"})
    assert proc.stdout in ("none\n", "function\n")     # function only when a system conda exists


def test_python_module_venv_function(linked):
    proc = bash(linked, "venv && echo \"${VIRTUAL_ENV##*/}\" && deactivate && echo \"${VIRTUAL_ENV:-none}\"")
    assert proc.stdout == ".venv\nnone\n"


VENV_STUB = ('deactivate() { echo deactivated; unset VIRTUAL_ENV; }; command mkdir -p proj/.venv/bin proj2/sub; '
             'echo "VIRTUAL_ENV=\\$PWD/.venv" > proj/.venv/bin/activate; ')


def test_python_module_venv_auto_deactivates_in_a_sibling_whose_name_extends_the_project(linked):
    proc = bash(linked, VENV_STUB + 'cd proj; _venv_auto; cd ../proj2/sub; _venv_auto; echo "${VIRTUAL_ENV:-none}"')
    assert (proc.stdout, proc.stderr) == ("deactivated\nnone\n", "")


def test_python_module_venv_auto_leaves_a_venv_activated_by_hand(linked):
    proc = bash(linked, VENV_STUB + 'VIRTUAL_ENV=$HOME/venvs/x; cd proj2; _venv_auto; echo "${VIRTUAL_ENV:-none}"')
    assert (proc.stdout, proc.stderr) == (f"{linked}/venvs/x\n", "")


def test_python_module_venv_auto_entering_a_project_keeps_a_venv_activated_by_hand(linked):
    proc = bash(linked, VENV_STUB + 'VIRTUAL_ENV=$HOME/venvs/x; cd proj; _venv_auto; echo "${VIRTUAL_ENV:-none}"')
    assert (proc.stdout, proc.stderr) == (f"{linked}/venvs/x\n", "")


def test_tools_module_follows_the_moved_version_manager_homes(linked, tmp_path):
    pyenv, sdkman = tmp_path / "pyenv", tmp_path / "sdkman"
    (pyenv / "bin").mkdir(parents=True)
    (sdkman / "bin").mkdir(parents=True)
    (sdkman / "bin/sdkman-init.sh").write_text("echo sdkman\n")
    nix = linked / ".local/state/nix/profile/etc/profile.d"
    nix.mkdir(parents=True)
    (nix / "nix.sh").write_text("echo nix\n")
    proc = bash(linked, 'tr : "\\n" <<<"$PATH" | command grep -x "$PYENV_ROOT/bin"',
                env={"PYENV_ROOT": str(pyenv), "SDKMAN_DIR": str(sdkman)})
    assert proc.stdout == f"nix\nsdkman\n{pyenv}/bin\n"
def test_python_module_venv_auto_and_the_prompt_go_in_once_when_bashrc_is_read_again(linked):
    text = (REPO / "dot_config/bash/rc.d/75-python.sh").read_text()
    local = next(l[1:] for l in text.splitlines() if l.startswith("#") and "PROMPT_COMMAND=\"_venv_auto" in l)
    proc = bash(linked, 'source ~/.bashrc; echo "$PROMPT_COMMAND"', local=local + "\n")
    commands = proc.stdout.replace(";", " ").split()
    assert (commands.count("_venv_auto"), commands.count("prompt_build")) == (1, 1)


def test_tools_module_leaves_cat_alone_when_bat_is_installed(linked, tmp_path):
    fake = stubs(tmp_path, bat='echo "bat $*"\n')
    proc = bash(linked, "type -t cat", env={"PATH": f"{fake}:{os.environ['PATH']}"})
    assert proc.stdout == "file\n"


def test_tools_module_loads_kubectl_and_gh_completion_on_the_first_tab(linked, tmp_path):
    script = 'echo "$0" >> ran; echo "__start_NAME() { :; }; complete -o default -F __start_NAME NAME"\n'
    fake = stubs(tmp_path, kubectl=script.replace("NAME", "kubectl"), gh=script.replace("NAME", "gh"))
    proc = bash(linked, "complete -p kubectl k gh; _dotfiles_lazy_completion k; echo $?; "
                        "_dotfiles_lazy_completion gh; complete -p kubectl k gh; cat ran",
                env={"PATH": f"{fake}:{os.environ['PATH']}"})
    assert proc.stdout == ("complete -F _dotfiles_lazy_completion kubectl\n"
                           "complete -F _dotfiles_lazy_completion k\n"
                           "complete -F _dotfiles_lazy_completion gh\n"
                           "124\n"
                           "complete -o default -F __start_kubectl kubectl\n"
                           "complete -o default -F __start_kubectl k\n"
                           "complete -o default -F __start_gh gh\n"
                           f"{fake}/kubectl\n{fake}/gh\n")


@pytest.mark.skipif(shutil.which("fd", path="/usr/bin:/bin") is not None, reason="a real fd is installed")
def test_tools_module_fzf_lists_with_fdfind_where_there_is_no_fd(linked, tmp_path):
    # fzf runs these with `$SHELL -c`: they name a program on PATH.
    fake = stubs(tmp_path, fzf="", fdfind='echo "fdfind $*"\n')
    proc = bash(linked, 'for v in FZF_DEFAULT_COMMAND FZF_CTRL_T_COMMAND FZF_ALT_C_COMMAND; do '
                        'sh -c "${!v}"; done', env={"PATH": f"{fake}:/usr/bin:/bin"})
    assert proc.stdout == ("fdfind --type f --hidden --exclude .git\n" * 2
                           + "fdfind --type d --hidden --exclude .git\n")


def test_hpc_module_defines_nothing_without_a_scheduler(linked):
    proc = bash(linked, "alias qs sq ml 2>&1 | grep -c 'not found'", env={"PATH": "/usr/bin:/bin"})
    assert proc.stdout == "3\n"


def test_hpc_module_leaves_lmods_own_ml_function(linked):
    proc = bash(linked, "ml gcc; mll", before='module() { echo "module $*"; }\nml() { echo "lmod ml $*"; }\n')
    assert proc.stdout == "lmod ml gcc\nmodule list\n"


def test_hpc_module_with_fake_schedulers(linked, tmp_path):
    fake = stubs(tmp_path, qstat="echo $0 $*\n", squeue="echo $0 $*\n")
    (tmp_path / "pbs.conf").write_text("PBS_SERVER=head\n")
    proc = bash(linked, "alias qs sq | cut -d= -f2-; qs",
                env={"PATH": f"{fake}:/usr/bin:/bin", "PBS_CONF_FILE": str(tmp_path / "pbs.conf")})
    lines = proc.stdout.splitlines()
    assert lines[0] == "'qstat -u \"$USER\"'"
    assert lines[1].startswith("'squeue -u \"$USER\"")
    assert lines[2:] == [f"{fake}/qstat -u {os.environ.get('USER', '')}".rstrip()]


def test_hpc_module_takes_slurms_qstat_wrapper_for_no_pbs(linked, tmp_path):
    # Slurm's Torque wrappers install a qstat: without pbs.conf it is not PBS
    fake = stubs(tmp_path, qstat="echo $0 $*\n", squeue="echo $0 $*\n")
    proc = bash(linked, "alias qs 2>&1; alias sq >/dev/null && echo slurm",
                env={"PATH": f"{fake}:/usr/bin:/bin", "PBS_CONF_FILE": str(tmp_path / "absent")})
    assert proc.stdout == "bash: alias: qs: not found\nslurm\n"


def test_profile_and_bash_profile_chain(linked):
    (linked / ".config" / "bash" / "profile.d").mkdir()
    (linked / ".config" / "bash" / "profile.d" / "x.sh").write_text("export FROM_PROFILE_D=1\n")
    proc = subprocess.run(["bash", "-l", "-i", "-c", 'echo "$FROM_PROFILE_D $LANG"; type -t mkcd'],
                          env={"HOME": str(linked), "PATH": os.environ["PATH"], "TERM": "dumb"},
                          capture_output=True, text=True)
    assert proc.stdout == "1 C.UTF-8\nfunction\n"


def test_bash_profile_ssh_to_tmux_leaves_an_editor_reading_the_environment(linked, tmp_path):
    # VS Code Remote-SSH reads the environment from `bash -ilc` with no
    # terminal; going into tmux there hangs it.
    profile = linked / ".bash_profile"
    text = profile.read_text()
    switched = re.sub(r"^#(\[\[ -n \"\$\{SSH_CONNECTION)", r"\1", text, flags=re.M)
    assert switched != text
    profile.unlink()
    profile.write_text(switched)
    fake = stubs(tmp_path, tmux='echo "tmux $*"\n')
    env = {"HOME": str(linked), "PATH": f"{fake}:{os.environ['PATH']}", "TERM": "dumb",
           "SSH_CONNECTION": "10.0.0.1 22 10.0.0.2 22", "VSCODE_RESOLVING_ENVIRONMENT": "1"}
    proc = subprocess.run(["bash", "-l", "-i", "-c", "echo env"], env=env, capture_output=True,
                          text=True, stdin=subprocess.DEVNULL)
    assert proc.stdout == "env\n"


@needs("dash")
def test_profile_is_posix_sh(linked):
    proc = subprocess.run(["dash", "-c", f". {linked}/.profile; echo $LANG"],
                          env={"HOME": str(linked), "PATH": "/usr/bin:/bin"}, capture_output=True, text=True)
    assert (proc.returncode, proc.stdout, proc.stderr) == (0, "C.UTF-8\n", "")


def switch_on_job_skip(home, name):
    """~/NAME with its batch-job setting switched on"""
    path = home / name
    text = path.read_text()
    switched = re.sub(r"^#(\[\[? .*PBS_JOBID)", r"\1", text, flags=re.M)
    assert switched != text
    path.unlink()
    path.write_text(switched)


JOB_VARIABLES = ["PBS_JOBID", "SLURM_JOB_ID", "GITLAB_CI", "GITHUB_ACTIONS"]


def test_login_files_skip_a_batch_job_but_not_an_interactive_one(linked):
    switch_on_job_skip(linked, ".bash_profile")
    (linked / ".config" / "bash" / "profile.d").mkdir()
    (linked / ".config" / "bash" / "profile.d" / "x.sh").write_text("export FROM_PROFILE_D=1\n")

    def login(flags, **job):
        env = {"HOME": str(linked), "PATH": "/usr/bin:/bin", "TERM": "dumb", **job}
        return subprocess.run(["bash", *flags, "-c", 'echo "${FROM_PROFILE_D-none} ${LANG-none}"'],
                              env=env, capture_output=True, text=True, stdin=subprocess.DEVNULL).stdout

    assert [login(["-l"], **{v: "1"}) for v in JOB_VARIABLES] == ["none none\n"] * 4
    assert login(["-l"]) == "1 C.UTF-8\n"
    assert login(["-l", "-i"], PBS_JOBID="1").endswith("1 C.UTF-8\n")


@needs("dash")
def test_profile_skips_a_batch_job_in_sh(linked):
    switch_on_job_skip(linked, ".profile")

    def login(*flags, **job):
        return subprocess.run(["dash", "-l", *flags, "-c", "echo ${LANG-none}"], capture_output=True,
                              text=True, stdin=subprocess.DEVNULL,
                              env={"HOME": str(linked), "PATH": "/usr/bin:/bin", **job}).stdout

    assert (login(SLURM_JOB_ID="7"), login(), login("-i", SLURM_JOB_ID="7")) == (
        "none\n", "C.UTF-8\n", "C.UTF-8\n")


def test_bash_logout_leaves_the_console_alone_in_a_batch_job(linked, tmp_path):
    switch_on_job_skip(linked, ".bash_logout")
    fake = stubs(tmp_path, clear_console='echo "clear_console $*"\n')

    def logout(**job):
        env = {"HOME": str(linked), "PATH": f"{fake}:/usr/bin:/bin", "TERM": "dumb", "SHLVL": "0", **job}
        return subprocess.run(["bash", "--noprofile", "-l", "-c", "exit"], env=env, capture_output=True,
                              text=True, stdin=subprocess.DEVNULL).stdout

    assert (logout(GITLAB_CI="true"), logout()) == ("", "clear_console -q\n")


# ----------------------------------------------------------------------
# history (12-history.sh)
# ----------------------------------------------------------------------

HISTORY_ON = "_hist_pane_start\n_hist_log_start\n"


class Panes:
    """A private tmux server whose panes run the applied bash, switched on
    by HISTORY_ON in ~/.bashrc.local. Commands are typed with a leading
    space, so the pane's history never records them."""

    def __init__(self, home, tmp_path):
        self.home, self.out = home, tmp_path / "out"
        self.out.mkdir()
        self.env = shell_env(home)
        self.sock = str(tmp_path / "tmux.sock")
        self.shell = f"bash --rcfile {home}/.bashrc -i"
        (home / ".bashrc.local").write_text(HISTORY_ON)

    def tmux(self, *args):
        proc = subprocess.run(["tmux", "-S", self.sock, "-f", "/dev/null", *args], env=self.env,
                              cwd=str(self.home), capture_output=True, text=True, timeout=10)
        assert proc.returncode == 0, proc.stderr
        return proc.stdout

    def seed_shared(self, text):
        """Write text to the shared history file, wherever HISTFILE puts it."""
        proc = subprocess.run(["bash", "--rcfile", f"{self.home}/.bashrc", "-i", "-c",
                               'printf %s "$_hist_shared"'], env=self.env, cwd=str(self.home),
                              capture_output=True, text=True, timeout=10)
        shared = Path(proc.stdout)
        shared.parent.mkdir(parents=True, exist_ok=True)
        shared.write_text(text)

    def type(self, target, line):
        self.tmux("send-keys", "-t", target, line, "Enter")

    def history(self, target):
        """What Up recalls in the pane, oldest first."""
        mark = self.out / f"{len(list(self.out.iterdir()))}.txt"
        self.type(target, f" fc -ln 1 >| {mark}.tmp; mv {mark}.tmp {mark}")
        return [line.strip() for line in self.wait_for(mark).read_text().splitlines()]

    def run(self, target, line):
        """Type line and wait until the next prompt has recorded it."""
        self.type(target, line)
        self.history(target)

    def kill(self, kind, target):
        """kill-pane or kill-window, then wait until its shells are gone."""
        pids = self.tmux("list-panes", "-t", target, "-F", "#{pane_pid}").split()
        self.tmux(kind, "-t", target)
        self.wait_for(*(Path(f"/proc/{pid}") for pid in pids), gone=True)

    def wait_for(self, *paths, gone=False):
        deadline = time.monotonic() + 10
        while any(p.exists() == gone for p in paths):
            assert time.monotonic() < deadline, f"timed out waiting for {paths}"
            time.sleep(0.02)
        return paths[0]

    def close(self):
        subprocess.run(["tmux", "-S", self.sock, "kill-server"], capture_output=True)


@pytest.fixture
def panes(linked, tmp_path):
    p = Panes(linked, tmp_path)
    yield p
    p.close()


def hist_files(home, session):
    return sorted((home / ".hist").glob(f"*/{session}/*"))


@needs("tmux")
def test_history_split_pane_starts_from_its_source_and_stays_apart(panes):
    panes.tmux("new-session", "-d", "-s", "work", panes.shell)
    panes.run("work", "echo first")
    panes.tmux("split-window", "-t", "work", panes.shell)
    panes.run("work.1", "echo split")
    panes.run("work.0", "echo first-again")
    assert panes.history("work.1")[-2:] == ["echo first", "echo split"]
    assert panes.history("work.0")[-2:] == ["echo first", "echo first-again"]


@needs("tmux")
def test_history_split_with_d_starts_from_the_active_pane(panes):
    panes.tmux("new-session", "-d", "-s", "work", panes.shell)
    panes.run("work", "echo first")
    panes.tmux("split-window", "-d", "-t", "work", panes.shell)
    assert panes.history("work.1")[-1] == "echo first"


@needs("tmux")
def test_history_new_window_takes_over_the_last_closed_pane_of_its_session(panes):
    panes.tmux("new-session", "-d", "-s", "work", panes.shell)
    panes.run("work", "echo keep")
    panes.tmux("new-window", "-t", "work", panes.shell)
    panes.run("work:1", "echo closed")
    panes.kill("kill-window", "work:1")
    panes.tmux("new-window", "-t", "work", panes.shell)
    assert panes.history("work:1")[-2:] == ["echo keep", "echo closed"]
    assert len(hist_files(panes.home, "work")) == 2      # taken over, not copied


@needs("tmux")
def test_history_session_restarted_takes_over_and_other_names_start_from_shared(panes):
    panes.seed_shared("#100\necho shared\n")
    panes.tmux("new-session", "-d", "-s", "work", panes.shell)
    assert panes.history("work")[-1] == "echo shared"
    panes.run("work", "echo in-work")
    panes.kill("kill-session", "work")
    panes.tmux("new-session", "-d", "-s", "work", panes.shell)
    panes.tmux("new-session", "-d", "-s", "other", panes.shell)
    assert panes.history("work")[-1] == "echo in-work"
    # The shared file also has every pane's commands.
    assert panes.history("other")[-2:] == ["echo shared", "echo in-work"]


@needs("tmux")
def test_history_old_closed_files_and_empty_directories_go_before_a_takeover(panes):
    panes.seed_shared("#100\necho shared\n")
    host = panes.home / ".hist" / os.uname().nodename
    old_file = host / "work" / "99999999.1"     # no such pid: closed
    live_file = host / "work" / f"{os.getpid()}.1"
    old_file.parent.mkdir(parents=True)
    old_file.write_text("#100\necho old\n")
    live_file.write_text("#100\necho live\n")
    old_dir, new_dir = host / "gone", host / "just-made"
    old_dir.mkdir()
    new_dir.mkdir()                             # by a shell about to fill it
    long_ago = time.time() - 91 * 86400
    for path in (old_file, live_file, old_dir):
        os.utime(path, (long_ago, long_ago))
    panes.tmux("new-session", "-d", "-s", "work", panes.shell)
    assert panes.history("work")[-1] == "echo shared"
    assert not old_file.exists() and not old_dir.exists()
    assert live_file.exists() and new_dir.exists()


@needs("tmux")
def test_history_shell_started_in_a_pane_starts_from_that_pane(panes):
    panes.tmux("new-session", "-d", "-s", "work", panes.shell)
    panes.tmux("split-window", "-t", "work", panes.shell)
    panes.run("work.0", "echo zero")
    panes.run("work.1", "echo one")
    panes.type("work.1", f" {panes.shell}")
    nested = panes.history("work.1")
    assert nested[-1] == "echo one" and "echo zero" not in nested


@needs("tmux")
def test_history_exec_bash_keeps_the_pane_file(panes):
    panes.tmux("new-session", "-d", "-s", "work", panes.shell)
    panes.run("work", "echo before")
    time.sleep(1.1)                             # a new file would get a new name
    panes.type("work", f" exec {panes.shell}")
    panes.run("work", "echo after")
    assert panes.history("work")[-2:] == ["echo before", "echo after"]
    assert len(hist_files(panes.home, "work")) == 1


@needs("tmux")
def test_history_sourcing_bashrc_again_keeps_the_pane_file(panes):
    panes.tmux("new-session", "-d", "-s", "work", panes.shell)
    panes.run("work", "echo before")
    panes.type("work", " source ~/.bashrc")
    panes.run("work", "echo after")
    assert panes.history("work")[-2:] == ["echo before", "echo after"]
    assert len(hist_files(panes.home, "work")) == 1


@needs("tmux")
def test_history_log_lines_and_hgrep(panes):
    panes.tmux("new-session", "-d", "-s", "work", panes.shell)
    panes.run("work", "cd /")
    panes.type("work", " cd /tmp")      # not recorded, but where the next one runs
    panes.run("work", "echo hello | wc -c")
    log = (panes.home / ".hist" / "log" / time.strftime("%Y-%m")).read_text().splitlines()
    assert [line.split("\t")[1:] for line in log] == [
        [os.uname().nodename, "work", str(panes.home), "cd /"],
        [os.uname().nodename, "work", "/tmp", "echo hello | wc -c"],
    ]
    out = panes.home / "hgrep.txt"
    panes.type("work", f" hgrep wc >| {out}.tmp; mv {out}.tmp {out}")
    assert panes.wait_for(out).read_text()[19:] == "  /tmp  echo hello | wc -c\n"


def test_history_record_hands_on_the_exit_status_and_escapes_lines_and_tabs(linked):
    proc = bash(linked, "set -o history; history -s $'for i in 1\\ndo :\\ndone'; history -s $'a\\tb'; "
                        "false; _hist_record; echo $?; cut -f5- ~/.hist/log/*", local="_hist_log_start\n")
    assert proc.stdout == "1\nfor i in 1\\ndo :\\ndone\na\\tb\n"


def test_history_pane_setting_outside_tmux_changes_nothing(linked):
    script = 'echo "$HISTFILE"; [[ $PROMPT_COMMAND == *_hist_record* ]] && echo hooked; ls -A ~/.hist 2>&1'
    off = bash(linked, script)
    on = bash(linked, script, local="_hist_pane_start\n")
    assert (on.stdout, on.stderr) == (off.stdout, off.stderr)
    assert "hooked" not in on.stdout


def test_history_hgrep_refuses_bad_arguments_and_a_missing_log(linked):
    proc = bash(linked, "hgrep; echo $?; hgrep x y; echo $?; hgrep x")
    assert proc.stdout == "2\n2\n"
    assert proc.stderr == ("usage: hgrep PATTERN [N]\nusage: hgrep PATTERN [N]\n"
                           f"hgrep: no log in {linked}/.hist/log; switch the log on in 12-history.sh")


def test_history_hgrep_takes_backslashes_as_written_and_any_case_without_capitals(linked):
    (linked / ".hist" / "log").mkdir(parents=True)
    (linked / ".hist" / "log" / "2026-10").write_text("".join(
        f"2026-10-12 10:00:0{i}\th\t-\t/d\t{cmd}\n" for i, cmd in enumerate(["make a.py", "make abpy", "Make X"])))
    proc = bash(linked, r"hgrep 'a\.py'; hgrep make; hgrep Make")
    assert proc.stdout.replace("2026-10-12 10:00:0", "") == (
        "0  /d  make a.py\n"
        "0  /d  make a.py\n1  /d  make abpy\n2  /d  Make X\n"
        "2  /d  Make X\n")


def test_history_log_keeps_the_last_months_and_hgrep_reads_them_oldest_first(linked):
    logs = linked / ".hist" / "log"
    logs.mkdir(parents=True)
    year, month = map(int, time.strftime("%Y %m").split())
    def ago(n):
        y, m = divmod(year * 12 + month - 1 - n, 12)
        return f"{y:04d}-{m + 1:02d}"
    for n in 3, 2, 0:
        (logs / ago(n)).write_text(f"t\th\t-\t/d\techo {n}\n")
    (logs / "2000-saved").write_text("kept\n")
    proc = bash(linked, "hgrep echo; ls ~/.hist/log", before="DOTFILES_HIST_LOG_MONTHS=3\n",
                local="_hist_log_start\n")
    assert proc.stdout == f"t  /d  echo 2\nt  /d  echo 0\n2000-saved\n{ago(2)}\n{ago(0)}\n"


def test_history_a_new_shell_deletes_the_scratch_files_of_shells_gone(linked, tmp_path):
    runtime = tmp_path / "run"
    runtime.mkdir()
    dead = subprocess.run(["sh", "-c", "echo $$"], capture_output=True, text=True).stdout.strip()
    for name in f"bash-history.{dead}", f"bash-history.{os.getpid()}", "bash-history.x", "other.1":
        (runtime / name).write_text("")
    proc = bash(linked, 'ls "$XDG_RUNTIME_DIR" | grep -vx -e "bash-history.$$" -e "dots-fast\\..*"', env={"XDG_RUNTIME_DIR": str(runtime)}, local="_hist_log_start\n")
    assert proc.stdout == f"bash-history.{os.getpid()}\nbash-history.x\nother.1\n"


def test_history_unset_or_null_histfile_keeps_commands_out_of_everything(linked):
    proc = bash(linked, "set -o history; history -s secret; unset HISTFILE; _hist_record; "
                        "HISTFILE=/dev/null; history -s secret2; _hist_record; "
                        'grep -rsh secret ~/.hist "$_hist_shared"; echo end', local="_hist_log_start\n")
    assert (proc.stdout, proc.stderr) == ("end\n", "")


# ----------------------------------------------------------------------
# vim
# ----------------------------------------------------------------------


def vim(home, *commands, before=None, env=None):
    if before is not None:
        (home / ".vimrc.before").write_text(before)
    # -es prints :set queries on stdout; anything else needs :verbose, which
    # writes to stderr. One line per command, stripped, "Last set from" dropped.
    cmds = [c for command in commands
            for c in ("-c", command if command.startswith("set ") else "verbose " + command)]
    environment = fast_mode_apart(dict(os.environ, HOME=str(home), TERM="xterm-256color"), home)
    proc = subprocess.run(["vim", "-es", "-u", str(home / ".vimrc"), *cmds, "-c", "qall!"],
                          env=dict(environment, **(env or {})),
                          stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, timeout=30,
                          errors="replace")
    lines = [l.strip() for l in proc.stdout.splitlines() if l.strip() and "Last set from" not in l]
    return "\n".join(lines)


@needs("vim")
def test_vimrc_loads_every_module(linked):
    assert vim(linked, "DotfilesModules").splitlines() == VIM_MODULES


@needs("vim")
def test_vim_modules_each_leave_a_setting(linked):
    out = vim(linked, *("set %s?" % o for o in "hidden shiftwidth hlsearch wildmode foldmethod undofile mouse laststatus".split()))
    assert out.splitlines() == ["hidden", "shiftwidth=2", "hlsearch", "wildmode=longest:full,full",
                           "foldmethod=indent", "undofile", "mouse=a", "laststatus=2"]
    assert (linked / ".vim" / "tmp" / "undo").is_dir()


@needs("vim")
def test_vim_in_fast_mode_keeps_swap_files_in_tmpfs_unsynced_and_prunes_old_ones(linked):
    swap = linked.parent / "xdg-run" / "vim-swap"
    out = vim(linked, "set directory?", "set swapsync?", env={"DOTS_FAST_ACTIVE": "1"})
    assert out.splitlines() == [f"directory={swap}//", "swapsync="]
    assert oct(swap.stat().st_mode & 0o777) == "0o700" and (swap / ".pruned").exists()
    old, new = swap / "%old.swp", swap / "%new.swp"
    old.write_text(""), new.write_text("")
    day = 86400
    os.utime(old, (time.time() - 15 * day,) * 2)
    os.utime(swap / ".pruned", (time.time() - 2 * day,) * 2)
    vim(linked, "set directory?", env={"DOTS_FAST_ACTIVE": "1"})
    assert (old.exists(), new.exists()) == (False, True)
    assert vim(linked, "set directory?", "set swapsync?").splitlines() == ["directory=~/.vim/tmp/swap//",
                                                                          "swapsync=fsync"]
    # A directory others can read is not taken; the /dev/shm one cannot be made with this USER
    swap.chmod(0o755)
    out = vim(linked, "set directory?", env={"DOTS_FAST_ACTIVE": "1", "USER": "no/such"})
    assert out == "directory=~/.vim/tmp/swap//"


@needs("vim")
def test_vim_knobs_from_vimrc_before(linked):
    out = vim(linked, "set shiftwidth?", "set foldmethod?", "set expandtab?",
              before="let g:dotfiles_indent = 4\nlet g:dotfiles_foldmethod = 'marker'\n")
    assert out.splitlines() == ["shiftwidth=4", "foldmethod=marker", "expandtab"]


@needs("vim")
def test_vim_keys_map_leader_and_have_no_trailing_comment_garbage(linked):
    out = vim(linked, "nmap <leader>QQ", "nmap <C-h>", "xmap J",
              "echo map([',qa', ',p', ',P', ',q', ',w', ',Q', ',v', ',x', ',b', ',n', ',d', ',a', ',s', ',u', ',tw', ',tc'],"
              " 'maparg(v:val, \"n\")') maparg(',p', 'x') maparg(',P', 'x')")
    assert out.splitlines() == ["n  ,QQ         * :call <SNR>19_Close('!')<CR>", "n  <C-H>       * <C-W>h",
                                "x  J           * :move '>+1<CR>gv=gv",
                                "[':qall<CR>', '\"+p', '\"+P', '', '', '', '', '', '', '', '', '', '', '', '', ''] \"+p \"+P"]


@needs("vim")
def test_vim_status_line_reads_the_branch_without_turning_terminal_echo_on(linked):
    # A terminal's late answers to vim's startup queries (kitty's
    # P1+r...=... key codes) were echoed onto the status line while its git
    # ran with the terminal in cooked mode.
    fake = linked / "fakebin"
    fake.mkdir()
    (fake / "git").write_text('#!/bin/sh\nstty -a </dev/tty | grep -o -- " -\\?echo " >>"$HOME/echo"\necho main\n')
    (fake / "git").chmod(0o755)
    (linked / "d").mkdir()
    pid, fd = pty.fork()
    if pid == 0:                                     # pragma: no cover -- the child
        env = dict(os.environ, HOME=str(linked), TERM="xterm-256color", PATH=f"{fake}:{os.environ['PATH']}")
        os.execvpe("vim", ["vim", str(linked / "d" / "f.txt"), "-c", "redraw!", "-c", "qall!"], env)
    out = b""
    while select.select([fd], [], [], 5)[0]:
        try:
            out += os.read(fd, 65536)
        except OSError:                              # EIO: vim has exited
            break
    os.waitpid(pid, 0)
    os.close(fd)
    assert ((linked / "echo").read_text(), b"git:main" in out) == (" -echo \n", True)


def vim_on_a_pty(home, env, *commands):
    """Run vim on a pty with ENV over the environment (None drops a variable)"""
    pid, fd = pty.fork()
    if pid == 0:                                     # pragma: no cover (the child)
        full = {k: v for k, v in dict(os.environ, HOME=str(home), **env).items() if v is not None}
        args = [a for c in (*commands, "qall!") for a in ("-c", c)]
        os.execvpe("vim", ["vim", "-u", str(home / ".vimrc"), *args], full)
    while select.select([fd], [], [], 5)[0]:
        try:
            os.read(fd, 65536)
        except OSError:                              # EIO: vim has exited
            break
    os.waitpid(pid, 0)
    os.close(fd)


@needs("vim")
def test_vim_j_and_k_move_screen_lines_but_a_count_moves_buffer_lines(linked):
    (linked / "w.txt").write_text("a" * 300 + "\nb\nc\nd\ne\nf\ng\n")
    probe = f"call writefile([line('.') .. ',' .. col('.')], '{linked}/out', 'a')"
    vim_on_a_pty(linked, {"TERM": "xterm-256color"}, f"edit {linked}/w.txt",
                 "normal j", probe, "normal k", probe, "normal 5j", probe, "normal 4k", probe)
    lines = (linked / "out").read_text().splitlines()
    assert lines[0].startswith("1,") and lines[0] != "1,1"
    assert lines[1:] == ["1,1", "6,1", "2,1"]


@needs("vim")
def test_vim_inside_tmux_gets_the_sgr_mouse_and_focus_events_but_not_in_screen(linked):
    probe = f"call writefile([&ttymouse, &t_fe, &t_fd], '{linked}/out', 'a')"
    vim_on_a_pty(linked, {"TERM": "tmux-256color", "TMUX": None}, probe)
    vim_on_a_pty(linked, {"TERM": "screen-256color", "TMUX": "/tmp/tmux-1/default,1,0"}, probe)
    vim_on_a_pty(linked, {"TERM": "screen-256color", "TMUX": None}, probe)
    assert (linked / "out").read_text().splitlines() == [
        "sgr", "\x1b[?1004h", "\x1b[?1004l", "sgr", "\x1b[?1004h", "\x1b[?1004l", "xterm", "", ""]


@needs("vim")
def test_vim_comma_q_closes_the_window_and_deletes_its_buffer(linked):
    out = vim(linked, "edit a.txt | split b.txt | execute 'normal ,qq'"
              " | let g:b = [winnr('$'), buflisted(bufnr('b.txt')), bufloaded(bufnr('b.txt'))]",
              "split c.txt | call setline(1, 'changed') | silent! execute 'normal ,qq'"
              " | let g:kept = [winnr('$'), buflisted(bufnr('c.txt'))]",
              "execute 'normal ,QQ' | let g:dropped = [winnr('$'), buflisted(bufnr('c.txt'))]",
              "split | execute 'normal ,qq' | let g:shared = [winnr('$'), buflisted(bufnr('a.txt'))]",
              "echo [g:b, g:kept, g:dropped, g:shared]")
    assert out.splitlines()[-1] == "[[1, 0, 0], [2, 1], [1, 0], [1, 1]]"


def vim_edit(home, name, text, *commands):
    """The file NAME holding TEXT after vim runs COMMANDS on it, written with
    noautocmd so the strip-on-write autocmd hides nothing."""
    path = home / name
    path.write_text(text)
    args = [a for c in commands for a in ("-c", c)]
    subprocess.run(["vim", "-es", "-u", str(home / ".vimrc"), str(path), *args, "-c", "noautocmd wq"],
                   env=dict(os.environ, HOME=str(home), TERM="xterm-256color"), cwd=home, timeout=30)
    return path.read_text()


PY = "def f():\n    x = 1\n\n    # y = 2\n    return x\n"


@needs("vim")
@pytest.mark.parametrize("name, text, keys, expected", [
    ("a.py", PY, "normal gg2,cc", "# def f():\n#     x = 1\n\n    # y = 2\n    return x\n"),
    ("a.py", PY, "normal ggVG,cc", "# def f():\n#     x = 1\n\n#     # y = 2\n#     return x\n"),
    ("a.py", PY, "normal 2GVG,cc", "def f():\n    # x = 1\n\n    # # y = 2\n    # return x\n"),
    ("a.py", PY, "normal 4G,cc", "def f():\n    x = 1\n\n    y = 2\n    return x\n"),
    ("a.py", "    #x\n  #  y\n", "normal ggVG,cc", "    x\n   y\n"),
    ("a.c", "int x;\n  int y;\n", "normal ggVG,cc", "/* int x; */\n/*   int y; */\n"),
    ("a.c", "/* int x; */\n  /*int y;*/\n", "normal ggVG,cc", "int x;\n  int y;\n"),
    ("a.txt", "x\n", "set commentstring= | normal ,cc", "x\n"),
])
def test_vim_comma_cc_toggles_comments(linked, name, text, keys, expected):
    assert vim_edit(linked, name, text, keys) == expected


@needs("vim")
def test_vim_comma_cc_round_trips_and_gc_package_loads(linked):
    once = vim_edit(linked, "a.py", PY, "normal ggVG,cc")
    assert vim_edit(linked, "a.py", once, "normal ggVG,cc") == PY
    assert vim(linked, "echo maparg('gc', 'n')") == "comment.Toggle()"


@needs("vim")
@pytest.mark.parametrize("name, text, keys, expected", [
    ("s.txt", "c\na\nb\na\n", "normal ,ss", "a\na\nb\nc\n"),
    ("s.txt", "c\na\nb\na\n", "normal ,uu", "a\nb\nc\n"),
    ("s.txt", "c\nb\na\nz\n", "normal 2GV3G,ss", "c\na\nb\nz\n"),
    ("s.txt", "c\nb\nb\nz\n", "normal 2GV3G,uu", "c\nb\nz\n"),
    ("s.txt", "a\nb\n", "normal gg2,o", "a\n\n\nb\n"),
    ("r.txt", "foo Foo foo\n", 'execute "normal gg,rwBAR\\<CR>"', "BAR Foo BAR\n"),
    ("r.txt", "foo Foo foo\n", 'execute "normal gg,riBAR\\<CR>"', "BAR BAR BAR\n"),
    ("s.txt", "a\nb\n", "normal G,O", "a\n\nb\n"),
    ("i.py", "if x:\nfoo\n", "normal ,=", "if x:\n  foo\n"),
    ("j.json", '{"b": [1], "a": 1}\n', "normal ,j", '{\n  "b": [\n    1\n  ],\n  "a": 1\n}\n'),
    ("j.json", "{bad\n", "normal ,j", "{bad\n"),
    ("j.txt", 'x {"a": [1]} y\nz\n', 'normal gg0f{vf},j', 'x {\n  "a": [\n    1\n  ]\n} y\nz\n'),
    ("j.txt", 'x\n{"a": 1}\nz\n', "normal 2GV,j", 'x\n{\n  "a": 1\n}\nz\n'),
    ("j.txt", 'x {bad} y\n', "normal gg0f{vf},j", 'x {bad} y\n'),
    ("j.txt", 'k\n{"a": 1}\n', 'normal ggyy2GV,jGp', 'k\n{\n  "a": 1\n}\nk\n'),
    ("s.txt", "a\n", "normal gg$,id", "a" + __import__("time").strftime("%Y-%m-%d") + "\n"),
])
def test_vim_comma_editing_maps(linked, name, text, keys, expected):
    assert vim_edit(linked, name, text, keys) == expected


@needs("vim")
def test_vim_substitute_g_flag_means_every_match(linked):
    assert vim_edit(linked, "g.txt", "a a\na a\n", "1s/a/b/g", "2s/a/b/") == "b b\nb a\n"


@needs("vim")
def test_vim_comma_z_zooms_and_restores_and_comma_co_toggles_quickfix(linked):
    out = vim_edit(linked, "o.txt", "", "split", "normal ,z", "let g:z = winheight(0)", "normal ,z",
                   "normal ,co", "let g:open = len(getwininfo())", "normal ,co",
                   "call setline(1, [g:z > winheight(0), winheight(0) < &lines - 5, g:open, len(getwininfo())])")
    assert out == "1\n1\n3\n2\n"


@needs("vim")
def test_vim_comma_slash_greps_below_the_current_directory(linked):
    (linked / "g").mkdir()
    (linked / "g" / "x.txt").write_text("other\nneedle here\n")
    out = vim_edit(linked, "w.txt", "needle\n", "normal gg,/", "cclose",
                   "call setline(1, map(getqflist(), 'bufname(v:val.bufnr) . \":\" . v:val.lnum'))")
    assert sorted(os.path.normpath(l) for l in out.splitlines()) == ["g/x.txt:2", "w.txt:1"]


@needs("vim")
def test_vim_python_marks_column_100_in_slate_gray(linked):
    out = vim(linked, "edit x.py", "echo &l:colorcolumn synIDattr(hlID('ColorColumn'), 'bg#', 'gui')",
              "colorscheme shine", "echo synIDattr(hlID('ColorColumn'), 'bg#', 'gui')")
    assert out.splitlines()[-2:] == ["100 #3c4450", "#e4e8ee"]
@needs("vim")
def test_vim_local_override_wins(linked):
    (linked / ".vimrc.local").write_text("set shiftwidth=7\n")
    assert vim(linked, "set shiftwidth?") == "shiftwidth=7"


@needs("vim")
def test_vim_off_module_is_not_sourced(linked):
    assert "60-plugins" not in vim(linked, "DotfilesModules")


@needs("vim")
def test_vim_strips_trailing_whitespace_on_write_except_in_a_binary_file(linked):
    text, blob = linked / "t.txt", linked / "blob"
    text.write_bytes(b"ab \ncd\t\n")
    blob.write_bytes(b"ab \x00\t\ncd \n")
    for args in ([str(text)], ["-b", str(blob)]):
        subprocess.run(["vim", "-es", "-u", str(linked / ".vimrc"), *args, "-c", "wq"],
                       env=dict(os.environ, HOME=str(linked), TERM="xterm-256color"), timeout=30)
    assert (text.read_bytes(), blob.read_bytes()) == (b"ab\ncd\n", b"ab \x00\t\ncd \n")


@needs("vim")
@needs("vim")
@pytest.mark.parametrize("name, text, keys, expected", [
    ("a.conf", "    x\n", r'exe "normal! o#y\<Esc>"', "    x\n    #y\n"),
    ("a.txt", "for the record\n", r'exe "normal! oy\<Esc>"', "for the record\ny\n"),
])
def test_vim_new_lines_keep_the_indent_without_smartindent(linked, name, text, keys, expected):
    assert vim_edit(linked, name, text, keys) == expected


def test_vim_python_indents_two_and_tabs_show_their_width(linked):
    (linked / "a.py").write_text("x = 1\n")
    out = vim(linked, f"edit {linked}/a.py", "set shiftwidth?", "set tabstop?", "set softtabstop?",
              "set listchars?")
    assert out.split()[-4:] == ["shiftwidth=2", "tabstop=2", "softtabstop=-1",
                                "listchars=tab:»·,trail:·,nbsp:␣,extends:›,precedes:‹"]


@needs("vim")
def test_vim_comma_ww_strips_trailing_whitespace_and_tabs_but_not_in_make(linked):
    assert vim_edit(linked, "n.txt", "a \n\tb\t \n", "normal ,ww") == "a\n  b\n"
    assert vim_edit(linked, "Makefile", "all:\n\techo hi\n", "normal ,ww") == "all:\n\techo hi\n"
    assert vim_edit(linked, "v.txt", "a \n\tb \n\tc \n", "normal 2GV,ww") == "a \n  b\n\tc \n"


@needs("vim")
def test_vim_tmp_and_secret_files_leave_the_next_files_options_alone(linked):
    # linked is under /tmp; /dotfiles-nowhere/a.txt is a new file outside it
    (linked / "t.txt").write_text("")
    probe = "set backup? writebackup? swapfile? undofile? viminfo?"
    out = vim(linked, f"edit {linked}/t.txt", probe, "edit /dotfiles-nowhere/a.txt", probe,
              f"edit {linked}/k.gpg", probe, "set backupskip?")
    # -es runs the answers together: "writebackupnoswapfile"
    before, skip = out.split("backupskip=")
    viminfo = "viminfo='100,<50,s10,h,r/tmp,r/dev/shm"
    assert re.findall(r"(?:no)?(?:backup|writebackup|swapfile|undofile)|viminfo=\S*", before) == [
        "backup", "writebackup", "noswapfile", "noundofile", viminfo,
        "backup", "writebackup", "swapfile", "undofile", viminfo,
        "backup", "writebackup", "noswapfile", "noundofile", "viminfo="]
    assert skip.endswith("/tmp/*,/dev/shm/*,*.gpg,*.asc,*/.ssh/*,*/pass.*/*")


@needs("vim")
def test_vim_editorconfig_when_on_follows_the_project_but_keeps_encoding_and_line_ends(linked):
    (linked / ".vimrc.local").write_text("packadd! editorconfig\n")
    project = linked / "p"
    project.mkdir()
    (project / ".editorconfig").write_text("root = true\n[*]\nindent_size = 8\ntrim_trailing_whitespace = false\n")
    (project / "a.c").write_text("x \n")
    (linked / "c.txt").write_bytes(b"a\r\nb\r\n")
    (linked / "GNUmakefile").write_text("all:\n")
    out = vim(linked, f"edit {project}/a.c", "set shiftwidth? modified?", f"edit {linked}/c.txt",
              "set fileformat? modified?", f"edit {linked}/GNUmakefile", "set expandtab?")
    assert re.findall(r"shiftwidth=\d+|(?:no)?modified|fileformat=(?:dos|unix)|(?:no)?expandtab", out) == [
        "shiftwidth=8", "nomodified", "fileformat=dos", "nomodified", "noexpandtab"]
    # a real write, autocmds and all: the project keeps its trailing space,
    # the CRLF file its line ends
    for path, change in ((project / "a.c", "1s/$/ /"), (linked / "c.txt", "1s/a/A/")):
        subprocess.run(["vim", "-es", "-u", str(linked / ".vimrc"), str(path), "-c", change, "-c", "wq"],
                       env=dict(os.environ, HOME=str(linked), TERM="xterm-256color"), cwd=linked, timeout=30)
    assert ((project / "a.c").read_text(), (linked / "c.txt").read_bytes()) == ("x  \n", b"A\r\nb\r\n")


@needs("vim")
def test_vim_strips_trailing_whitespace_on_write_when_editorconfig_is_off(linked):
    (linked / "p").mkdir()
    (linked / "p" / ".editorconfig").write_text("root = true\n[*]\ntrim_trailing_whitespace = false\n")
    (linked / "p" / "a.c").write_text("x \n")
    subprocess.run(["vim", "-es", "-u", str(linked / ".vimrc"), str(linked / "p" / "a.c"), "-c", "wq"],
                   env=dict(os.environ, HOME=str(linked), TERM="xterm-256color"), cwd=linked, timeout=30)
    assert (linked / "p" / "a.c").read_text() == "x\n"


@needs("vim")
def test_vim_filetype_module_maps_pbs_scripts_to_sh(linked):
    (linked / "job.pbs").write_text("#!/bin/bash\n")
    assert vim(linked, f"edit {linked}/job.pbs", "set filetype?").endswith("filetype=sh")


# ----------------------------------------------------------------------
# tmux
# ----------------------------------------------------------------------


def tmux(home, *args):
    sock = f"dots-{os.getpid()}"
    env = dict(os.environ, HOME=str(home))
    env.pop("TMUX", None)
    return subprocess.run(["tmux", "-L", sock, "-f", str(home / ".tmux.conf"), "start-server", ";",
                           *args, ";", "kill-server"], env=env, capture_output=True, text=True, timeout=30)


@needs("tmux")
def test_tmux_conf_parses_and_each_module_sets_something(linked):
    proc = tmux(linked, "show", "-g", "mouse", ";", "show", "-g", "status-left", ";",
                "list-keys", "-T", "copy-mode-vi", "y", ";", "list-keys", "-T", "root", "F12", ";",
                "list-keys", "-T", "prefix", "|")
    assert proc.returncode == 0, proc.stderr
    assert proc.stderr == ""
    lines = proc.stdout.splitlines()
    assert lines[0] == "mouse on"
    assert lines[1].startswith('status-left "#[fg=colour114,bold] #S')
    assert "copy-pipe-and-cancel" in lines[2]
    assert "set-option key-table off" in lines[3]
    assert 'split-window -h -c "#{pane_current_path}"' in lines[4]


@needs("tmux")
def test_tmux_cursor_shape_override_keeps_its_escape(linked):
    # "\E" in double quotes reaches tmux as "E": the outer terminal then
    # prints "E[2 q" over vim's view instead of changing the cursor.
    proc = tmux(linked, "show", "-s", "terminal-overrides")
    assert r'] "*:Ss=\\E[%p1%d q:Se=\\E[2 q"' in proc.stdout


@needs("tmux")
def test_tmux_local_override_and_off_module(linked):
    (linked / ".tmux.conf.local").write_text("set -g history-limit 7\n")
    proc = tmux(linked, "show", "-g", "history-limit", ";", "show", "-g", "@plugin")
    assert proc.stdout.splitlines()[0] == "history-limit 7"
    assert "@plugin" not in proc.stdout             # 50-plugins.conf.off not read


def test_tmux_env_check_applies_the_file_once_and_keeps_the_status(linked, tmp_path):
    env_file = tmp_path / "s.env.41.3"
    env_file.write_text("export DISPLAY=:5\nunset XAUTHORITY\n")
    script = (f"XAUTHORITY=x; false; _tmux_env_check; echo $? $DISPLAY ${{XAUTHORITY-unset}}; "
              f"DISPLAY=mine; _tmux_env_check; echo $DISPLAY; "
              f"echo 'export DISPLAY=:6' >| {env_file}; _tmux_env_check; echo $DISPLAY; "
              f"_tmux_env_start; _tmux_env_start; echo \"$PS0\"")
    proc = bash(linked, script, env={"TMUX": f"{tmp_path}/s,41,3"})
    assert (proc.stdout, proc.stderr) == ("1 :5 unset\nmine\n:6\n${ _tmux_env_check; }\n", "")


class Clients:
    """A private tmux server running the applied configuration with the
    client-env settings switched on, one session, and terminals for clients
    to attach from."""

    def __init__(self, home, tmp_path):
        self.home, self.tmp = home, tmp_path
        self.sock = str(tmp_path / "tmux.sock")
        # The pane's shell starts with an XAUTHORITY the clients do not have
        self.env = shell_env(home, {"XAUTHORITY": "stale"})
        self.clients = []
        conf = (home / ".config/tmux/conf.d/45-client-env.conf").read_text()
        (home / ".tmux.conf.local").write_text(re.sub(r"(?m)^#(set-hook )", r"\1", conf))
        (home / ".bashrc.local").write_text("_tmux_env_start\n")
        self.tmux("-f", str(home / ".tmux.conf"), "new", "-d", "-s", "a", f"bash --rcfile {home}/.bashrc -i")

    def tmux(self, *args):
        proc = subprocess.run(["tmux", "-S", self.sock, *args], env=self.env, cwd=str(self.home),
                              capture_output=True, text=True, timeout=10)
        assert proc.returncode == 0, proc.stderr
        return proc.stdout

    def attach(self, **env):
        """A client attached from a terminal whose environment adds env;
        what tmux draws on it is read and dropped."""
        main, side = pty.openpty()
        env = {k: v for k, v in dict(self.env, **env).items() if k != "XAUTHORITY"}
        proc = subprocess.Popen(["tmux", "-S", self.sock, "attach", "-t", "a"], stdin=side, stdout=side,
                                stderr=side, env=env, start_new_session=True)
        os.close(side)
        threading.Thread(target=self.drain, args=(main,), daemon=True).start()
        self.clients.append(proc)
        wait_until(lambda: len(self.tmux("list-clients").splitlines()) == len(self.clients))
        return proc, main

    @staticmethod
    def drain(fd):
        try:
            while os.read(fd, 65536):
                pass
        except OSError:                 # EIO: the client has gone, nothing more to read
            pass

    def env_file(self):
        files = list(self.tmp.glob("tmux.sock.env.*"))
        return files[0].read_text() if len(files) == 1 else ""

    def type_on(self, client, display, command):
        """Type a key on the client, wait for the hook to write its
        display, then type command and wait for the file it writes."""
        os.write(client[1], b" ")
        wait_until(lambda: f"DISPLAY={display}\n" in self.env_file())
        out = self.tmp / f"out{len(list(self.tmp.glob('out*')))}"
        os.write(client[1], f"{command} > {out}.tmp; mv {out}.tmp {out}\r".encode())
        wait_until(out.exists)
        return out.read_text()

    def close(self):
        subprocess.run(["tmux", "-S", self.sock, "kill-server"], capture_output=True)
        for proc in self.clients:
            proc.kill()
            proc.wait()


def wait_until(condition):
    deadline = time.monotonic() + 10
    while not condition():
        assert time.monotonic() < deadline, "timed out"
        time.sleep(0.02)


@needs("tmux")
def test_tmux_env_follows_the_client_typed_on_last(linked, tmp_path):
    agents = [socket.socket(socket.AF_UNIX) for _ in range(2)]
    for n, agent in enumerate(agents, 1):
        agent.bind(str(tmp_path / f"agent{n}"))
    clients = Clients(linked, tmp_path)
    try:
        # Files of an earlier server and of a session that is gone, deleted
        # at the first run (env_file reads only a lone file)
        server = clients.tmux("display", "-p", "#{pid}").strip()
        for stale in ("1.0", f"{server}.99"):
            (tmp_path / f"tmux.sock.env.{stale}").write_text("export DISPLAY=:9\n")
        first = clients.attach(DISPLAY=":1", SSH_AUTH_SOCK=str(tmp_path / "agent1"))
        second = clients.attach(DISPLAY=":2", SSH_AUTH_SOCK=str(tmp_path / "agent2"))
        show = 'echo "$DISPLAY $SSH_AUTH_SOCK ${XAUTHORITY-unset}"'
        link = linked / ".ssh/agent.sock"
        # The pane's shell started before either client attached. It takes
        # the values of the client typed on, before the command it runs.
        assert clients.type_on(first, ":1", show) == f":1 {link} unset\n"
        assert os.readlink(link) == str(tmp_path / "agent1")
        assert clients.type_on(second, ":2", show) == f":2 {link} unset\n"
        assert os.readlink(link) == str(tmp_path / "agent2")
        assert clients.tmux("show-environment", "-t", "a", "DISPLAY") == "DISPLAY=:2\n"
        # The client typed on last leaves: the other one takes over
        second[0].kill()
        wait_until(lambda: "DISPLAY=:1\n" in clients.env_file())
        assert os.readlink(link) == str(tmp_path / "agent1")
    finally:
        clients.close()
        for agent in agents:
            agent.close()


# ----------------------------------------------------------------------
# git
# ----------------------------------------------------------------------


def git_config(home, *args):
    env = dict(os.environ, HOME=str(home))
    env.pop("GIT_CONFIG_GLOBAL", None)
    return subprocess.run(["git", "config", "--includes", "--global", *args], env=env,
                          capture_output=True, text=True).stdout.strip()


def test_gitconfig_every_include_contributes(linked):
    assert git_config(linked, "push.default") == "current"          # core
    assert git_config(linked, "color.branch.current") == "green bold"   # color
    assert git_config(linked, "alias.st") == "status -sb"           # aliases
    assert git_config(linked, "diff.algorithm") == "histogram"      # diff
    assert git_config(linked, "url.https://github.com/.insteadof") == "gh:"   # url
    assert git_config(linked, "commit.gpgsign") == ""               # signing is commented out


def test_gitconfig_leaves_the_editor_to_editor(linked):
    proc = git_script(linked, "unset GIT_EDITOR; EDITOR=nano VISUAL=nano git var GIT_EDITOR")
    assert proc.stdout == "nano\n"


def test_gitconfig_local_wins(linked):
    (linked / ".gitconfig.local").write_text("[user]\n\tname = Tester\n[push]\n\tdefault = simple\n")
    assert git_config(linked, "user.name") == "Tester"
    assert git_config(linked, "push.default") == "simple"


def git_script(home, script):
    env = dict(os.environ, HOME=str(home), GIT_AUTHOR_NAME="T", GIT_AUTHOR_EMAIL="t@example.com",
               GIT_COMMITTER_NAME="T", GIT_COMMITTER_EMAIL="t@example.com")
    env.pop("GIT_CONFIG_GLOBAL", None)
    return subprocess.run(["bash", "-c", script], cwd=str(home), env=env, capture_output=True, text=True)


def test_git_brclean_deletes_a_merged_branch_whose_name_contains_main(linked):
    proc = git_script(linked, "git init -q -b main r && cd r && git commit -q --allow-empty -m one && "
                              "git branch domain-fix && git branch old && git brclean >/dev/null && "
                              "git branch --format='%(refname:short)'")
    assert (proc.stdout, proc.stderr) == ("main\n", "")


def test_git_pr_and_mr_check_out_a_github_pull_request_and_a_gitlab_merge_request(linked):
    proc = git_script(linked, "git init -q --bare -b main o.git && git clone -q o.git c 2>/dev/null && cd c && "
                              "git commit -q --allow-empty -m one && git push -q -u origin main && "
                              "git commit -q --allow-empty -m pull && git push -q origin HEAD:refs/pull/3/head && "
                              "git commit -q --allow-empty -m merge && git push -q origin HEAD:refs/merge-requests/7/head && "
                              "git reset -q --hard main && git pr 3 2>/dev/null && git log --format=%s -1 && "
                              "git mr 7 2>/dev/null && git log --format=%s -1 && git branch --show-current")
    assert (proc.stdout, proc.stderr) == ("pull\nmerge\nmr-7\n", "")


def test_git_gone_skips_the_current_branch_and_deletes_the_rest(linked):
    proc = git_script(linked, "git init -q --bare -b main o.git && git clone -q o.git c 2>/dev/null && cd c && "
                              "git commit -q --allow-empty -m one && git push -q -u origin main && "
                              "git switch -q -c old && git push -q -u origin old && "
                              "git switch -q -c feat && git push -q -u origin feat && "
                              "git push -q origin --delete old feat && git gone >/dev/null; echo $?; "
                              "git branch --format='%(refname:short)'")
    assert (proc.stdout, proc.stderr) == ("0\nfeat\nmain\n", "")


def test_git_snapshot_stashes_a_restore_point_and_leaves_the_tree_as_it_was(linked):
    proc = git_script(linked, "git init -q -b main r && cd r && echo 1 > f && git add f && git commit -qm one && "
                              "echo 2 > f && echo u > untracked && git snapshot >/dev/null && cat f untracked && "
                              "git stash list --format=%s | sed 's/[0-9_:-]*$//' && git stash show -p --include-untracked "
                              "| grep -c '^+[2u]$'")
    assert (proc.stdout, proc.stderr) == ("2\nu\nOn main: snapshot \n2\n", "")


def test_git_snapshot_on_a_clean_tree_applies_no_older_stash(linked):
    proc = git_script(linked, "git init -q -b main r && cd r && echo 1 > f && git add f && git commit -qm one && "
                              "echo old > f && git stash -q && git snapshot; echo $?; cat f; git stash list | wc -l")
    assert (proc.stdout, proc.stderr) == ("No local changes to save\n0\n1\n1\n", "")


def fake_ctags(home, version="Universal Ctags 6.1.0"):
    """A ctags on PATH that writes the checked-out branch, or "plain" outside
    a repository, into its -f file; the shell preamble that puts it and
    ~/.local/bin first, with wait_for FILE TEXT for the background hooks."""
    fake = home / "fakebin"
    fake.mkdir(exist_ok=True)
    (fake / "ctags").write_text(
        f'#!/bin/sh\n[ "$1" = --version ] && {{ echo "{version}"; exit 0; }}\n'
        'out=tags; while [ $# -gt 0 ]; do [ "$1" = -f ] && out=$2; shift; done\n'
        'git rev-parse --abbrev-ref HEAD >"$out" 2>/dev/null || echo plain >"$out"\n')
    (fake / "ctags").chmod(0o755)
    return (f'export PATH="{fake}:{home}/.local/bin:$PATH"; wait_for() {{ for _ in $(seq 50); do '
            '[ "$(cat "$1" 2>/dev/null)" = "$2" ] && return; sleep 0.1; done; return 1; }; ')


@needs("vim")
def test_vim_comma_tg_builds_tags_with_git_ctags_in_a_repository_and_ctags_outside(linked):
    fake_ctags(linked)
    git_script(linked, "git init -q -b main r && cd r && git commit -q --allow-empty -m one && mkdir ../n")
    out = vim(linked, f"let $PATH = '{linked}/fakebin:{linked}/.local/bin:' . $PATH", f"edit {linked}/r/a.txt | execute 'normal ,tg'",
              f"edit {linked}/n/b.txt | cd {linked}/n | execute 'normal ,tg'",
              f"echo readfile('{linked}/r/tags') readfile('{linked}/n/tags') system('ls {linked}/r/.git/hooks/post-commit.d')")
    assert out.splitlines()[-1] == "['main'] ['plain'] ctags"


@needs("vim")
def test_vim_tags_found_upward_and_comma_t_maps_open_them(linked):
    (linked / "tags").write_text("foo\tf.txt\t/^foo$/\n")
    (linked / "f.txt").write_text("x\nfoo\n")
    (linked / "d").mkdir()
    (linked / "d" / "a.txt").write_text("foo\n")
    out = vim(linked, f"edit {linked}/d/a.txt",
              "execute 'normal ,tv' | let g:v = [winnr('$'), winwidth(0) < &columns, expand('%:t'), line('.')] | close",
              "execute 'normal ,th' | let g:h = [winnr('$'), winwidth(0) == &columns, expand('%:t')] | close",
              "execute 'normal ,tt' | let g:t = [tabpagenr('$'), expand('%:t')] | tabclose",
              "execute 'normal ,tp' | let g:p = [winnr('$'), expand('%:t')] | pclose",
              "echo [g:v, g:h, g:t, g:p, &tags]")
    assert out.splitlines()[-1] == "[[2, 1, 'f.txt', 2], [2, 1, 'f.txt'], [2, 'f.txt'], [2, 'a.txt'], './tags;,tags;']"


def test_git_fetch_keeps_a_local_tag_the_remote_does_not_have(linked):
    proc = git_script(linked, "git init -q --bare -b main o.git && git clone -q o.git c 2>/dev/null && cd c && "
                              "git commit -q --allow-empty -m one && git push -q -u origin main && "
                              "git tag mine && git fetch -q && git tag -l")
    assert (proc.stdout, proc.stderr) == ("mine\n", "")


def test_git_global_ignore_and_attributes_are_read(linked, tmp_path):
    repo = tmp_path / "repo"
    repo.mkdir()
    env = dict(os.environ, HOME=str(linked))
    subprocess.run(["git", "init", "-q"], cwd=repo, env=env, check=True)
    (repo / "a.swp").write_text("")
    (repo / "x.py").write_text("")
    out = subprocess.run(["git", "status", "--porcelain"], cwd=repo, env=env, capture_output=True, text=True).stdout
    assert out == "?? x.py\n"
    out = subprocess.run(["git", "check-attr", "diff", "x.py"], cwd=repo, env=env, capture_output=True, text=True).stdout
    assert out == "x.py: diff: python\n"


# ----------------------------------------------------------------------
# the rest
# ----------------------------------------------------------------------


def test_inputrc_is_read_by_readline(linked):
    proc = bash(linked, "bind -v | grep -E '^set (completion-ignore-case|show-all-if-ambiguous|bell-style)'",
                env={"INPUTRC": str(linked / ".inputrc")})
    assert proc.stdout == "set completion-ignore-case on\nset show-all-if-ambiguous on\nset bell-style none\n"


@needs("ssh")
def test_ssh_config_parses_and_local_include_wins(linked):
    (linked / ".ssh" / "config.local").write_text("Host box\n    HostName box.example\n    ServerAliveInterval 5\n")
    proc = subprocess.run(["ssh", "-F", str(linked / ".ssh" / "config"), "-G", "box"],
                          capture_output=True, text=True)
    assert proc.returncode == 0, proc.stderr
    settings = dict(l.split(" ", 1) for l in proc.stdout.splitlines() if " " in l)
    assert settings["hostname"] == "box.example"
    assert settings["serveraliveinterval"] == "5"
    assert settings["controlmaster"] == "auto"
    assert settings["addkeystoagent"] in ("yes", "true")


@needs("ssh")
def test_ssh_control_socket_path_fits_the_unix_socket_limit_for_a_long_host_name(linked):
    # ssh adds 17 characters while it creates the socket; sun_path holds 104
    # (BSD) to 108 bytes. The path is a hash, whatever the host's name.
    host = "node" + "x" * 60 + ".cluster.example.edu"
    proc = subprocess.run(["ssh", "-F", str(linked / ".ssh" / "config"), "-G", host],
                          capture_output=True, text=True)
    path = dict(l.split(" ", 1) for l in proc.stdout.splitlines() if " " in l)["controlpath"]
    assert len(path) + 17 < 104, path


@needs("gdb")
def test_gdbinit_parses(linked):
    proc = subprocess.run(["gdb", "-batch", "-nx", "-x", str(linked / ".gdbinit"), "-ex", "show print pretty"],
                          env=dict(os.environ, HOME=str(linked)), capture_output=True, text=True, timeout=30)
    assert proc.stderr == "" and proc.stdout.strip() == "Pretty formatting of structures is on."


@needs("gdb")
def test_gdbinit_does_not_run_a_strange_directorys_gdbinit(linked, tmp_path):
    # set auto-load safe-path / ran any directory's .gdbinit, shell commands included.
    (tmp_path / ".gdbinit").write_text("shell touch planted-ran\n")
    proc = subprocess.run(["gdb", "-batch", "-ex", "show print pretty"], cwd=tmp_path,
                          env=dict(os.environ, HOME=str(linked)), capture_output=True, text=True, timeout=30)
    assert proc.stdout.splitlines()[-1] == "Pretty formatting of structures is on."
    assert "auto-loading has been declined" in proc.stderr
    assert not (tmp_path / "planted-ran").exists()


@needs("curl")
def test_curlrc_parses(linked):
    proc = subprocess.run(["curl", "--config", str(linked / ".curlrc"), "--max-time", "1", "http://127.0.0.1:1/"],
                          capture_output=True, text=True, timeout=30)
    assert "Warning" not in proc.stderr and "error" not in proc.stderr.lower().replace("connection refused", "")
    assert proc.returncode == 7                        # couldn't connect: the config itself was fine


@needs("wget")
def test_wgetrc_parses(linked):
    proc = subprocess.run(["wget", "-q", "--tries=1", "--timeout=1", "http://127.0.0.1:1/"],
                          env=dict(os.environ, HOME=str(linked)), capture_output=True, text=True, timeout=30)
    assert "wgetrc" not in proc.stderr and "Error" not in proc.stderr


class RangeHandler(http.server.BaseHTTPRequestHandler):
    """Serves self.server.body with Last-Modified and byte ranges, as most servers do."""

    def send_body(self, with_body):
        data, start = self.server.body, 0
        if "Range" in self.headers:
            start = int(self.headers["Range"].split("=")[1].split("-")[0])
            if start >= len(data):
                self.send_response(416)
                self.send_header("Content-Range", f"bytes */{len(data)}")
                self.end_headers()
                return
            self.send_response(206)
            self.send_header("Content-Range", f"bytes {start}-{len(data) - 1}/{len(data)}")
        else:
            self.send_response(200)
        self.send_header("Content-Length", str(len(data) - start))
        self.send_header("Last-Modified", email.utils.formatdate(self.server.mtime, usegmt=True))
        self.send_header("Content-Type", "text/plain")
        self.end_headers()
        if with_body:
            self.wfile.write(data[start:])

    def do_GET(self):
        self.send_body(True)

    def do_HEAD(self):
        self.send_body(False)

    def log_message(self, *args):
        pass


@needs("wget")
@pytest.mark.parametrize("new", [b"VERSION TWO, longer than before\n", b"v2\n"])
def test_wgetrc_refetch_replaces_a_changed_file(linked, tmp_path, new):
    # continue = on with wget -N resumed from the old file's size: the old
    # prefix spliced onto the new tail, or a shorter file kept stale.
    server = http.server.HTTPServer(("127.0.0.1", 0), RangeHandler)
    threading.Thread(target=server.serve_forever, daemon=True).start()
    url = f"http://127.0.0.1:{server.server_port}/f.txt"
    try:
        for body, mtime in ((b"version one\n", 1_000_000_000), (new, 1_100_000_000)):
            server.body, server.mtime = body, mtime
            proc = subprocess.run(["wget", "-q", "-N", url], cwd=tmp_path, env=dict(os.environ, HOME=str(linked)),
                                  capture_output=True, text=True, timeout=30)
            assert proc.returncode == 0, proc.stderr
    finally:
        server.shutdown()
    assert (tmp_path / "f.txt").read_bytes() == new


@needs("wget")
def test_wgetrc_lets_no_clobber_keep_a_file(linked, tmp_path):
    # timestamping = on made wget -nc refuse to run at all.
    server = http.server.HTTPServer(("127.0.0.1", 0), RangeHandler)
    threading.Thread(target=server.serve_forever, daemon=True).start()
    server.body, server.mtime = b"new\n", 1_100_000_000
    (tmp_path / "f.txt").write_bytes(b"old\n")
    try:
        proc = subprocess.run(["wget", "-q", "-nc", f"http://127.0.0.1:{server.server_port}/f.txt"],
                              cwd=tmp_path, env=dict(os.environ, HOME=str(linked)),
                              capture_output=True, text=True, timeout=30)
    finally:
        server.shutdown()
    assert (proc.returncode, proc.stderr) == (0, "")
    assert (tmp_path / "f.txt").read_bytes() == b"old\n"


@needs("dircolors")
def test_dircolors_parses(linked):
    proc = subprocess.run(["dircolors", "-b", str(linked / ".dircolors")], capture_output=True, text=True)
    assert proc.returncode == 0 and proc.stdout.startswith("LS_COLORS=")


@needs("dircolors")
def test_ls_under_dots_fast_paths_reads_the_directory_and_stats_nothing(linked):
    # In a directory that can be read but not searched, every stat fails with an error
    script = ('command mkdir -p slow/locked; touch slow/locked/f{1..5}; chmod +x slow/locked/f1; '
              'chmod a-x slow/locked; full=$LS_COLORS; ls_errors() { '
              'command ls --color=always ~/slow/locked 2>&1 >/dev/null | wc -l; }; '
              'ls_errors; cd slow; _dots_fast_cwd; ls_errors; cd ~; _dots_fast_cwd; ls_errors; '
              '[[ $LS_COLORS == "$full" ]] && echo restored; chmod u+x slow/locked')
    proc = bash(linked, script, env={"DOTS_FAST_PATHS": "~/slow"})
    assert proc.stdout.split() == ["5", "0", "5", "restored"]


def test_git_under_dots_fast_paths_looks_at_less_and_keeps_a_config_count_set_before(linked):
    script = ('show() { echo "${GIT_CONFIG_COUNT-unset} ${GIT_CONFIG_KEY_1-unset} $_GIT_UNTRACKED" '
              '"$(git config core.checkStat)" "$(git config core.trustctime)" "$(git config core.untrackedCache)" '
              '"$(git config color.ui)"; }; '
              'command mkdir slow; show; cd slow; _dots_fast_cwd; show; cd ~; _dots_fast_cwd; show')
    env = {"DOTS_FAST_PATHS": "~/slow", "GIT_CONFIG_COUNT": "1", "GIT_CONFIG_KEY_0": "color.ui",
           "GIT_CONFIG_VALUE_0": "never"}
    proc = bash(linked, script, env=env)
    assert proc.stdout.splitlines() == ["1 unset     never", "4 core.untrackedCache normal minimal false true never",
                                        "1 unset     never"]


def test_tab_under_dots_fast_paths_lists_without_colors_or_type_marks(linked):
    script = ('stats() { bind -v | command grep -E " (colored|visible)-stats " | tr "\\n" " "; echo; }; '
              'command mkdir slow; stats; cd slow; _dots_fast_cwd; stats; cd ~; _dots_fast_cwd; stats')
    proc = bash(linked, script, env={"DOTS_FAST_PATHS": "~/slow"})
    on, off = "set colored-stats on set visible-stats on ", "set colored-stats off set visible-stats off "
    assert proc.stdout.splitlines() == [on, off, on]


@needs("dircolors")
def test_ls_fast_colors_links_as_links_when_the_colors_follow_them(linked):
    dircolors = linked / ".dircolors"
    dircolors.unlink()
    dircolors.write_text("LINK target\nEXEC 01;32\n")
    proc = bash(linked, 'echo "$LS_COLORS"', env={"DOTS_FAST": "on"})
    assert proc.stdout.endswith(":ln=01;36:ex=00:su=00:sg=00:ca=00:tw=00:ow=00:st=00:or=00:mi=00:mh=00\n")


def test_pythonrc_imports_and_history(linked):
    env = dict(os.environ, HOME=str(linked), PYTHONSTARTUP=str(linked / ".config/python/pythonrc.py"))
    proc = subprocess.run(["python3", "-i"], input="print(pp.__name__, Path.__name__, json.__name__)\n",
                          env=env, capture_output=True, text=True, timeout=30)
    assert "pprint Path json" in proc.stdout


@needs("xrdb")
def test_xresources_parses(linked):
    proc = subprocess.run(["xrdb", "-n", str(linked / ".Xresources")], capture_output=True, text=True)
    assert proc.returncode == 0 and "XTerm*scrollTtyOutput:\tfalse" in proc.stdout


@needs("nano")
def test_nanorc_has_no_unknown_options(linked):
    proc = subprocess.run(["nano", "--rcfile", str(linked / ".nanorc"), "--version"],
                          capture_output=True, text=True, timeout=10)
    assert "Unknown" not in proc.stderr and "Error" not in proc.stderr


# ----------------------------------------------------------------------
# on a real terminal
# ----------------------------------------------------------------------


def pty_session(home, typed, before="", local="", seconds=3.0, argv=None):
    """An interactive bash on a pseudo-terminal: wait for the first prompt,
    type each line of `typed`, and return everything the terminal received.
    Pipes would take the other branch of every is-a-terminal check (65-title
    installs nothing without one)."""
    import pty
    import select
    import time
    (home / ".bashrc.before").write_text(before)
    (home / ".bashrc.local").write_text(local)
    pid, fd = pty.fork()
    if pid == 0:                                     # pragma: no cover -- the child
        os.chdir(str(home))
        env = {k: v for k, v in os.environ.items() if k not in ("PROMPT_COMMAND", "DOTFILES_DIR", "TMUX")}
        env.update(HOME=str(home), TERM="xterm-256color")
        os.execvpe("bash", argv or ["bash", "--rcfile", str(home / ".bashrc"), "-i"], env)
    out, sent, deadline = b"", False, time.time() + seconds
    while time.time() < deadline:
        ready, _, _ = select.select([fd], [], [], 0.05)
        if ready:
            try:
                out += os.read(fd, 65536)
            except OSError:
                break
        if not sent and b"$ " in out:
            for line in typed:
                os.write(fd, line.encode() + b"\r")
                time.sleep(0.4)
            sent = True
    os.kill(pid, 9)
    os.waitpid(pid, 0)
    os.close(fd)
    return out.decode(errors="replace")


def test_prompt_shows_a_failed_command_even_with_the_title_module(linked):
    # 65-title's hook runs before prompt_build and used to hand it its own
    # exit status, so the prompt said ✓ after `false` on every terminal.
    screen = pty_session(linked, ["false"])
    assert "\x1b]0;" in screen                      # the title module is active
    assert "✗ 1" in screen


def test_prompt_sets_no_debug_trap_and_keeps_the_space_before_the_dollar(linked):
    screen = pty_session(linked, ["echo T[$(trap -p DEBUG)]"])
    assert "T[]" in screen
    assert "✓\x1b[0m $ " in screen


def test_title_shows_the_running_command_when_switched_on(linked):
    line = next(l for l in (REPO / "dot_config/bash/rc.d/65-title.sh").read_text().splitlines()
                if l.startswith("#PROMPT_COMMAND="))
    screen = pty_session(linked, ["sleep 0.2", "trap -p DEBUG", "false"],
                         local="trap ': kept' DEBUG\n" + line[1:] + "\n")
    assert "\x1b]0;sleep 0.2\x07" in screen
    assert ": kept; _title_command" in screen       # a DEBUG trap already set is kept
    assert "✗ 1" in screen                          # and the exit status still reaches the prompt


def test_title_collapses_home_only_at_a_path_boundary(linked):
    sibling = linked.parent / (linked.name + "2")
    sibling.mkdir()
    screen = pty_session(linked, [f"cd {sibling}"])
    assert f": {sibling}\x07" in screen             # was ~2
    (linked / "sub").mkdir()
    screen = pty_session(linked, ["cd sub"])
    assert ": ~/sub\x07" in screen


# What a system file does, run from .bashrc.before ahead of every module:
# TMOUT and LIMIT read-only and exported. The rest marks the first shell's
# process ID, a temporary directory to find the swap's file in, and two key
# bindings and a trap a new bash would not have.
OVERRIDE_BEFORE = """readonly TMOUT=60 LIMIT=1; export TMOUT LIMIT
mkdir -p ~/tmp; TMPDIR=~/tmp; echo "start:$$"
bind '"\\eq": "macro"'; bind -x '"\\ew": echo widget'; trap 'echo trapped' USR2
DOTFILES_OVERRIDE=(TMOUT 'LIMIT=two words' 'HISTSIZE=777')
"""

# After the swap: the process ID, TMOUT in the shell and the environment,
# the listed value, ENV, files left in ~/tmp, $0, then the configuration.
OVERRIDE_TYPED = ['echo "now:$$:${TMOUT-gone}:$(env | grep -c ^TMOUT=):$HISTSIZE:${ENV-none}:$(ls ~/tmp | wc -l):$0"',
                  "declare -p LIMIT", "type -t mkcd; alias ll; shopt -p autocd; set -o | command grep -w posix",
                  "bind -s | command grep eq; bind -X | command grep ew; kill -USR2 $$", "false"]


def test_override_swaps_the_shell_for_a_read_only_variable_and_keeps_the_rest(linked):
    screen = pty_session(linked, OVERRIDE_TYPED, before=OVERRIDE_BEFORE)
    pid = re.search(r"start:(\d+)", screen)[1]
    assert screen.count("start:") == 1              # the new shell read no startup file
    assert "bash:" not in screen                    # and restored everything without an error
    assert f"now:{pid}:gone:0:777:none:0:bash\r\n" in screen
    assert 'declare -x LIMIT="two words"' in screen
    assert "function\r\nalias ll='ls -alFh'\r\nshopt -s autocd\r\nposix" in screen
    assert re.search(r"posix\s+off", screen)
    assert '"\\eq": "macro"' in screen and '"\\ew" "echo widget"' in screen
    assert "\r\ntrapped\r\n" in screen
    assert "✗ 1" in screen                          # the prompt still has its exit status


def test_override_in_a_login_shell_swaps_after_the_rest_of_bash_profile(linked):
    # The lines after ~/.bashrc in ~/.bash_profile (tmux, startx) still run
    profile = (REPO / "dot_bash_profile").read_text()
    sourced = "[[ -r ~/.bashrc ]] && source ~/.bashrc\n"
    assert sourced in profile
    (linked / ".bash_profile").unlink()
    (linked / ".bash_profile").write_text(profile.replace(sourced, sourced + 'echo "after:${TMOUT-gone}"\n'))
    screen = pty_session(linked, ['echo "now:$$:${TMOUT-gone}"; shopt -p login_shell'],
                         before=OVERRIDE_BEFORE, argv=["bash", "-l"])
    pid = re.search(r"start:(\d+)", screen)[1]
    assert "after:60" in screen
    assert f"now:{pid}:gone\r\nshopt -s login_shell" in screen


def test_override_sets_and_unsets_in_place_without_read_only_names(linked):
    proc = bash(linked, 'echo "${GONE-unset}"; declare -p KEEP', env={"GONE": "1", "KEEP": "old"},
                before="DOTFILES_OVERRIDE=(GONE 'KEEP=new value' 'bad-name=1')\n")
    assert proc.stdout == 'unset\ndeclare -x KEEP="new value"\n'
    assert "DOTFILES_OVERRIDE: not a variable name: bad-name" in proc.stderr


def test_override_leaves_a_command_shell_alone(linked):
    # bash -ic (editors read the environment this way) would lose its
    # command. On a terminal, which a swap needs, and through a pipe.
    before = "readonly TMOUT=60; GONE=1\nDOTFILES_OVERRIDE=(TMOUT GONE)\n"
    command = 'echo "ran:$TMOUT:${GONE-unset}"'
    screen = pty_session(linked, [], before=before, seconds=1.5,
                         argv=["bash", "--rcfile", str(linked / ".bashrc"), "-i", "-c", command])
    assert "ran:60:unset" in screen
    assert bash(linked, command, before=before).stdout == "ran:60:unset\n"
def test_ssh_agent_module_starts_one_agent_and_later_shells_reuse_it(linked):
    off = linked / ".config/bash/rc.d/25-ssh-agent.sh.off"
    os.symlink(os.readlink(off), linked / ".config/bash/rc.d/25-ssh-agent.sh")
    env = {"SSH_AUTH_SOCK": "", "SSH_AGENT_PID": ""}
    first = bash(linked, "echo $SSH_AGENT_PID", env=env).stdout.strip()
    try:
        assert first.isdigit(), "no agent was started"          # used to think one was running
        assert (linked / ".ssh" / "agent.env").is_file()
        assert bash(linked, "echo $SSH_AGENT_PID", env=env).stdout.strip() == first
    finally:
        if first.isdigit():
            os.kill(int(first), 15)
