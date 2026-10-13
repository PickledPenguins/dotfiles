# List what would be managed

**Level:** simple

## What it shows

`dots managed` prints the target path of every file in the source tree, with the `dot_` prefix turned into a leading dot, sorted by target.

## Expected

Two targets, both starting with a dot, in alphabetical order. The exact output is `expected.txt`; `case.sh` is the script, run from a fresh HOME with `dots` on PATH and `$SRC` as the source directory.
