# Link a single file

**Level:** simple

## What it shows

`dots apply` creates a symlink in HOME pointing back at the source file and reports one change.

## Expected

One `link` line, `1 change(s)`, and `readlink` shows the source path.  The exact output is `expected.txt`; `case.sh` is the script, run from a fresh HOME with `dots` on PATH and `$SRC` as the source directory.
