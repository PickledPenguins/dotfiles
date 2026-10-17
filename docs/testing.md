# Testing

Back to the [README](../README.md).

## Suites and gates

| Command | What | Runs when | Time |
|---------|------|-----------|------|
| `tests/run-tests.sh` (`fast`) | unit, interface, safety and docs tests of `dots`, in-process | before every push, on each pushed commit (the packaged `test-push` hook, installed switched off by `tests/run-tests.sh hook`; `git hooks on test-push` switches it on) | ~4 s |
| `tests/run-tests.sh long` | the applied configuration read by the real programs, every setting that is off switched on and loaded, the example catalog, and the prompt toolkit's bats suite (~45 s of it) | before a release, after any module change | ~140 s |
| `tests/run-tests.sh all` | both | | ~145 s |
| `tests/run-tests.sh cov` | fast suite under coverage; **fails below 100%** line and branch (`tests/coveragerc`) | with `fast` on a `dots` change | ~3 s |
| `tests/run-tests.sh mutate` | every mutant in `tests/mutants.txt` applied to `dots` with `breaks-it`; **fails if any survives** | on a `dots` change | ~1 min |
| `tests/run-tests.sh mutate-shell` | every mutant in `tests/shell-mutants.txt` applied to a copy of the checkout under `.build/mutate-shell` with `breaks-it`, each checked by its own long-test subset or toolkit bats file; **fails if any survives, or if its line is no longer in the file (stale)**; exits 2 first if a TESTS fails with no mutant applied (a `-k` selecting nothing, bats missing), which would read as every mutant caught | on a change to a hook, a bash module, `layout.sh` or the toolkit's git cache | ~6 min |
| `tests/run-tests.sh perf` | `tests/perf.py`: the median of 15 interactive bash starts and of a warm `prompt_build` at the top of the checkout, outside tmux and inside it with a stub `tmux`, in a temporary linked home; **fails more than 25% over this machine's baseline**. Needs no pytest | on a module or prompt change; before each push once the packaged `perf-push` hook is switched on (`tests/run-tests.sh hook` installs it off; `git hooks on perf-push`) | ~6 s |

