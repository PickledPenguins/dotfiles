# add needs at least one file

**Level:** failure

## What it shows

`add` and `forget` require paths; argparse says so and exits 2.

## Expected

`the following arguments are required: paths`, exit 2, for both.  The exact output is `expected.txt`; `case.sh` is the script, run from a fresh HOME with `dots` on PATH and `$SRC` as the source directory.
