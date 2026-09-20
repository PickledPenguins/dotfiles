# Contributing

Changing the project.  Back to the [README](../README.md);
[architecture.md](architecture.md) has the shape and the extension points.

## Where a change goes

| Kind of change | Where | Then |
|----------------|-------|------|
| a shell behavior | one module in `dot_config/bash/rc.d/`; a new concern is a new numbered file | its row and knobs in `docs/configuration.md`; an integration assertion |
| a per-machine difference | not in the repository: a knob or a hook file | document the knob in the module header and `docs/configuration.md` |
| a `dots` behavior | the band that owns it (`docs/architecture.md`); output and exit code in the `cmd_*` | unit/CLI test, mutant line, `docs/cli.md`, catalog case |
| a new dotfile | `dot_<name>` or `private_dot_<name>` at the mirrored path | integration test through the real program; row in `docs/configuration.md` |
| the prompt | `dot_config/bash/prompt/layout.sh` only; `prompt.sh` and `lib/` are upstream's | |
| a decision not to build something | `docs/future-work.md`, labelled, with the evidence | |

## What enforces what

| Gate | Fails when |
|------|------------|
| `tests/test_docs.py` (fast) | a flag, exit code, knob, module, hook file or top-level target is missing from its document; a README example drifts from its catalog case; README over 150 lines; a `docs/` file unlinked; a dead link |
| `run-tests.sh cov` | `dots` coverage below 95% line or branch |
| `run-tests.sh mutate` | a mutant in `tests/mutants.txt` survives the fast suite |
| `test_catalog_has_enough_variety` (long) | fewer than 15/12/6/8 cases per level |
| `test_bashrc_loads_every_module_in_order` (long) | a module added, removed or renamed without updating `BASH_MODULES` |
| `.git/hooks/pre-commit` | the fast suite fails (`./run-tests.sh hook` installs it) |
| `.dotsignore` | a new root file that is not a target must be listed, or `dots apply` links it into `$HOME` |

## Recipes

**Add a bash module** `dot_config/bash/rc.d/NN-name.sh`:

```sh
cat > dot_config/bash/rc.d/72-direnv.sh <<'EOF'
# 72-direnv.sh -- per-directory .envrc.  Skipped when direnv is absent.
#
# Knobs (set in ~/.bashrc.before):
#   DOTFILES_DIRENV_QUIET   1 = no "direnv: loading" lines   default: 0
command -v direnv >/dev/null || return 0
[[ "${DOTFILES_DIRENV_QUIET:-0}" == 1 ]] && export DIRENV_LOG_FORMAT=
eval "$(direnv hook bash)"
EOF
```

Then: `BASH_MODULES` in `tests/test_config_integration.py` gets `direnv`
after `conda`; a test asserts `type -t _direnv_hook`; `docs/configuration.md`
gets the module row and the knob row; `./run-tests.sh all`.

**Add a `dots` flag**: the `add_argument` in `main`, the behavior in the
`cmd_*`, a CLI test asserting output and exit code, a line in
`tests/mutants.txt` for the new branch, the flag's row in `docs/cli.md`,
and `./run-tests.sh cov mutate`.

**Record a changed catalog output**: `python3 tests/test_examples.py
--write LEVEL/NAME`, read the diff, commit it with the change that caused it.

## Commit convention

One change per commit; the subject says what changed and the body says
why, in normal prose.  No changelog: the log is the record.

```
Make apply exit 1 while conflicts remain

`dots apply && exec bash` continued on a half-applied home.  The summary
now counts conflicts and the exit status follows it; forget of an
unmanaged path is treated the same way.
```
