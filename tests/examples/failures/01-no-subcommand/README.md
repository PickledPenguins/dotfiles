# Running dots with no subcommand

**Level:** failure

## What it shows

argparse reports the missing subcommand and exits 2.

## Expected

usage line, `the following arguments are required: cmd`, exit 2. The exact output is `expected.txt`; `case.sh` is the script, run from a fresh HOME with `dots` on PATH and `$SRC` as the source directory.
