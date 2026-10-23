# A fast mode dots does not know

**Level:** failure

## What it shows

`dots fast` takes `on`, `off`, `auto` or `reset`; any other word stops it with argparse's usage line and the choices, before anything is written.

## Expected

The usage line and `invalid choice: 'maybe'`, exit 2, nothing written. The exact output is `expected.txt`; `case.sh` is the script, run from a fresh HOME with `dots` on PATH and `$SRC` as the source directory.
