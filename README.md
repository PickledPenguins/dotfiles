# dotfiles

A git-managed home directory: bash, vim, tmux, git and readline configuration,
each split into single-purpose modules that can be switched off one at a time,
and a small chezmoi-alike, `dots`, that symlinks it all into `$HOME`.

The repository lives at `~/.dotfiles` (here, a symlink to `~/work/ai/dotfiles`).
`dots` is a single stdlib-only Python 3 script; nothing else is required to
install the configuration on a new machine.

## Contents

- [Quick start](#quick-start)
- [How the source tree maps to `$HOME`](#how-the-source-tree-maps-to-home)
- [The `dots` command](#the-dots-command)
- [Turning things on and off](#turning-things-on-and-off)
- [Bash](#bash)
- [Prompt](#prompt)
- [Vim](#vim)
- [tmux](#tmux)
- [Git](#git)
- [Readline](#readline)
- [Machine-local files](#machine-local-files)
- [Testing](#testing)
- [Design notes](#design-notes)

## Quick start

```sh
git clone <this repo> ~/.dotfiles
~/.dotfiles/dots status          # what would change; real files show as "conflict"
~/.dotfiles/dots apply -n        # dry run
~/.dotfiles/dots apply --force   # link everything; real files go to ~/.dotfiles-backup/<timestamp>/
exec bash
```

Then put your identity in `~/.gitconfig.local` (see [Git](#git)).

## How the source tree maps to `$HOME`

The source directory mirrors the home directory, chezmoi-style.  Attribute
prefixes on any path component are stripped to get the target name:

| Prefix        | Effect on the target                          |
|---------------|-----------------------------------------------|
| `dot_`        | leading `.`                                   |
| `private_`    | `chmod go-rwx` (directories become `700`)     |
| `executable_` | `chmod u+x`                                   |

```
dot_bashrc                        ->  ~/.bashrc
dot_config/bash/rc.d/10-options.sh ->  ~/.config/bash/rc.d/10-options.sh
private_dot_ssh/config            ->  ~/.ssh/config          (600, ~/.ssh 700)
dot_local/bin/executable_hi       ->  ~/.local/bin/hi        (u+x)
```

Directories are created for real in `$HOME`; every *file* is a symlink back
into the source tree, so editing `~/.bashrc` edits the repository.  Modes are
set on the source file (a symlink has no mode of its own).

Not managed: entries in the source root whose name starts with `.` (`.git`,
`.gitignore`, `.dotsignore`), and every target path matching a glob in
`.dotsignore` (`README.md`, `dots`, `tests`).

## The `dots` command

```
dots apply   [-n] [--force] [PATH...]   create or repair the symlinks
dots status  [-a] [PATH...]             list targets that are not linked correctly; exit 1 if any
dots managed [-s]                       list managed targets (-s: their source files)
dots add     [-n] [--private] FILE...   move real files into the source tree, leave links behind
dots forget  [-n] FILE...               stop managing: link becomes a real copy, source file removed
dots unlink  [-n] [PATH...]             remove the symlinks; source untouched
dots -S DIR ...                         use DIR as the source (also $DOTS_SOURCE; default ~/.dotfiles)
```

`apply` classifies every target and acts on it:

| State        | Meaning                                                | `apply` does                       |
|--------------|--------------------------------------------------------|------------------------------------|
| `ok`         | symlink to the source file                             | nothing (re-asserts modes)         |
| `missing`    | nothing there                                          | link                               |
| `stale-link` | symlink to another file *inside* the source tree       | relink (a file was renamed)        |
| `conflict`   | a real file, or a symlink pointing *outside* the tree  | refuse; with `--force`, back up and replace |

Backups keep their home-relative path under `~/.dotfiles-backup/<YYYYmmdd-HHMMSS>/`.
`PATH...` restricts `apply`, `status` and `unlink` to targets under those
paths (`dots apply ~/.config/tmux`).

`add` infers `private_` from a mode with no "other" bits and `executable_`
from `u+x`; `--private` forces the former.  It takes files, not directories --
add the files inside.

## Turning things on and off

Every domain has a two-line loader in `$HOME` and a directory of numbered
modules.  Three mechanisms, from most to least permanent:

1. **Delete or comment out** -- the module or the line in the loader.
2. **Rename with `.off`** -- `git mv 70-conda.sh 70-conda.sh.off`.  The loaders
   glob on the real extension, so an `.off` file is linked but never read.
   This is committed, so it applies on every machine.
3. **Per-machine disable list** (bash only) -- `~/.config/bash/disabled`, one
   module name per line, `#` comments allowed.  The name is the file name
   without its number and `.sh`: `conda`, `prompt`, `tools`.  Not committed.

Machine-local additions go in the `*.local` files listed under
[Machine-local files](#machine-local-files); they are sourced last and win.

## Bash

```
~/.bashrc                       loader: sources ~/.config/bash/rc.d/*.sh in order
~/.bash_profile                 sources ~/.config/bash/profile.d/*.sh (if any), then ~/.bashrc
~/.bash_logout                  clears the console on a top-level logout
~/.config/bash/rc.d/
  00-env.sh          EDITOR, PAGER, LESS, XDG_*, LANG fallback, colored man pages
  10-options.sh      shopt (histappend, globstar, autocd, cdspell ...), history size and
                     sharing across shells (history -a in PROMPT_COMMAND), stty -ixon
  20-path.sh         path_prepend / path_append / path_remove; ~/.local/bin, ~/bin, ~/.dotfiles
  30-aliases.sh      ls/grep color, ll la lt, .. ..., rm -I cp -i mv -i, df/du/free -h, sb vb, alert
  40-functions.sh    mkcd, up N, extract, ff, bak, path, calc, retry
  50-completion.sh   bash-completion
  60-prompt.sh       the toolkit prompt (see below)
  61-prompt-simple.sh.off   plain one-line colored prompt with git branch; swap with 60
  70-conda.sh        finds miniconda/anaconda/miniforge and sources its conda.sh
  80-tools.sh        lesspipe, fzf, direnv, zoxide, bat -- each only if installed
  90-local.sh        sources ~/.bashrc.local
```

The loader exports `DOTFILES_DIR` (the source tree) and sets
`DOTFILES_BASH_DIR` (`~/.config/bash`) for the modules.  `DOTFILES_DEBUG=1 bash -i`
prints each module as it loads with its elapsed time -- the first place to
look when a shell starts slowly.

## Prompt

`~/.config/bash/prompt/` is a vendored snapshot of
[bash-prompt-toolkit](../bash-prompt-toolkit) 0.1.4: `prompt.sh` and `lib/`
are copied verbatim (the version is in their headers; re-copy to upgrade) and
`layout.sh` is the configuration -- which segments are registered, the row
templates, and the active layout.  Edit `layout.sh`; leave the rest alone.

The default layout is a rounded box: identity and directory on top, an
environment row (ssh, tmux, conda, jobs ...), two git rows, and the exit
status.  Every segment is silent when it does not apply, so outside a repo on
a workstation the box collapses to two lines.  Alternative layouts are in the
file, commented out.

## Vim

```
~/.vimrc                loader: sources ~/.vim/rc/*.vim, then ~/.vimrc.local
~/.vim/rc/
  00-general.vim   encoding, hidden, mouse, clipboard, nomodeline, filetype plugin indent on
  10-ui.vim        numbers, cursorline, wildmenu, listchars, splits below/right, desert
  20-search.vim    hlsearch incsearch ignorecase smartcase; rg as grepprg
  30-indent.vim    2-space soft tabs; 4 for python/rust, real tabs for make/go
  40-files.vim     swap/backup/undo under ~/.vim/tmp/, persistent undo, reopen at last position
  50-keys.vim      <space> leader, Ctrl-hjkl between splits, buffer keys, Y=y$, w!!, F2 paste
  60-plugins.vim.off   vim-plug with commentary/surround/fugitive/gitgutter/fzf; enable after installing vim-plug
```

## tmux

```
~/.tmux.conf              loader: source-file -q ~/.config/tmux/conf.d/*.conf, then ~/.tmux.conf.local
~/.config/tmux/conf.d/
  00-options.conf    256color + truecolor, 50000 lines, mouse, escape-time 0, base-index 1, vi copy mode
  10-keys.conf       prefix r reload, | and - splits keeping cwd, hjkl panes, HJKL resize,
                     v/y in copy mode (xclip when present), C-p pipe-pane logging
  20-status.conf     session left, windows middle, host and clock right
```

Requires tmux 3.0+ for the glob in `source-file`.  Prefix stays `C-b`; the
`C-a` lines are in `10-keys.conf`, commented out.

## Git

```
~/.gitconfig                    loader: [include] one file per concern, then ~/.gitconfig.local
~/.config/git/
  core.gitconfig     editor, pager, push.default current + autoSetupRemote, pull.rebase,
                     fetch.prune, rebase.autoStash, zdiff3 conflicts, histogram diff, rerere
  color.gitconfig    color.ui and per-command colors
  aliases.gitconfig  st co sw br cm ca df dfs unstage undo last lg lga hist who root aliases
  ignore             global excludes; git reads this path without being told
```

Identity is deliberately not in the repository.  Create `~/.gitconfig.local`:

```ini
[user]
    name = Your Name
    email = you@example.com
```

## Readline

`~/.inputrc`: case-insensitive completion, single-Tab listing, colored
completions, Up/Down search history by prefix.

## Machine-local files

None of these are managed or committed; each is sourced last if it exists.

| File                       | Read by                       |
|----------------------------|-------------------------------|
| `~/.bashrc.local`          | `rc.d/90-local.sh`            |
| `~/.config/bash/disabled`  | `~/.bashrc` (module skip list)|
| `~/.config/bash/profile.d/*.sh` | `~/.bash_profile` (login shells only) |
| `~/.vimrc.local`           | `~/.vimrc`                    |
| `~/.tmux.conf.local`       | `~/.tmux.conf`                |
| `~/.gitconfig.local`       | `~/.gitconfig`                |

## Testing

```sh
python3 -m pytest tests -q        # 26 tests, ~4 s
```

`tests/test_dots.py` runs `dots` as a subprocess against temporary `HOME` and
source directories (attribute mapping, every target state, `--force` backups,
`add`/`forget`/`unlink`), then applies this repository into a temporary `HOME`
and checks that bash loads every module, honors `disabled` and
`~/.bashrc.local`, and that vim, tmux and git read their split configuration.
`shellcheck -s bash -e SC1090,SC1091,SC2034 dot_bashrc dot_config/bash/rc.d/*.sh`
is clean.

## Design notes

- **Symlinks, not copies.**  chezmoi's default copies files and `chezmoi
  apply` is a step to forget; a symlink means editing the live file edits the
  repo and `git status` shows what changed.  The cost is that chezmoi's
  templating and per-machine `.tmpl` files are gone -- `*.local` files and the
  `disabled` list cover the same need.
- **Loaders are trivial.**  Each `$HOME` entry point does nothing but source a
  directory, so a domain can be reset to stock by deleting one directory, and a
  problem module is found by bisecting file names rather than a 300-line file.
- **Directories are real.**  Linking `~/.config` whole would capture every
  tool that writes there.  Per-file links leave unmanaged files alone.
- **`add` infers attributes from mode**; `forget` keeps a working copy.  Both
  refuse anything that is not a regular file under `$HOME`.
- **Foreign symlinks are conflicts.**  A `~/.bashrc` pointing at some earlier
  scheme is backed up (the link itself) rather than silently replaced.
