# Per-machine module disable list

**Level:** moderate

## What it shows

With the real repository applied, `~/.config/bash/disabled` names modules to skip on this machine only. `DOTFILES_DEBUG=1` shows the skip.

## Expected

`bashrc: skip functions`, and `mkcd` is not defined; every other module loads. The exact output is `expected.txt`; `case.sh` is the script, run from a fresh HOME with `dots` on PATH and `$SRC` as the source directory.
