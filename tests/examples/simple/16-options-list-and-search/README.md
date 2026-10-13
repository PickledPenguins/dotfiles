# List and search the settings

**Level:** simple

## What it shows

`dots options` lists every described setting of a file in the options format, with its line and `on` or `off`; `--off` keeps the ones that are off; a word narrows the list and `-f` prints the whole description and the code.

## Expected

Both settings, then only the one that is off, then that one in full. The exact output is `expected.txt`; `case.sh` is the script, run from a fresh HOME with `dots` on PATH and `$SRC` as the source directory.
