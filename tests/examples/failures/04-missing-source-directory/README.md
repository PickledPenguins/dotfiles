# The source directory does not exist

**Level:** failure

## What it shows

`-S` (or `$DOTS_SOURCE`) naming a directory that is not there is reported on stderr with exit 2, before anything is touched.

## Expected

One line naming the missing directory, exit 2. The exact output is `expected.txt`; `case.sh` is the script, run from a fresh HOME with `dots` on PATH and `$SRC` as the source directory.
