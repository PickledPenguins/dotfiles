# Apply only part of the tree

**Level:** moderate

## What it shows

Paths after `apply`, `status` or `unlink` restrict them to targets under those paths.  Useful for trying one tool's configuration on a machine before the rest.

## Expected

Only the tmux and git targets are linked; status of the rest is still missing.  The exact output is `expected.txt`; `case.sh` is the script, run from a fresh HOME with `dots` on PATH and `$SRC` as the source directory.
