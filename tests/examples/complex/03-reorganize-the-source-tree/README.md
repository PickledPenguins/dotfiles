# Move files around in the source

**Level:** complex

## What it shows

A linked home, then the source is reorganized with `git mv`: one file gains an attribute prefix (same target, so its link is stale and `apply` relinks it and tightens the mode), one directory is moved (new targets appear as missing; the old links are left behind, pointing nowhere, because they are no longer targets), and one file is deleted.  `status` and `apply` show exactly what dots does and does not clean up.

## Why the combination matters

Renames, moves and deletions in the source each leave a different trace in HOME, and only the rename is repaired automatically; the case documents the boundary of what `apply` owns so the leftover links are expected, not a surprise.

## Expected

`relink` for the re-prefixed file, `link` for the moved directory's files, and the old `.config/app/*` and `.obsolete` links remain as dangling symlinks that `find -xtype l` reveals -- dots has no prune.  The exact output is `expected.txt`; `case.sh` is the script, run from a fresh HOME with `dots` on PATH and `$SRC` as the source directory.
