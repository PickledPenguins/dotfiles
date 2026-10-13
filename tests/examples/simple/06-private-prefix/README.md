# private_ makes a file 600 and its directory 700

**Level:** simple

## What it shows

The `private_` prefix on a directory component gives the target directory mode 700, and on a file strips group and other bits from the source file.

## Expected

`~/.ssh` is 700 and the source `config` is 600, whatever they were before. The exact output is `expected.txt`; `case.sh` is the script, run from a fresh HOME with `dots` on PATH and `$SRC` as the source directory.
