# Architecture

For changing the project. Back to the [README](../README.md).

## Shape

Two independent things share the repository: a source tree that mirrors
`$HOME` (the configuration) and one script, `dots`, that projects it into
`$HOME` as symlinks. `dots` knows nothing about bash or vim; the
configuration knows nothing about `dots` except that `~/.bashrc` resolves
its own symlink to find `DOTFILES_DIR`. The one shared convention is the
[options format](configuration.md#the-options-format), which `dots
options` reads and `tests/test_options.py` enforces: a description above
every setting, and settings that are off written with the comment
character directly in front.

```
dots                            the linker (python3, stdlib, no .py suffix)

.dotsignore                     targets dots never links (README.md, dots, tests, docs ...)
dot_bashrc  dot_bash_profile  dot_bash_logout  dot_profile      bash entry points (loaders)
dot_config/bash/rc.d/NN-*.sh    bash modules, one concern each
dot_config/bash/prompt/         toolkit/ (bash-prompt-toolkit, git subtree), layout.sh (ours)
dot_vimrc  dot_vim/rc/NN-*.vim  vim loader and modules
dot_tmux.conf  dot_config/tmux/conf.d/NN-*.conf
dot_gitconfig  dot_config/git/{core,color,aliases,diff,url,signing}.gitconfig  ignore  attributes
dot_inputrc  dot_editorconfig  dot_curlrc  dot_wgetrc  dot_screenrc  dot_dircolors
dot_gdbinit  dot_nanorc  dot_condarc  dot_Xresources  dot_ctags.d/  dot_config/{ripgrep,python,pip}/
dot_config/{kitty,matplotlib}/  dot_ipython/profile_default/  dot_sqliterc     shipped with every setting off
dot_config/systemd/user/        scheduled jobs as user timers, linked but enabled per machine
private_dot_ssh/config          ~/.ssh/config (600) and ~/.ssh/sockets/ for ControlMaster
dot_local/bin/dots              -> ../../dots: apply puts dots on PATH; unlink takes it off
dot_local/share/bash-completion/completions/dots   Tab completion for dots
dot_local/bin/executable_git-hooks   git hooks: install, switch and remove the packaged hooks in a repository
dot_local/bin/executable_git-ctags   git ctags: a tags file kept up to date by the ctags hook
dot_local/share/git-hooks/      the 18 packaged hooks and dispatch, the one file git runs per event
tests/                          conftest, unit/cli/safety/integration/examples/docs tests, examples/, hooks/, mutants.txt, shell-mutants.txt, coveragerc
tests/run-tests.sh              test runner and gates
docs/                           this set
```

`git hooks` and `git ctags` are bash, on `PATH` as git subcommands, and
independent of `dots` too: `dots apply` only links them and the catalog
into place. In a repository, `.git/hooks/EVENT` is a link to `dispatch`,
which runs each hook in `.git/hooks/EVENT.d/`; a hook is off while its
name ends in `.off`, and a hook the repository already had moves into
`EVENT.d` under the event's name. The layout and the commands are in
[configuration.md](configuration.md#packaged-git-hooks-localsharegit-hooks).

## `dots`

One file, about 400 executable lines, in five bands:

| Band | Functions | Responsibility |
|------|-----------|----------------|
| source state | `source_dir`, `parse_name`, `load_ignores`, `ignored`, `Entry`, `managed_entries` | turn the source tree into a sorted list of entries with targets and attributes |
| target state | `state`, `linked_dir`, `set_mode`, `backup` | classify one target; find a directory above it linked into the source; apply modes; move a conflict aside |
| commands | `cmd_apply`, `cmd_status`, `cmd_managed`, `cmd_unlink`, `cmd_prune`, `cmd_options`, `source_name`, `reuse_source_dirs`, `cmd_add`, `cmd_forget`, `selected`, `skip_unmanaged` | one function per subcommand, each printing its own report and returning the exit code |
| the options format | `OPTIONS_TAG`, `comment_marker`, `Option`, `parse_options` | split a configuration file into settings, their descriptions and their on/off state; used by `cmd_options` and by the tests |
| entry | `main` | argparse, source resolution, dispatch |

Dependency direction: commands call the state bands; nothing calls a
command; `main` alone owns argument parsing and the exit status (each
`cmd_*` returns it). Human output is `print` inside the command functions;
warnings, the missing-source error and the two-sources-one-target error
go to stderr.

`dots` has no `.py` suffix so it can sit on `PATH` as a command; the tests
load it with `SourceFileLoader` (`tests/conftest.py`).

## Key decisions

- **Symlinks, not copies.**  chezmoi copies and needs `chezmoi apply` after
  every edit; a link makes the live file the repository file, so `git
  status` is the change list. The cost is no templating: per-machine
  differences are hook files and knobs instead of `.tmpl` files. Rejected:
  chezmoi in symlink mode (a Go binary on every login node for one feature).
- **Per-file links, real directories.**  Linking `~/.config` whole would
  capture every tool that writes there. Files unknown to dots are left
  alone inside managed directories.
- **Loaders are trivial.**  Each entry point only sources a directory, so a
  domain resets to stock by deleting one directory and a bad module is
  found by bisecting file names. The price is one more `source` per
  module (~0 ms each; the shell starts in under 100 ms without conda).
- **Knobs before, overrides after.**  `~/.bashrc.before` exists because a
  knob must be set before the module reads it, and `~/.bashrc.local` must
  come after to win. One file could not do both.
- **Every option in the file, labeled, rather than documented elsewhere.**
  The aim is that no setting has to be looked up: whatever a tool offers
  that people commonly want is in its file, with what it does and what it
  costs, switched by one character. A separate options document would
  drift; `dots options` reads the files themselves, and the switch-on test
  keeps every offered setting loadable. What starts off is anything that
  would change an existing behavior; what only adds a name starts on.
- **Knobs are values; on/off is the comment character.**  The boolean
  knobs (`DOTFILES_AUTOCD`, `DOTFILES_SAFE_RM`, `g:dotfiles_tabs` and the
  rest) became plain settings: two ways to switch the same kind of thing
  was one too many, and per machine a setting's own line in the `.local`
  file does what the knob did. Knobs remain for values (sizes, paths,
  names) and for what must be known before a module runs (the vim leader).
- **Hooks hand `$?` on.**  Every function a module puts into
  `PROMPT_COMMAND` ahead of the prompt returns the status it found, since
  the prompt reads the last command's status after them.
- **`.off` renames rather than a manifest.**  The file stays in git and in
  the linked tree, so the diff of turning something off is a rename, not
  an edit to a list nobody reads.
- **Foreign symlinks are conflicts.**  A `~/.bashrc` from an older scheme
  is backed up (the link itself, not what it pointed to) rather than
  silently replaced; only links into our own source tree are relinked.
- **Nothing is deleted outside git.**  Conflicts move to a timestamped
  backup tree; `forget` puts a copy of the source at the target, or moves
  the source to the backup tree when a conflict is there, before the source
  leaves the tree; `unlink` touches only links in state `ok`;
  `prune` removes only symlinks that point into the source tree at a path
  that no longer exists -- nothing with content. A target reached through
  a directory link into the source is the source file, so `apply --force`
  and `forget` refuse it.
- **Modes on the source file.**  A symlink has no mode; `private_` and
  `executable_` are applied to the source and re-asserted on every
  `apply`, so a `chmod` drift is repaired.
- **stdlib Python, no dependencies.**  It has to run on a login node with
  nothing installed; `python3` is the one thing that is always there.
- **The prompt toolkit is a git subtree, not a submodule or a copy.**  A
  clone has to work without `--recursive`, so not a submodule; a fix to the
  toolkit is made once, here, and split upstream, so not a copy kept in
  step by hand. Its tests, README, LICENSE and installer stay out of
  `$HOME` through `.dotsignore`.

## Extension points

- **A bash module**: add `dot_config/bash/rc.d/NN-name.sh` with a header
  (`# NN-name.sh: what`, `Knobs:` block), read knobs as
  `${DOTFILES_X:-default}`, guard on `command -v` for optional tools, use
  `command mkdir` etc. inside functions. Add its name to `BASH_MODULES` in
  `tests/test_config_integration.py`, a test asserting one thing only it
  sets, its row in `docs/configuration.md`, and its knobs there. `dots
  apply` links it; nothing else to register.
- **A vim / tmux / git module**: same pattern in `dot_vim/rc/`,
  `dot_config/tmux/conf.d/`, `dot_config/git/` (plus an include line in
  `dot_gitconfig`).
- **A setting**: its description directly above it (first sentence: what
  it is; then what it does and costs; `Needs:` for prerequisites), off
  written as the comment character directly followed by the code, a blank
  line after. `tests/run-tests.sh long -k options` switches it on and loads it.
- **A new dotfile**: create it under its attribute name with the standard
  header lines (they mention `dots options`); give its program a loader in
  `LOADERS` in `tests/test_options.py`; add an integration test that makes
  the real program read it; add its row in `docs/configuration.md`. Formats that do not allow trailing comments
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
