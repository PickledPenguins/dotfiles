# executable_ makes a script runnable

**Level:** simple

## What it shows

The `executable_` prefix adds u+x to the source file, so the link in `~/.local/bin` runs.

## Expected

The script prints `hi` when run through its link. The exact output is `expected.txt`; `case.sh` is the script, run from a fresh HOME with `dots` on PATH and `$SRC` as the source directory.
