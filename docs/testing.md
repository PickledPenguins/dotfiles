# Testing

Back to the [README](../README.md).

## Suites and gates

| Command | What | Runs when | Time |
|---------|------|-----------|------|
| `./run-tests.sh` (`fast`) | unit, interface, safety and docs tests of `dots`, in-process | before every commit (`.git/hooks/pre-commit`, installed by `./run-tests.sh hook`) | ~2 s |
| `./run-tests.sh long` | the applied configuration read by the real programs, and the example catalog | before a release, after any module change | ~22 s |
| `./run-tests.sh all` | both | | ~24 s |
| `./run-tests.sh cov` | fast suite under coverage; **fails below 95%** line and branch (`tests/coveragerc`) | with `fast` on a `dots` change | ~3 s |
| `./run-tests.sh mutate` | every mutant in `tests/mutants.txt` applied to `dots` with `breaks-it`; **fails if any survives** | on a `dots` change | ~1 min |

Anything after the suite name goes to pytest (`./run-tests.sh fast -k add`).
Generated files (coverage data) land in `.build/`; the pytest cache is
disabled.  Nothing here touches the real home directory: every test gets a
temporary `HOME` through the `home` fixture.

## Numbers (commit `de70691`, 2026-09-20, this machine)

- fast: 108 tests, 1.7 s.  long: 141 tests, 21.5 s.
- coverage of `dots`: 100% lines (242), 100% branches (102); floor 95.
- mutation: 24 mutants, 24 caught, 0 survivors.  The list is hand-written
  (no mutmut here), one mutant per decision in the script: each attribute
  prefix, the ignore matching, the root-dotfile skip, the home-directory
  guard, each state classification, each mode bit, the force/dry-run
  branches, every exit code, the `add` attribute inference, path
  selection.  A new branch in `dots` needs a line there.
- performance: not gated.  `dots apply` on this repository (73 targets)
  is ~60 ms; no path is worth a timing baseline yet.

## Layout

| File | Covers | Suite |
|------|--------|-------|
| `tests/conftest.py` | loads `dots` by path; `home`, `src`, `run` fixtures; `run_subprocess` | |
| `tests/test_dots_unit.py` | every function in `dots` called directly, including a seeded 500-case round-trip property test for the naming | fast |
| `tests/test_dots_cli.py` | every subcommand's exact output, state change and exit code; argparse behavior as a subprocess | fast |
| `tests/test_dots_safety.py` | destructive paths (`--force`, `unlink`, `forget`), escapes from `$HOME`, names that map to `~`, modes, odd names, unreadable ignore file, backup collisions | fast |
| `tests/test_docs.py` | the documentation against the code, both directions (see below) | fast |
| `tests/test_config_integration.py` | the repository applied into a temporary `HOME`; bash, vim, tmux, git, ssh, readline, gdb, curl, wget, python, xrdb, nano read it; each module asserted by a setting only it provides; knobs and hook files | long |
| `tests/test_examples.py` | the example catalog: 43 cases, output compared to `expected.txt` after path normalization | long |
| `tests/examples/` | `simple/` 15, `moderate/` 12, `complex/` 6, `failures/` 10; each with `README.md`, `case.sh`, `expected.txt` | |
| `tests/mutants.txt`, `tests/coveragerc`, `tests/hooks/pre-commit` | the gates | |

Integration tests for programs not installed skip by name
(`needs("tmux")`), so a missing program is visible in the report rather
than passing silently.

## Standard

- A test asserts the value: the exact lines printed, the exit code, the
  link target, the mode.  "It ran" is not a test.
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
- the README's example blocks are the recorded output of named catalog
  cases; the README stays under 150 lines; every file in `docs/` is linked
  from the README; no internal link or anchor is dead

## Example catalog

Each case is a script run from a fresh `HOME` with `dots` on `PATH`; the
output, with paths normalized to `SRC`/`HOME`/`TMP` and timestamps to
`TS`, must equal `expected.txt`.  `python3 tests/test_examples.py NAME`
prints a case; `--write` re-records it after an intended change.  Complex
cases and `moderate/08`-`10` copy this repository as the source and run the
real configuration.  The catalog README is `tests/examples/README.md`.

## What is not measured

- No load, concurrency or scaling tests: `dots` is single-process and
  bounded by the number of dotfiles.
- The prompt toolkit's own behavior: it has its own bats suite upstream;
  here only "it builds a PS1 for each layout" is checked.
- Programs absent on the machine the suite runs on (screen, ctags, delta)
  are skipped, not faked.
