# Move files around in the source

**Level:** complex

## What it shows

A linked home, then the source is reorganized with `git mv`: one file gains an attribute prefix (same target, so its link is stale and `apply` relinks it and tightens the mode), one directory is moved (new targets appear as missing; the old links are left behind, pointing nowhere, because they are no longer targets), and one file is deleted.  `status` and `apply` show what they own; `prune` removes the dangling links they do not.

## Why the combination matters

Renames, moves and deletions in the source each leave a different trace in HOME, and only the rename is repaired by `apply`; the case documents the boundary between what `apply` owns and what `prune` cleans, so the leftover links are expected and then gone.

## Expected

`relink` for the re-prefixed file, `link` for the moved directory's files, then the old `.config/app/*` and `.obsolete` links show up in `find -xtype l`, `prune -n` counts three, `prune` removes them and `find` counts zero.  The exact output is `expected.txt`; `case.sh` is the script, run from a fresh HOME with `dots` on PATH and `$SRC` as the source directory.
