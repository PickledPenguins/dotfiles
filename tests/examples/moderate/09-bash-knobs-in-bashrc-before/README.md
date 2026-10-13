# Knobs from ~/.bashrc.before

**Level:** moderate

## What it shows

`~/.bashrc.before` is sourced before the modules, so `DOTFILES_*` variables set there change what the modules do: here the history size and the editor.

## Expected

HISTSIZE 500 and EDITOR nano. The exact output is `expected.txt`; `case.sh` is the script, run from a fresh HOME with `dots` on PATH and `$SRC` as the source directory.
