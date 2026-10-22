# `dots` command reference

Every command, flag and exit code. Back to the [README](../README.md);
vocabulary in [concepts.md](concepts.md).

```
dots [-S SOURCE] COMMAND [options] [paths...]
```

## Global options

| Flag | Argument | Default | Effect |
|------|----------|---------|--------|
| `-S`, `--source` | directory | `$DOTS_SOURCE`, else the directory holding `dots` when it has a `.dotsignore`, else `~/.dotfiles`, else the directory holding `dots` | the source tree |
| `-h`, `--help` | | | usage and the naming rules, exit 0 |

The default is dynamic. A `dots` inside a source tree (a `.dotsignore`
beside it, symlinks resolved, so the installed `~/.local/bin/dots` too)
manages that tree: `./dots apply` from a second clone or a worktree acts
on that checkout and links `$HOME` into it, whatever `~/.dotfiles` is, and
deleting the checkout later leaves those links dangling until `dots apply`
from another tree or `dots prune`. A `dots` copied on its own uses
`~/.dotfiles` if it exists (symlinks resolved), else its own directory.

## Commands

Paths given to `apply`, `status` and `unlink` restrict them to targets equal
to or below those paths; `add` and `forget` require paths; `managed` and
`prune` take none; `options` takes search words and `fast` a mode instead. Paths are made
absolute lexically (`~` expanded, `..` collapsed, symlinks not followed).
A path that selects no target (a typo, an unmanaged or ignored file) gets
`skip      PATH: not managed` before the summary line, and the command
exits 1; the paths that do match are still acted on.

### `dots apply [-n] [--force] [paths...]`

Create or repair the symlinks. One line per action -- `link`, `relink`,
`replace` + `backup`, or `conflict` -- then `N change(s)` with
`, M conflict(s) left` when any were refused. A target reached through a
directory that is itself a symlink into the source tree (`~/.vim ->
SRC/dot_vim`) is the source file; it stays a conflict even under
`--force`, with `(.vim links into the source; make it a real directory)`.

