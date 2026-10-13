# Prune after the source tree is reorganized

**Level:** complex

## What it shows

A source directory is renamed and a `.dotsignore` line stops another one being managed. `prune` removes the links the rename left dangling, `apply` creates the new ones, and the link into the now-ignored directory stays.

## Why the combination matters

After a rename, the old links are no longer targets, so `apply` and `unlink` never see them; only `prune` does. An ignored path is also no longer a target, but its link still resolves, and `prune` must not take a working link for an orphan.

## Expected

`prune` removes exactly `.config/app/rc`; `apply` links `.config/tool/rc`; `~/notes/todo` is still a link; final status `ok: 2`. The exact output is `expected.txt`; `case.sh` is the script, run from a fresh HOME with `dots` on PATH and `$SRC` as the source directory.
