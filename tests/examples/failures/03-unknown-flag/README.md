# A flag the subcommand does not have

**Level:** failure

## What it shows

Unknown options are rejected with the subcommand's usage line, exit 2.

## Expected

`unrecognized arguments: --frobnicate`, exit 2. The exact output is `expected.txt`; `case.sh` is the script, run from a fresh HOME with `dots` on PATH and `$SRC` as the source directory.