| Flag | Effect |
|------|--------|
| `-n`, `--dry-run` | print the plan, change nothing; the summary ends in `(dry run)` |
| `--force` | back up and replace real files and foreign symlinks (see [lifecycle](lifecycle.md#dots-apply)) |

Exit 0, or 1 when conflicts remain or a path selected nothing. `--force -n`
shows `replace` lines without the `backup` lines, since no backup is made.

### `dots status [-a] [paths...]`

One line per target that is not `ok` (`STATE  path`), then a summary of
counts per state, e.g. `conflict: 1  missing: 3`; `ok: N` alone when all
is well; `nothing managed` for an empty source.

| Flag | Effect |
|------|--------|
| `-a`, `--all` | list `ok` targets too |

Exit 0 when every target is `ok` and every path selected one, else 1.

### `dots managed [-s]`

The managed targets, one per line, sorted.

| Flag | Effect |
|------|--------|
| `-s`, `--show-source` | print the absolute source path of each instead |

Exit 0.

### `dots add [-n] [--private] paths...`

Move regular files from `$HOME` into the source tree under their attribute
names and leave symlinks behind. `add  target  ->  source-relative name`
per file; `skip  path: reason` for anything refused: not under `$HOME`,
already a symlink, not a regular file (directories are not added -- name
the files inside), the source name already exists, or `a name starts with
dot_, private_ or executable_` (such a name cannot be stored under itself:
`~/private_notes` would become the source of `~/notes`), or `ignored by
.dotsignore` (a path such as `~/docs/plan.txt` would land among the
repository's own files and never be linked). A file below a
directory the source already has under another attribute name goes into
that directory: `~/.ssh/known_hosts` into `private_dot_ssh/`.

| Flag | Effect |
|------|--------|
| `-n`, `--dry-run` | print the moves, change nothing |
| `--private` | use `private_` regardless of the file's mode |

Attributes are inferred from the mode: `private_` when no permission bits
are set for others (`-rw-r-----` or tighter), `executable_` when the owner
has execute. Exit 0 (skips are not errors).

### `dots forget [-n] paths...`

Stop managing targets, keeping each file. A target that is our link, a
stale link or missing becomes a real copy of the source file, and the
source file is removed. A target that is a conflict is left alone and the
source file moves to the backup tree (`backup  target  ->  path`).
`forget  target` per path; `skip  path: not managed` for the rest. A
target reached through a
directory link into the source tree is refused (`skip  path: .vim links
into the source; make it a real directory`): there the target is the
source file, and removing one would remove both.

| Flag | Effect |
|------|--------|
| `-n`, `--dry-run` | print what would be forgotten |

Exit 0, or 1 when any path was not managed.

### `dots prune [-n]`

Remove dangling symlinks into the source tree: links left behind when a
source path was moved or deleted, which are no longer targets and so
invisible to `apply` and `unlink`. Looks at the symlinks directly in
`$HOME` and everything under the top-level directories that hold managed
targets (`~/.config`, `~/.vim`, ...); a link is removed only when it
points inside the source tree **and** its file is gone. A link into the
tree that still resolves, or a broken link to anywhere else, is left
alone. `prune  target  ->  link` per removal, then
`N dangling link(s) removed`.

| Flag | Effect |
|------|--------|
| `-n`, `--dry-run` | print the removals, change nothing |

Exit 0.

### `dots options [--on | --off] [-f] [words...]`

List the settings in the configuration files, on and off, so an option can
be found without knowing which file holds it. Reads every managed file that
contains the text `dots options` (each file in this repository says it in
its header) in the [options format](configuration.md#the-options-format):
a comment directly above a setting describes it, and a setting whose
comment character is followed directly by code (`#shopt -s histverify`,
`"set relativenumber`) is off. The comment character is `"` for `.vimrc`
and `*.vim`, `!` for `.Xresources`, `#` for everything else.

Output: the target (`~/.config/bash/rc.d/10-options.sh`), then one line per
option: its line number, `on` or `off`, and the first line of its
description. Code with no description above it (a `[section]` header, the
rest of an `if`) is not an option and is not listed.

| Flag | Effect |
|------|--------|
| `words` | only options whose target path, description or code contains every word, case-insensitively |
| `--on` | only settings that are on |
| `--off` | only settings that are off |
| `-f`, `--full` | also print the rest of each description and the setting's code, indented |

Exit 0 when anything was listed, 1 when nothing matched. To switch an
option, open the file at the line shown (`vim +57 ~/.config/...`) and
delete or add the comment character in front of the setting.

### `dots fast [on | off | auto | reset]`

Set fast mode for this machine, or print it. `on`, `off` and `auto` write
the word to `~/.config/bash/fast` and print
`fast mode: MODE in PATH`; `reset` removes the file
(`fast mode: PATH removed`) and the mode falls back to off. When
`DOTS_FAST` is set, a line says it overrides the file. New shells read the
file; in the shell that ran it, the `dots` function from `05-fast.sh`
applies it at once. Other open shells keep their mode.

With no argument, print the mode, where it comes from (`DOTS_FAST`, the
file, or the default), auto's verdict and reason, each host signal against
its threshold (a line over it ends in `!`), and the samples kept on this
host. The host is sampled over 1 s. The thresholds come from the
environment and `~/.bashrc.before`. [fast-mode.md](fast-mode.md) has what
each line means.

```text
fast mode  auto, on now (/home/me/.config/bash/fast)
reason     iowait 23% >= 20
blocked    0          at 2 or more (DOTS_FAST_BLOCKED)
iowait     23 %       at 20% or more (DOTS_FAST_IOWAIT)  !
...
samples    1 of the last 5 slow (on at 2), 1 of the last 10 (off at 0 of 10)
```

| Flag | Effect |
|------|--------|
| `on` | fast mode on in every new shell, whatever the signals |
| `off` | fast mode off, even where auto would turn it on |
| `auto` | decide at each shell start from the signals |
| `reset` | remove the setting: off |

Exit 0, or with the status of the bash that prints the report.

### `dots unlink [-n] [paths...]`

Remove every symlink whose state is `ok`; real files, foreign links and
the source tree are untouched. `unlink  target` per link, then
`N link(s) removed`. This is the uninstall: `~/.local/bin/dots` and its
completion are links like the rest, so a plain `dots unlink` takes the
command off `PATH` too (run `~/.dotfiles/dots` from then on).

| Flag | Effect |
|------|--------|
| `-n`, `--dry-run` | print the removals, change nothing |

Exit 0, or 1 when a path selected nothing.

## Exit status

| Code | When |
|------|------|
| 0 | success |
| 1 | `apply`, `status` or `unlink` named a path that selects nothing; `apply` left conflicts; `status` found anything not `ok`; `forget` named an unmanaged path or refused one; `options` matched nothing; an unhandled error (a traceback, such as for an unreadable `.dotsignore`, or `apply` meeting a source file that is a broken symlink, before it links anything) |
| 2 | usage error (argparse); the source directory does not exist; two source files map to one target |

## Environment

| Variable | Effect |
|----------|--------|
| `DOTS_SOURCE` | the source tree, when `-S` is not given |
| `DOTS_FAST` | `on`, `off` or `auto`: overrides the file `dots fast` writes, which `dots fast` then says |
| `XDG_CONFIG_HOME` | where `dots fast` keeps its setting: `$XDG_CONFIG_HOME/bash/fast`, `~/.config/bash/fast` when unset |
| `HOME` | the home directory every target is relative to |

## Input and output

Reports go to stdout; the `dots: source directory ... does not exist` and
`dots: A and B both map to TARGET; remove one` errors, the
`dots: ignoring NAME: maps to '...'` warning and argparse errors go to
stderr. Nothing is read from stdin. Output is the same whether or
not stdout is a terminal; there is no color.

## Files

| Path | Role |
|------|------|
| `SOURCE/.dotsignore` | target paths never managed; glob per line, `#` comments |
| `~/.config/bash/fast` | the fast mode `dots fast` set: `on`, `off` or `auto` |
| `~/.dotfiles-backup/<YYYYmmdd-HHMMSS>/` | where `apply --force` moves what it replaces |
| `~/.local/bin/dots` | the command on `PATH`, a link `apply` makes to `SOURCE/dot_local/bin/dots`, itself a link to `SOURCE/dots` |
| `~/.local/share/bash-completion/completions/dots` | Tab completion: subcommands, each one's options, directories after `-S`, file names for paths |
