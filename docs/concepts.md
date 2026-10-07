# Concepts

The vocabulary used by `dots`, the modules and the rest of the documentation.
Names match the code.  Back to the [README](../README.md).

## The source tree and targets

- **source tree** (`src` in the code) -- this repository, checked out at
  `~/.dotfiles` (a symlink to `~/work/ai/dotfiles` on the author's machine).
  It mirrors `$HOME`: a path inside it names a path in the home directory.
- **target** -- the path in `$HOME` a source file maps to.  `dot_bashrc` has
  the target `~/.bashrc`; `dot_config/git/core.gitconfig` has
  `~/.config/git/core.gitconfig`.
- **attribute prefix** -- a prefix on any path component, stripped to get
  the target name and remembered as a property of the entry:
  `dot_` (leading dot), `private_` (mode 600 for a file, 700 for a
  directory and everything below it), `executable_` (owner execute bit).
  Prefixes stack in any order: `private_executable_dot_x`.  A home file
  whose own name starts with a prefix word (`~/private_notes`,
  `~/bin/dot_env`) cannot be managed: its name would be read as an
  attribute, and `add` refuses it.
- **entry** (`Entry`) -- one source file with its target, its attributes and
  the directories that must be 700 because of a `private_` component.
- **managed** -- an entry that `dots` will act on.  Everything under the
  source tree is managed except directories whose name starts with `.`, at
  any depth (`.git`), files whose name starts with `.` in the root
  (`.gitignore`, `.dotsignore`; deeper ones are managed), and target paths
  matching a pattern in `.dotsignore`.
- **`.dotsignore`** -- one glob pattern per line, matched against the
  target-relative path and each of its leading directories, anchored at the
  top; `*` crosses `/`.  `#` starts a comment.

## Target states

What `dots status` and `dots apply` find at a target:

| State        | Meaning                                                              |
|--------------|----------------------------------------------------------------------|
| `ok`         | a symlink to exactly the source file                                 |
| `missing`    | nothing at the target                                                |
| `stale-link` | a symlink to some other path inside the source tree (renamed source) |
| `conflict`   | anything else: a real file, a directory, a symlink to outside        |

A **dangling link** is a symlink into the source tree at a path that no
longer exists -- what a moved or deleted source file leaves behind; it is
not a target, so only `dots prune` deals with it.

`apply` links `missing`, relinks `stale-link`, and refuses `conflict` unless
`--force`, which moves the conflicting thing into the **backup tree**
`~/.dotfiles-backup/<YYYYmmdd-HHMMSS>/` under its home-relative path.

## Links, not copies

`apply` creates real directories in `$HOME` and a **symlink** for every
managed file, pointing at the absolute source path.  Editing `~/.bashrc`
edits the repository; `git status` in the source tree shows what changed.
Modes live on the source file, since a symlink has none of its own.

## Modules, loaders, knobs, hooks

- **loader** -- the file at the `$HOME` entry point (`~/.bashrc`,
  `~/.vimrc`, `~/.tmux.conf`, `~/.gitconfig`).  Each does nothing but read
  a directory of modules in order and the hook files around them.
- **module** -- one numbered file with one responsibility:
  `~/.config/bash/rc.d/NN-name.sh`, `~/.vim/rc/NN-name.vim`,
  `~/.config/tmux/conf.d/NN-name.conf`, `~/.config/git/name.gitconfig`.
  Renaming a module with the suffix `.off` keeps it in the repository but
  out of the load (the loaders glob on the real extension).
- **module name** -- the file name without its number and extension:
  `70-conda.sh` is `conda`.  Used by the disabled list and by
  `DOTFILES_DEBUG=1`.
- **setting** or **option** -- one thing a configuration file does, with
  its **description**: the comment lines directly above it.  A setting is
  **on** when its code is live and **off** when each of its lines starts
  with the file's comment character directly followed by the code
  (`#shopt -s histverify`); **switching** it is deleting or adding that one
  character.  `dots options` lists them (`Option` in the code; see
  [the options format](configuration.md#the-options-format)).
- **`Needs:` line** -- a description line naming what a setting that is
  off requires (`# Needs: delta`); the switch-on test skips it while that
  is missing.
- **knob** -- a variable a module reads at load time with a default, for
  a value that differs between machines:
  `${DOTFILES_HISTSIZE:-50000}` in bash, `get(g:, 'dotfiles_indent', 2)` in
  vim.  Every module lists its knobs in a `Knobs:` block in its header.
- **hook file** -- a machine-local, never-committed file a loader reads:
  `~/.bashrc.before` (first, for knobs), `~/.bashrc.local` (last, for
  overrides), and the same pair for vim; `~/.tmux.conf.local`,
  `~/.gitconfig.local`, `~/.ssh/config.local`.  See
  [configuration.md](configuration.md#hook-files) for the full list.
- **disabled list** -- `~/.config/bash/disabled`, one module name per line;
  the bash loader skips those on this machine only.

## The prompt

`~/.config/bash/prompt/prompt.sh`, `lib/` and `segments/` are a **vendored snapshot** of
[bash-prompt-toolkit](../../bash-prompt-toolkit) (its version is in the file
headers).  `layout.sh` is the local configuration -- which **segments** are
registered, the **row** templates, and which **layout** `DOTFILES_PROMPT_LAYOUT`
selects.