`tests/run-tests.sh perf` keeps one baseline per host name in
`perf-baseline.json` in the git directory (`.git/`, shared by every
worktree, so the hook's temporary checkout finds it). The first run on a
host records it, as does `tests/run-tests.sh perf --rebaseline` after a
slowdown that is accepted, and a measure the host's baseline lacks is
recorded on its own; `--runs N` and `--baseline FILE` change the
count and the file. A failure names the measure over its limit;
`DOTFILES_DEBUG=1 bash -i -c true` then times each module.

Anything after the suite name goes to pytest (`tests/run-tests.sh fast -k add`).
pytest comes from `python3` on `PATH`; where that one has none (the
system Python, as in a commit from a shell with no conda environment
active), the runner reruns itself under `in-env` from the skills tools,
whose default environment has it, and otherwise stops with exit 2 and a
message naming the interpreter.
Generated files (coverage data) land in `.build/`; the pytest cache is
disabled. Nothing here touches the real home directory: every test gets a
temporary `HOME` through the `home` fixture.

## Numbers (2026-10-16, this machine, measured on the commit that added this line)

- fast: 440 tests, 3.5 s. long: 386 passed and 6 skipped (programs not
  installed here: conda, sqlite3, ripgrep, matplotlib in the test
  interpreter; no loader for `~/.screenrc`; settings whose `Needs:`
  program is missing), 140 s, of which the toolkit's bats tests are
  about 45 s. A gdb built without debuginfod support passes the
  debuginfod setting.
- coverage of `dots`: 100% lines (392), 100% branches (166); floor 100.
- mutation: 60 mutants, 60 caught, 0 survivors. The list is hand-written
  (no mutmut here), one mutant per decision in the script: each attribute
  prefix, the ignore matching, the root-dotfile skip, the home-directory
  guard, each state classification, each mode bit, the force/dry-run
  branches, every exit code, the `add` attribute inference, path
  selection, and the options parser and filters. A new branch in `dots`
  needs a line there.
- shell mutation: 55 mutants, 55 caught, 0 survivors, 0 stale: the git
  hooks and the dispatcher, `git hooks`, the `20-path.sh` helpers and
  `path_clash`, `up`, `bd`, `cdg`, `retry`, `_title_arm`, `_venv_auto`, the
  prompt rows in `layout.sh`, and the toolkit's git cache and collector
  touch. The first runs had 5 survivors; four tests were added and one
  equivalent mutant dropped (the list says which). ~6.5 min.
- performance (2026-10-13, 4 cores, load 0.5): an interactive start 70 ms
  median (68 to 74 over 15), a warm `prompt_build` 13.5 ms in this
  repository, 16 ms with a stub `tmux`, 12 ms outside git; `perf` takes
  ~6 s. `dots apply` on
  this repository (112 targets, 2026-10-16) is ~85 ms, not gated.

## Layout

| File | Covers | Suite |
|------|--------|-------|
| `tests/conftest.py` | loads `dots` by path; `home`, `src`, `run`, `linked` (this checkout applied) fixtures; `run_subprocess`; umask 022 for every test, whatever the caller's | |
| `tests/test_dots_unit.py` | every function in `dots` called directly, including a seeded 500-case round-trip property test for the naming | fast |
| `tests/test_dots_cli.py` | every subcommand's exact output, state change and exit code; argparse behavior as a subprocess | fast |
| `tests/test_dots_safety.py` | destructive paths (`--force`, `unlink`, `forget`), escapes from `$HOME`, names that map to `~`, modes, odd names, unreadable ignore file, backup collisions | fast |
| `tests/test_docs.py` | the documentation against the code, both directions (see below) | fast |
| `tests/test_config_integration.py` | the repository applied into a temporary `HOME`; bash, vim, tmux, git, ssh, readline, gdb, curl, wget, python, xrdb, nano read it; each module asserted by a setting only it provides; knobs and hook files; on a pseudo-terminal, the prompt's exit status beside the title module and the title's running command | long |
| `tests/test_options.py` | the [options format](configuration.md#the-options-format): every file declares it and describes every setting (fast); every setting that is off, switched on alone, loads in its real program -- bash, vim, tmux, git, ssh, readline, gdb, curl, wget, nano (on a pty), xrdb, conda, pip, python, IPython, matplotlib, kitty, sqlite, ripgrep, ctags, systemd (long) | fast + long |
| `tests/test_git_hooks.py` | `git hooks` install, list, show, on, off and remove in real repositories; the dispatcher's order, failure and stdin rules; each packaged hook refusing and passing; `update` following the packaged hooks as they change; the template `git hooks template` writes matching what install leaves; `git ctags` on top | long |
| `tests/test_runner.py` | `tests/run-tests.sh` finding pytest: `python3`'s, else through `in-env`, else exit 2; `hook` and `perf` need none | fast |
| `tests/perf.py`, `tests/test_perf.py` | the `perf` gate; its baseline and verdict with the timing replaced (fast), one real measurement (long) | fast + long |
| `tests/test_examples.py` | the example catalog: 53 cases, output compared to `expected.txt` after path normalization (argparse's quoting of choices, which differs between Python versions, is dropped) | long |
| `tests/examples/` | `simple/` 16, `moderate/` 13, `complex/` 10, `failures/` 14; each with `README.md`, `case.sh`, `expected.txt` | |
| `tests/mutants.txt`, `tests/shell-mutants.txt`, `tests/coveragerc` | the gates | |

Integration tests for programs not installed skip by name
(`needs("tmux")`), so a missing program is visible in the report rather
than passing silently.

## Standard

- A test asserts the value: the exact lines printed, the exit code, the
  link target, the mode. "It ran" is not a test.
- A bug fix lands with the test that reproduces it, named for the bug
  (`test_add_refuses_paths_that_escape_home_via_dotdot`).
- A new `dots` branch needs: a unit or CLI test, a mutant line, and a
  catalog case if a user would type it.
- A new module needs: its name in `BASH_MODULES`/`VIM_MODULES`, one
  assertion that only it can satisfy, and its rows in
  `docs/configuration.md` (the docs test enumerates modules from disk).
- Never weaken or delete a test to make a suite pass.

## The documentation test

`tests/test_docs.py` derives the surface from the code at run time and
fails when any of it is missing from the document that owns it:

- every subcommand, flag and exit code in `dots` -> `docs/cli.md`
- every `DOTFILES_*` and `g:dotfiles_*` knob read by a module, and every
  module file in `rc.d/`, `dot_vim/rc/`, `conf.d/`, `dot_config/git/` ->
  `docs/configuration.md`
- every hook file a loader reads -> `docs/configuration.md`
- every top-level target of `dots managed` -> `docs/configuration.md`
- every packaged git hook, by name and events -> `docs/configuration.md`;
  each one's header is well formed and its `config:` line names exactly
  the `hooks.*` settings it reads; the `git hooks` completion offers
  exactly the subcommands of its usage line
- the README's example blocks are the recorded output of named catalog
  cases; the README stays under 150 lines; every file in `docs/` is linked
  from the README; no internal link or anchor is dead

## Example catalog

Each case is a script run from a fresh `HOME` with `dots` on `PATH`; the
output, with paths normalized to `SRC`/`HOME`/`TMP` and timestamps to
`TS`, must equal `expected.txt`. `python3 tests/test_examples.py NAME`
prints a case; `--write` re-records it after an intended change. Complex
cases and `moderate/08`-`10` copy this repository as the source and run the
real configuration. The catalog README is `tests/examples/README.md`.

## What is not measured

- No load, concurrency or scaling tests: `dots` is single-process and
  bounded by the number of dotfiles.
- The prompt toolkit's own behavior beyond its bats suite: the long suite
  runs `bats tests` in `dot_config/bash/prompt/toolkit/` and requires
  every test to pass (skipped where `bats` is not installed), and checks
  each layout builds a PS1, the exit status shown beside the title module,
  and a hostile directory name shown as typed. The pre-push hook does
  not run bats.
- Programs absent on the machine the suite runs on (screen, ctags, delta)
  are skipped, not faked; so is a setting whose `Needs:` line names a
  missing program or file.
- A switched-on setting is loaded, not exercised: an alias to a missing
  program, or a key binding that does the wrong thing, still passes.
  Values are checked only where the program checks them (bash, vim, tmux,
  conda, kitty, matplotlib, gdb); git and ssh are checked for syntax and
  option names, pip and conda keys against the programs' own option lists.
