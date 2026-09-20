# Architecture

For changing the project.  Back to the [README](../README.md).

## Shape

Two independent things share the repository: a source tree that mirrors
`$HOME` (the configuration) and one script, `dots`, that projects it into
`$HOME` as symlinks.  `dots` knows nothing about bash or vim; the
configuration knows nothing about `dots` except that `~/.bashrc` resolves
its own symlink to find `DOTFILES_DIR`.

```
dots                            the linker (python3, stdlib, no .py suffix)
run-tests.sh                    test runner and gates
.dotsignore                     targets dots never links (README.md, dots, tests, docs ...)
dot_bashrc  dot_bash_profile  dot_bash_logout  dot_profile      bash entry points (loaders)
dot_config/bash/rc.d/NN-*.sh    bash modules, one concern each
dot_config/bash/prompt/         prompt.sh + lib/ (vendored bash-prompt-toolkit), layout.sh (ours)
dot_vimrc  dot_vim/rc/NN-*.vim  vim loader and modules
dot_tmux.conf  dot_config/tmux/conf.d/NN-*.conf
dot_gitconfig  dot_config/git/{core,color,aliases,diff,url,signing}.gitconfig  ignore  attributes
dot_inputrc  dot_editorconfig  dot_curlrc  dot_wgetrc  dot_screenrc  dot_dircolors
dot_gdbinit  dot_nanorc  dot_condarc  dot_Xresources  dot_ctags.d/  dot_config/{ripgrep,python,pip}/
private_dot_ssh/config          ~/.ssh/config (600) and ~/.ssh/sockets/ for ControlMaster
tests/                          conftest, unit/cli/safety/integration/examples/docs tests, examples/, hooks/, mutants.txt, coveragerc
docs/                           this set
reviews/                        friction logs and review reports (caddressreview works through them)
CLAUDE.md                       instructions for the coding agent
```

## `dots`

One file, ~370 lines, in four bands:

| Band | Functions | Responsibility |
|------|-----------|----------------|
| source state | `source_dir`, `parse_name`, `load_ignores`, `ignored`, `Entry`, `managed_entries` | turn the source tree into a sorted list of entries with targets and attributes |
| target state | `state`, `set_mode`, `backup` | classify one target; apply modes; move a conflict aside |
| commands | `cmd_apply`, `cmd_status`, `cmd_managed`, `cmd_unlink`, `cmd_prune`, `source_name`, `cmd_add`, `cmd_forget`, `selected` | one function per subcommand, each printing its own report and returning the exit code |
| entry | `main` | argparse, source resolution, dispatch |

Dependency direction: commands call the state bands; nothing calls a
command; `main` alone owns argument parsing and the exit status (each
`cmd_*` returns it).  Human output is `print` inside the command functions;
warnings and the missing-source error go to stderr.

`dots` has no `.py` suffix so it can sit on `PATH` as a command; the tests
load it with `SourceFileLoader` (`tests/conftest.py`).

## Key decisions

- **Symlinks, not copies.**  chezmoi copies and needs `chezmoi apply` after
  every edit; a link makes the live file the repository file, so `git
  status` is the change list.  The cost is no templating: per-machine
  differences are hook files and knobs instead of `.tmpl` files.  Rejected:
  chezmoi in symlink mode (a Go binary on every login node for one feature).
- **Per-file links, real directories.**  Linking `~/.config` whole would
  capture every tool that writes there.  Files unknown to dots are left
  alone inside managed directories.
- **Loaders are trivial.**  Each entry point only sources a directory, so a
  domain resets to stock by deleting one directory and a bad module is
  found by bisecting file names.  The price is one more `source` per
  module (~0 ms each; the shell starts in under 100 ms without conda).
- **Knobs before, overrides after.**  `~/.bashrc.before` exists because a
  knob must be set before the module reads it, and `~/.bashrc.local` must
  come after to win.  One file could not do both.
- **`.off` renames rather than a manifest.**  The file stays in git and in
  the linked tree, so the diff of turning something off is a rename, not
  an edit to a list nobody reads.
- **Foreign symlinks are conflicts.**  A `~/.bashrc` from an older scheme
  is backed up (the link itself, not what it pointed to) rather than
  silently replaced; only links into our own source tree are relinked.
- **Nothing is ever deleted.**  Conflicts move to a timestamped backup
  tree; `forget` copies before it removes; `unlink` touches only links in
  state `ok`; `prune` removes only symlinks that point into the source tree
  at a path that no longer exists -- nothing with content.
- **Modes on the source file.**  A symlink has no mode; `private_` and
  `executable_` are applied to the source and re-asserted on every
  `apply`, so a `chmod` drift is repaired.
- **stdlib Python, no dependencies.**  It has to run on a login node with
  nothing installed; `python3` is the one thing that is always there.
- **The prompt toolkit is vendored, not a submodule.**  A clone has to work
  without `--recursive`, and the toolkit's tests and README do not belong
  in `$HOME`.  Its version is in the headers; upgrading is a copy.

## Extension points

- **A bash module**: add `dot_config/bash/rc.d/NN-name.sh` with a header
  (`# NN-name.sh -- what`, `Knobs:` block), read knobs as
  `${DOTFILES_X:-default}`, guard on `command -v` for optional tools, use
  `command mkdir` etc. inside functions.  Add its name to `BASH_MODULES` in
  `tests/test_config_integration.py`, a test asserting one thing only it
  sets, its row in `docs/configuration.md`, and its knobs there.  `dots
  apply` links it; nothing else to register.
- **A vim / tmux / git module**: same pattern in `dot_vim/rc/`,
  `dot_config/tmux/conf.d/`, `dot_config/git/` (plus an include line in
  `dot_gitconfig`).
- **A new dotfile**: create it under its attribute name; add an
  integration test that makes the real program read it; add its row in
  `docs/configuration.md`.  Formats that do not allow trailing comments
  (curl, wget, nano, screen, Xresources, ctags, editorconfig, inputrc,
  gdb) take comments on their own lines.
- **A `dots` subcommand**: a `cmd_*(args, src, home)` function returning
  the exit code, a `sub.add_parser` block in `main`, tests in
  `tests/test_dots_cli.py`, a section in `docs/cli.md` (the docs test
  fails until it is there), and catalog cases.

## Limitations

- No templating; a file that must differ per machine is a hook file.
- `prune` removes only broken links into the source tree; a link into the
  tree that still resolves is assumed deliberate.
- `add` takes files only (F.1.b).
- Linux/GNU assumed by the bash aliases (`ls --color`, `rm -I`, `ss`);
  the BSD branch only sets `CLICOLOR`.
- The prompt toolkit needs bash 4+ and a UTF-8 terminal for the box
  characters; `61-prompt-simple` is the fallback.
