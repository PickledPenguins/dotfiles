# dotfiles

A home directory in git: bash, vim, tmux, git, readline, kitty and the rest
as single-purpose modules, every setting described in place and the common
alternatives there too, switched off; and `dots`, a chezmoi-alike that
symlinks them into `$HOME` and lists the settings.

## What it does

The repository mirrors `$HOME` with chezmoi's naming (`dot_bashrc` is
`~/.bashrc`, `private_dot_ssh/config` is `~/.ssh/config` at mode 600).
`dots apply` creates real directories and one symlink per file, so editing
`~/.vimrc` edits the repository and `git status` is the change list. Each
tool's entry point is a loader that reads numbered modules -- one concern
each, switched off by an `.off` rename or a per-machine list -- and two hook
files, one before the modules for knobs and one after for overrides.
Identity and secrets never enter the repository.

Nothing needs looking up: each file carries the options people commonly
want for its tool -- about 660 on and 450 off -- each with a description
of what it does, what it costs and when not to use it. A setting written
with its comment character directly in front (`#shopt -s histverify`) is
off; delete that character to turn it on. `dots options WORD` finds a
setting in any file. Every one that is off is tested to load once
switched on.

For one person's machines, including HPC login nodes: `dots` is a
stdlib-only Python 3 script, nothing else is required to install. It does
not template files (per-machine differences are knobs and hook files) and
never deletes anything: a file in the way is moved to a timestamped backup.

## Install

Requires python3 (3.8+), git, bash 4+. vim, tmux and the others are
optional; their configuration is linked whether or not they are installed.

```sh
git clone <this repository> ~/.dotfiles
~/.dotfiles/dots status          # what would change; real files show as conflict
~/.dotfiles/dots apply           # links what it can; exit 1 while conflicts remain
~/.dotfiles/dots apply --force   # the rest; originals go to ~/.dotfiles-backup/<ts>/
printf '[user]\n\tname = You\n\temail = you@example.com\n' > ~/.gitconfig.local
exec bash
```

`apply` links `~/.local/bin/dots` to this checkout, so `dots` is a command
from then on, with Tab completion of its subcommands and options
(`~/.local/share/bash-completion/completions/dots`). `dots unlink`
uninstalls: it removes every link `apply` made, these two included.

## Quick start

Status before and after apply (`tests/examples/simple/05-status-before-and-after`):

<!-- example: simple/05-status-before-and-after -->
```sh
echo "# bashrc" > "$SRC/dot_bashrc"
echo "set nu"   > "$SRC/dot_vimrc"
dots status; echo "exit $?"
dots apply > /dev/null
dots status; echo "exit $?"
```
```text
missing     .bashrc
missing     .vimrc
missing: 2
exit 1
ok: 2
exit 0
```

A real file in the way is refused, then backed up with `--force`
(`tests/examples/moderate/01-conflict-then-force`):

<!-- example: moderate/01-conflict-then-force -->
```sh
echo "# theirs" > "$SRC/dot_bashrc"
echo "# mine"   > ~/.bashrc
dots apply; echo "exit $?"
dots apply --force; echo "exit $?"
cat ~/.dotfiles-backup/*/.bashrc
cat ~/.bashrc
```
```text
conflict  .bashrc  (use --force to back it up and replace)
0 change(s), 1 conflict(s) left
exit 1
replace   .bashrc  ->  SRC/dot_bashrc
backup    .bashrc  ->  HOME/.dotfiles-backup/TS/.bashrc
1 change(s)
exit 0
# mine
# theirs
```

Bring an existing file under management (`tests/examples/simple/10-add-a-file`):

<!-- example: simple/10-add-a-file -->
```sh
echo "set nu" > ~/.vimrc
dots add ~/.vimrc
cat "$SRC/dot_vimrc"
[ -L ~/.vimrc ] && echo "~/.vimrc is a link"
```
```text
add       .vimrc  ->  dot_vimrc
set nu
~/.vimrc is a link
```

Find a setting and switch it, turn a module off, or tune one:

```sh
dots options history                           # every setting that mentions history, on and off
dots options --off -f tmux                     # tmux's offered settings in full
echo conda >> ~/.config/bash/disabled          # this machine only
echo 'DOTFILES_HISTSIZE=5000' >> ~/.bashrc.before   # a knob, read before the modules run
DOTFILES_DEBUG=1 bash -i -c true               # each module and its load time
```

## Documentation

- [docs/concepts.md](docs/concepts.md): source tree, targets, attribute prefixes, target states, modules, loaders, knobs, hook files
- [docs/lifecycle.md](docs/lifecycle.md): what `dots apply`, `add` and `forget` do step by step; the order a shell, vim, tmux, git and ssh read their files
- [docs/cli.md](docs/cli.md): every `dots` command, flag, exit code, environment variable
- [docs/usage.md](docs/usage.md): bootstrapping a used machine, importing a home, per-machine settings, reorganizing, scripts, troubleshooting
- [docs/git-tools.md](docs/git-tools.md): the `git` subcommands in `~/.local/bin` and `gits` (rewriting history, per-commit runs, worktrees, conflicts, fixups, recovery, many repositories)
- [docs/configuration.md](docs/configuration.md): the options format, every knob, hook file, module and dotfile, with defaults
- [docs/architecture.md](docs/architecture.md): file tree, the bands of `dots`, decisions and their reasons, extension points, limits
- [docs/testing.md](docs/testing.md): suites, gates, coverage and mutation numbers, the documentation test
- [docs/contributing.md](docs/contributing.md): where a change goes, what enforces what, recipes
- [docs/future-work.md](docs/future-work.md): known gaps and what was deliberately not built
- [tests/examples/README.md](tests/examples/README.md): the example catalog, 53 runnable cases

No changelog: the git log is the record.
