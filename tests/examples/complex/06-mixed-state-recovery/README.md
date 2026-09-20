# Every target state in one home

**Level:** complex

## What it shows

Six targets, one in each state a home can be in: correctly linked, missing, stale link (renamed source), real file, foreign symlink, and a directory where a file belongs.  `status` classifies all six, `apply` fixes what it may and exits 1, `--force` finishes, and the backup tree holds exactly the three things that were replaced.

## Why the combination matters

The four classifications drive three different actions, and a home that is half migrated has all of them at once; running them together checks that fixing one state never changes how the next is classified, and that the backup contains the conflicts and only the conflicts.

## Expected

status: 1 ok, 1 missing, 1 stale-link, 3 conflict; apply: link + relink, 3 conflicts left, exit 1; --force: 3 replaced, exit 0; backup has 3 entries.  The exact output is `expected.txt`; `case.sh` is the script, run from a fresh HOME with `dots` on PATH and `$SRC` as the source directory.
