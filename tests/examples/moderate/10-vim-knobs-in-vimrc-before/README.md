# Knobs from ~/.vimrc.before

**Level:** moderate

## What it shows

`~/.vimrc.before` sets `g:dotfiles_*` before the vim modules load: indent width and fold method.  `~/.vimrc.local` is read last and overrides a module directly.

## Expected

shiftwidth 4 and foldmethod marker from the knobs; scrolloff 9 from .vimrc.local.  The exact output is `expected.txt`; `case.sh` is the script, run from a fresh HOME with `dots` on PATH and `$SRC` as the source directory.
