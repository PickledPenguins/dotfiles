# An unreadable .dotsignore

**Level:** failure

## What it shows

A `.dotsignore` that cannot be read is a hard error (a Python traceback ending in PermissionError) rather than a silent apply of everything -- ignoring the ignore list could link secrets.

## Expected

`PermissionError` on stderr, exit 1, nothing linked. The exact output is `expected.txt`; `case.sh` is the script, run from a fresh HOME with `dots` on PATH and `$SRC` as the source directory.
