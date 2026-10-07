# Force twice, with an older backup already there

**Level:** complex

## What it shows

`apply --force` replaces a real `~/.bashrc` and backs it up; later something writes a real file over the link again, and a second `--force` backs that one up too.

## Why the combination matters

The backup tree is the only copy of what `--force` replaced.  The second run must start a new timestamped tree beside the first rather than write over the older backup of the same path.

## Expected

Two backup trees, each holding its own `.bashrc` (`theirs one`, `theirs two`), and a final status of `ok: 1`.  The exact output is `expected.txt`; `case.sh` is the script, run from a fresh HOME with `dots` on PATH and `$SRC` as the source directory.
