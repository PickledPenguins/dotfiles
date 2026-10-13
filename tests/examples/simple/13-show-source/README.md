# Map targets to source files

**Level:** simple

## What it shows

`managed --show-source` prints the source path for each target, in the same order as `managed`.

## Expected

Absolute source paths, one per line. The exact output is `expected.txt`; `case.sh` is the script, run from a fresh HOME with `dots` on PATH and `$SRC` as the source directory.
