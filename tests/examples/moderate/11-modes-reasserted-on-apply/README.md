# apply repairs drifted modes

**Level:** moderate

## What it shows

An already-linked `private_` file whose mode was loosened is tightened again on the next `apply`, even though nothing is reported as changed.

## Expected

`0 change(s)` yet the mode is back to 600.  The exact output is `expected.txt`; `case.sh` is the script, run from a fresh HOME with `dots` on PATH and `$SRC` as the source directory.
