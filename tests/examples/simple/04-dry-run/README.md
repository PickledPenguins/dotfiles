# See the plan without doing it

**Level:** simple

## What it shows

`apply -n` prints what `apply` would do and leaves HOME untouched.

## Expected

The plan line, `(dry run)` in the summary, and HOME still empty. The exact output is `expected.txt`; `case.sh` is the script, run from a fresh HOME with `dots` on PATH and `$SRC` as the source directory.
