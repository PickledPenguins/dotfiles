# add reads the mode

**Level:** moderate

## What it shows

`add` chooses `private_` when the file has no permission bits for others and `executable_` when the owner can execute it; `--private` forces the former.

## Expected

Four files, four different source names. The exact output is `expected.txt`; `case.sh` is the script, run from a fresh HOME with `dots` on PATH and `$SRC` as the source directory.
