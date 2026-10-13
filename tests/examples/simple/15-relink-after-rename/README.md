# A renamed source file is relinked

**Level:** simple

## What it shows

When a link points at another path inside the source tree (the file was renamed or moved), `apply` reports `relink` and fixes it without --force.

## Expected

`relink` line, and the link now points at the new source name. The exact output is `expected.txt`; `case.sh` is the script, run from a fresh HOME with `dots` on PATH and `$SRC` as the source directory.
