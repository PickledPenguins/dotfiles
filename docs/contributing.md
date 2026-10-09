# Contributing

Changing the project.  Back to the [README](../README.md);
[architecture.md](architecture.md) has the shape and the extension points.

## Where a change goes

| Kind of change | Where | Then |
|----------------|-------|------|
| a setting someone may want | the module or file for its tool, in the [options format](configuration.md#the-options-format): description above, off unless it only adds a name | `./run-tests.sh long -k options` switches it on and loads it |
| a shell behavior | one module in `dot_config/bash/rc.d/`; a new concern is a new numbered file | its row and knobs in `docs/configuration.md`; an integration assertion |
| a per-machine difference | not in the repository: a knob (for a value) or a line in a hook file | document the knob in the module header and `docs/configuration.md` |
| a `dots` behavior | the band that owns it (`docs/architecture.md`); output and exit code in the `cmd_*` | unit/CLI test, mutant line, `docs/cli.md`, catalog case |
| a new dotfile | `dot_<name>` or `private_dot_<name>` at the mirrored path, with the standard header lines | a loader in `tests/test_options.py`; integration test through the real program; row in `docs/configuration.md` |
| the prompt | `dot_config/bash/prompt/layout.sh`; a toolkit change goes in `prompt/toolkit/` | [the prompt toolkit](#the-prompt-toolkit) |
| a decision not to build something | `docs/future-work.md`, labeled, with the evidence | |

## What enforces what

| Gate | Fails when |
|------|------------|
| `tests/test_options.py` (fast) | a configuration file lacks the header that mentions `dots options`; a setting has no description above it |
| `tests/test_options.py` (long) | a setting that is off does not load in its program once switched on |
| `tests/test_docs.py` (fast) | a flag, exit code, knob, module, hook file or top-level target is missing from its document; a README example drifts from its catalog case; README over 150 lines; a `docs/` file unlinked; a dead link |
| `run-tests.sh cov` | `dots` coverage below 100% line or branch |
| `run-tests.sh mutate` | a mutant in `tests/mutants.txt` survives the fast suite |
| `test_catalog_has_enough_variety` (long) | fewer than 15/12/6/8 cases per level |
| `test_bashrc_loads_every_module_in_order` (long) | a module added, removed or renamed without updating `BASH_MODULES` |
| `.git/hooks/pre-push` | the fast suite fails on a commit being pushed, run in a clean checkout of it (`./run-tests.sh hook` installs it switched off, as `pre-push.off`; `git hooks on` switches it on; `git push --no-verify` skips it) |
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
the switch-on test skips it where the program is missing.  Then
`./run-tests.sh long -k options`, and `dots options nocasematch` shows it.

**Add a bash module** `dot_config/bash/rc.d/NN-name.sh`, in the same format:

```bash
# 72-direnv.sh -- per-directory .envrc.  Skipped when direnv is absent.
#
# Each setting has its description in the comment above it.  A setting with
# "#" directly in front of it is off: delete that "#" to turn it on, or add
# one to turn a setting off.  `dots options WORD` searches every file.

# Nothing to do without direnv.
command -v direnv >/dev/null || return 0

# No "direnv: loading" lines when entering a directory.
#export DIRENV_LOG_FORMAT=

# The hook that loads and unloads each directory's .envrc.
eval "$(direnv hook bash)"
```

Then: `BASH_MODULES` in `tests/test_config_integration.py` gets `direnv`
after `conda`; a test asserts `type -t _direnv_hook`; `docs/configuration.md`
gets the module row; `./run-tests.sh all`.

**Add a `dots` flag**: the `add_argument` in `main`, the behavior in the
`cmd_*`, a CLI test asserting output and exit code, a line in
`tests/mutants.txt` for the new branch, the flag's row in `docs/cli.md`,
and `./run-tests.sh cov mutate`.

**Record a changed catalog output**: `python3 tests/test_examples.py
--write LEVEL/NAME`, read the diff, commit it with the change that caused it.

## The prompt toolkit

`dot_config/bash/prompt/toolkit/` is
[bash-prompt-toolkit](https://github.com/PickledPenguins/bash-prompt-toolkit)
as a git subtree (squashed).  A plain clone has it; nothing to initialize.
Edit it here, in a commit that touches only that directory, so it splits
cleanly.  The toolkit's own tests run with `bats tests/` from inside it;
`./run-tests.sh long` runs them too.

```sh
# Send toolkit commits made here to the toolkit repository.
git subtree split --prefix=dot_config/bash/prompt/toolkit -b toolkit-split
git -C ../bash-prompt-toolkit pull ../dotfiles toolkit-split
git branch -D toolkit-split

# Take toolkit commits made there.
git subtree pull --squash --prefix=dot_config/bash/prompt/toolkit ../bash-prompt-toolkit BRANCH
```

`git subtree push` to `../bash-prompt-toolkit` is refused while that
repository has the branch checked out, hence split and pull.  Both
directions need a clean working tree.
## Commit convention

One change per commit; the subject says what changed and the body says
why, in normal prose.  No changelog: the log is the record.

```
Make apply exit 1 while conflicts remain

`dots apply && exec bash` continued on a half-applied home.  The summary
now counts conflicts and the exit status follows it; forget of an
unmanaged path is treated the same way.
```
