# List every target, including the ok ones

**Level:** simple

## What it shows

`status --all` prints a line per target with its state, not just the problems.

## Expected

`ok` for the linked file, `missing` for the other, summary counts both.  The exact output is `expected.txt`; `case.sh` is the script, run from a fresh HOME with `dots` on PATH and `$SRC` as the source directory.
