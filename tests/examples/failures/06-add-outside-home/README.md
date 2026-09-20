# Adding a file that is not under HOME

**Level:** failure

## What it shows

`add` only manages files inside the home directory; anything else is skipped with the reason, including a path that escapes with `..`.

## Expected

`skip ... not under HOME` for both, exit 0, file untouched.  The exact output is `expected.txt`; `case.sh` is the script, run from a fresh HOME with `dots` on PATH and `$SRC` as the source directory.
