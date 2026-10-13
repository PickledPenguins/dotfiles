# add takes regular files only

**Level:** failure

## What it shows

A directory or an existing symlink is skipped with the reason; the files inside a directory must be named individually.

## Expected

Two skip lines with reasons, exit 0. The exact output is `expected.txt`; `case.sh` is the script, run from a fresh HOME with `dots` on PATH and `$SRC` as the source directory.
