# Knobs from ~/.bashrc.before

**Level:** moderate

## What it shows

`~/.bashrc.before` is sourced before the modules, so `DOTFILES_*` variables set there change what the modules do: history size, the safe-rm aliases, the prompt layout.

## Expected

HISTSIZE 500, no `rm` alias, and a one-line prompt.  The exact output is `expected.txt`; `case.sh` is the script, run from a fresh HOME with `dots` on PATH and `$SRC` as the source directory.
