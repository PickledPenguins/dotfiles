# Directories are real, files are links

**Level:** simple

## What it shows

A nested source path creates real directories in HOME; only the file at the end is a symlink.

## Expected

`~/.config/git` is a directory (not a link); `~/.config/git/config` is a link. The exact output is `expected.txt`; `case.sh` is the script, run from a fresh HOME with `dots` on PATH and `$SRC` as the source directory.
