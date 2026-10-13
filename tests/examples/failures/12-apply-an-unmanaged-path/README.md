# apply or status on a path dots does not manage

**Level:** failure

## What it shows

A path that selects no managed target, such as a typo, is reported as not managed and the exit status is 1, while the paths that do match are still applied. `status` and `unlink` do the same.

## Expected

`link .vimrc`, then `skip ... not managed` and `1 change(s)`, exit 1; then `status` of the typo alone: `skip`, `nothing managed`, exit 1. The exact output is `expected.txt`; `case.sh` is the script, run from a fresh HOME with `dots` on PATH and `$SRC` as the source directory.
