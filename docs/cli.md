# `dots` command reference

Every command, flag and exit code.  Back to the [README](../README.md);
vocabulary in [concepts.md](concepts.md).

```
dots [-S SOURCE] COMMAND [options] [paths...]
```

## Global options

| Flag | Argument | Default | Effect |
|------|----------|---------|--------|
| `-S`, `--source` | directory | `$DOTS_SOURCE`, else `~/.dotfiles`, else the directory holding `dots` | the source tree |
| `-h`, `--help` | | | usage and the naming rules, exit 0 |

The default is dynamic: `~/.dotfiles` is used only if it exists (symlinks
resolved); the script's own directory is the last resort, which is what
makes `./dots` work from a fresh clone anywhere.

## Commands

Paths given to `apply`, `status` and `unlink` restrict them to targets equal
to or below those paths; `add` and `forget` require paths; `managed` and
`prune` take none; `options` takes search words instead.  Paths are made
absolute lexically (`~` expanded, `..` collapsed, symlinks not followed).

### `dots apply [-n] [--force] [paths...]`

Create or repair the symlinks.  One line per action -- `link`, `relink`,
`replace` + `backup`, or `conflict` -- then `N change(s)` with
`, M conflict(s) left` when any were refused.  A target reached through a
directory that is itself a symlink into the source tree (`~/.vim ->
SRC/dot_vim`) is the source file; it stays a conflict even under
`--force`, with `(.vim links into the source; make it a real directory)`.

| Flag | Effect |
|------|--------|
| `-n`, `--dry-run` | print the plan, change nothing; the summary ends in `(dry run)` |
| `--force` | back up and replace real files and foreign symlinks (see [lifecycle](lifecycle.md#dots-apply)) |

Exit 0, or 1 when conflicts remain.  `--force -n` shows `replace` lines
without the `backup` lines, since no backup is made.

### `dots status [-a] [paths...]`

One line per target that is not `ok` (`STATE  path`), then a summary of
counts per state, e.g. `conflict: 1  missing: 3`; `ok: N` alone when all
is well; `nothing managed` for an empty source.

| Flag | Effect |
|------|--------|
| `-a`, `--all` | list `ok` targets too |

Exit 0 when every target is `ok`, else 1.

### `dots managed [-s]`

The managed targets, one per line, sorted.

| Flag | Effect |
|------|--------|
| `-s`, `--show-source` | print the absolute source path of each instead |

Exit 0.

### `dots add [-n] [--private] paths...`

Move regular files from `$HOME` into the source tree under their attribute
names and leave symlinks behind.  `add  target  ->  source-relative name`
per file; `skip  path: reason` for anything refused: not under `$HOME`,
already a symlink, not a regular file (directories are not added -- name
the files inside), the source name already exists, or `a name starts with
dot_, private_ or executable_` (such a name cannot be stored under itself:
`~/private_notes` would become the source of `~/notes`).  A file below a
directory the source already has under another attribute name goes into
that directory: `~/.ssh/known_hosts` into `private_dot_ssh/`.

| Flag | Effect |
|------|--------|
| `-n`, `--dry-run` | print the moves, change nothing |
| `--private` | use `private_` regardless of the file's mode |

Attributes are inferred from the mode: `private_` when no permission bits
are set for others (`-rw-r-----` or tighter), `executable_` when the owner
has execute.  Exit 0 (skips are not errors).

### `dots forget [-n] paths...`

Stop managing targets.  A target that is our link becomes a real copy of
the source file; the source file is removed.  `forget  target` per path;
`skip  path: not managed` for the rest.  A target reached through a
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
invisible to `apply` and `unlink`.  Looks at the symlinks directly in
`$HOME` and everything under the top-level directories that hold managed
targets (`~/.config`, `~/.vim`, ...); a link is removed only when it
points inside the source tree **and** its file is gone.  A link into the
tree that still resolves, or a broken link to anywhere else, is left
alone.  `prune  target  ->  link` per removal, then
`N dangling link(s) removed`.

| Flag | Effect |
|------|--------|
| `-n`, `--dry-run` | print the removals, change nothing |

Exit 0.

### `dots options [--on | --off] [-f] [words...]`

List the settings in the configuration files, on and off, so an option can
be found without knowing which file holds it.  Reads every managed file that
contains the text `dots options` (each file in this repository says it in
its header) in the [options format](configuration.md#the-options-format):
a comment directly above a setting describes it, and a setting whose
comment character is followed directly by code (`#shopt -s histverify`,
`"set relativenumber`) is off.  The comment character is `"` for `.vimrc`
and `*.vim`, `!` for `.Xresources`, `#` for everything else.

Output: the target (`~/.config/bash/rc.d/10-options.sh`), then one line per
option: its line number, `on` or `off`, and the first line of its
description.  Code with no description above it (a `[section]` header, the
rest of an `if`) is not an option and is not listed.

| Flag | Effect |
|------|--------|
| `words` | only options whose target path, description or code contains every word, case-insensitively |
| `--on` | only settings that are on |
| `--off` | only settings that are off |
| `-f`, `--full` | also print the rest of each description and the setting's code, indented |

Exit 0 when anything was listed, 1 when nothing matched.  To switch an
option, open the file at the line shown (`vim +57 ~/.config/...`) and
delete or add the comment character in front of the setting.

### `dots unlink [-n] [paths...]`

Remove every symlink whose state is `ok`; real files, foreign links and
the source tree are untouched.  `unlink  target` per link, then
`N link(s) removed`.

| Flag | Effect |
|------|--------|
| `-n`, `--dry-run` | print the removals, change nothing |

Exit 0.

## Exit status

| Code | When |
|------|------|
| 0 | success |
| 1 | `apply` left conflicts; `status` found anything not `ok`; `forget` named an unmanaged path or refused one; `options` matched nothing; an unhandled error (a traceback, e.g. an unreadable `.dotsignore`) |
| 2 | usage error (argparse), or the source directory does not exist |

## Environment

| Variable | Effect |
|----------|--------|
| `DOTS_SOURCE` | the source tree, when `-S` is not given |
| `HOME` | the home directory every target is relative to |

## Input and output

Reports go to stdout; the `dots: source directory ... does not exist`
error, the `dots: ignoring NAME: maps to '...'` warning and argparse errors
go to stderr.  Nothing is read from stdin.  Output is the same whether or
not stdout is a terminal; there is no color.

## Files

| Path | Role |
|------|------|
| `SOURCE/.dotsignore` | target paths never managed; glob per line, `#` comments |
| `~/.dotfiles-backup/<YYYYmmdd-HHMMSS>/` | where `apply --force` moves what it replaces |
