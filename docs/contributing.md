# Contributing

Changing the project. Back to the [README](../README.md);
[architecture.md](architecture.md) has the shape and the extension points.

## Where a change goes

| Kind of change | Where | Then |
|----------------|-------|------|
| a setting someone may want | the module or file for its tool, in the [options format](configuration.md#the-options-format): description above, off unless it only adds a name | `tests/run-tests.sh long -k options` switches it on and loads it |
| a shell behavior | one module in `dot_config/bash/rc.d/`; a new concern is a new numbered file | its row and knobs in `docs/configuration.md`; an integration assertion |
| a new command | by [the rule below](#alias-function-or-program): an alias or function in a module, or a program in linuxbin's `bin/` | a program gets its README and tests in linuxbin, not here |
| a per-machine difference | not in the repository: a knob (for a value) or a line in a hook file | document the knob in the module header and `docs/configuration.md` |
| a `dots` behavior | the band that owns it (`docs/architecture.md`); output and exit code in the `cmd_*` | unit/CLI test, mutant line, `docs/cli.md`, catalog case |
| a new dotfile | `dot_<name>` or `private_dot_<name>` at the mirrored path, with the standard header lines | a loader in `tests/test_options.py`; integration test through the real program; row in `docs/configuration.md` |
| the prompt | `dot_config/bash/prompt/layout.sh`; a toolkit change goes in `prompt/toolkit/` | [the prompt toolkit](#the-prompt-toolkit) |
| a decision not to build something | `docs/future-work.md`, labeled, with the evidence | |

### Alias, function or program

A program in a directory on PATH is the default: it works from scripts,
`xargs`, `find -exec`, vim's `:!` and other shells, costs no startup time,
and a whole directory of them goes on or off PATH like a package. The
first rule that fits wins.

1. A **function** when it must act on the running shell: `cd`, variables,
   history, jobs, traps, `exec`, `source`, running the shell's own
   functions or aliases, lazy loaders, prompt hooks (`mkcd`, `up`, `cdg`,
   `hr` reading `COLUMNS`, `man` falling back to `help`).
2. An **alias** for a changed default (`rm -I`, `ls --color`), a typo fix
   (`cd..`), or the `sudo ` trick.
3. An **alias** for a plain abbreviation: one command, the arguments at
   the end (`gs`, `ll`, `qs`).
4. Otherwise a **program** in linuxbin's `bin/` (`bin/hpc/` for one that
   needs a scheduler), with its own `docs/README_<name>.md`. dotfiles keeps
   a program only when its own files run it.
5. A set that shares state stays together in one form (`mark jump unmark
   marks`).

A package directory goes on PATH through `DOTFILES_PATH_APPEND`, after
the system's, so a program of the same name wins; `path_clash DIR` lists
the names it shares with something else.

## What enforces what

| Gate | Fails when |
|------|------------|
| `tests/test_options.py` (fast) | a configuration file lacks the header that mentions `dots options`; a setting has no description above it |
| `tests/test_options.py` (long) | a setting that is off does not load in its program once switched on |
| `tests/test_docs.py` (fast) | a flag, exit code, knob, module, hook file, packaged git hook or top-level target is missing from its document; a packaged git hook's header is malformed or names a setting it does not read; a README example drifts from its catalog case; README over 150 lines; a `docs/` file unlinked; a dead link |
| `tests/run-tests.sh cov` | `dots` coverage below 100% line or branch |
| `tests/run-tests.sh mutate` | a mutant in `tests/mutants.txt` survives the fast suite |
| `tests/run-tests.sh mutate-shell` | a mutant in `tests/shell-mutants.txt` survives its long tests or bats file, or its line has changed (stale: update the line) |
| `test_catalog_has_enough_variety` (long) | fewer than 15/12/6/8 cases per level |
| `test_bashrc_loads_every_module_in_order` (long) | a module added, removed or renamed without updating `BASH_MODULES` |
| `.git/hooks/pre-push.d/test-push` | the fast suite fails on a commit being pushed, run in a clean checkout of it: the packaged `test-push` hook with `hooks.test` set to `tests/run-tests.sh fast` (`tests/run-tests.sh hook` installs it switched off; `git hooks on test-push` switches it on; `git push --no-verify` or `HOOKS_SKIP=test-push` skips it) |
| `.git/hooks/pre-push.d/perf-push` | shell startup or the prompt of a commit being pushed is more than 25% slower than this machine's baseline: the packaged `perf-push` hook with `hooks.perf` set to `tests/run-tests.sh perf` (`tests/run-tests.sh hook` installs it switched off; `git hooks on perf-push` switches it on; `HOOKS_SKIP=perf-push` skips it) |
| `.dotsignore` | a new root file that is not a target must be listed, or `dots apply` links it into `$HOME` |

## Recipes

**Offer a setting** in an existing file: the description directly above
it -- the first sentence says what it is, the rest what it does, what it
costs and who would not want it -- and, if it changes an existing behavior,
the comment character directly in front of its code:

```bash
# Case-insensitive [[ == ]], [[ =~ ]] and case patterns.
#shopt -s nocasematch
```

A setting that needs a program adds `# Needs: PROGRAM` to its description;
the switch-on test skips it where the program is missing. Then
`tests/run-tests.sh long -k options`, and `dots options nocasematch` shows it.

**Add a bash module** `dot_config/bash/rc.d/NN-name.sh`, in the same format:

```bash
# 72-direnv.sh: per-directory .envrc. Skipped when direnv is absent.
#
# Each setting has its description in the comment above it. A setting with
# "#" directly in front of it is off: delete that "#" to turn it on, or add
# one to turn a setting off. `dots options WORD` searches every file.

# Nothing to do without direnv.
command -v direnv >/dev/null || return 0

# No "direnv: loading" lines when entering a directory.
#export DIRENV_LOG_FORMAT=

# The hook that loads and unloads each directory's .envrc.
eval "$(direnv hook bash)"
```

Then: `BASH_MODULES` in `tests/test_config_integration.py` gets `direnv`
after `conda`; a test asserts `type -t _direnv_hook`; `docs/configuration.md`
gets the module row; `tests/run-tests.sh all`.

**Add a `dots` flag**: the `add_argument` in `main`, the behavior in the
`cmd_*`, a CLI test asserting output and exit code, a line in
`tests/mutants.txt` for the new branch, the flag's row in `docs/cli.md`,
and `tests/run-tests.sh cov mutate`.

**Record a changed catalog output**: `python3 tests/test_examples.py
--write LEVEL/NAME`, read the diff, commit it with the change that caused it.

## The prompt toolkit

`dot_config/bash/prompt/toolkit/` is
[bash-prompt-toolkit](https://github.com/PickledPenguins/bash-prompt-toolkit)
as a git subtree (squashed). A plain clone has it; nothing to initialize.
Edit it here, in a commit that touches only that directory, so it splits
cleanly. The toolkit's own tests run with `bats tests/` from inside it;
`tests/run-tests.sh long` runs them too.

```sh
# Send toolkit commits made here to the toolkit repository.
git subtree split --prefix=dot_config/bash/prompt/toolkit -b toolkit-split
git -C ../bash-prompt-toolkit pull ../dotfiles toolkit-split
git branch -D toolkit-split

# Take toolkit commits made there.
git subtree pull --squash --prefix=dot_config/bash/prompt/toolkit ../bash-prompt-toolkit BRANCH
```

`git subtree push` to `../bash-prompt-toolkit` is refused while that
repository has the branch checked out, hence split and pull. Both
directions need a clean working tree.
## Commit convention

One change per commit; the subject says what changed and the body says
why, in normal prose. No changelog: the log is the record.

```
Make apply exit 1 while conflicts remain

`dots apply && exec bash` continued on a half-applied home. The summary
now counts conflicts and the exit status follows it; forget of an
unmanaged path is treated the same way.
```
