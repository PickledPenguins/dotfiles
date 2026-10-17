# A broken symlink in the source tree

**Level:** failure

## What it shows

A source file that is a symlink to nothing stops `apply` with a Python traceback ending in `FileNotFoundError` naming it, before any target is linked, so a run never stops halfway.

## Expected

`FileNotFoundError` on stderr, exit 1, nothing linked. The exact output is `expected.txt`; `case.sh` is the script, run from a fresh HOME with `dots` on PATH and `$SRC` as the source directory.
