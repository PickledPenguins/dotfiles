# Links from an older scheme

**Level:** moderate

## What it shows

A `~/.bashrc` that is already a symlink to somewhere outside the source tree (an old `~/env/` scheme) is a conflict, not a stale link: `--force` backs up the link itself and the file it pointed to is left alone.

## Expected

conflict, then after --force the backup is a symlink and `~/env/.bashrc` is unchanged.  The exact output is `expected.txt`; `case.sh` is the script, run from a fresh HOME with `dots` on PATH and `$SRC` as the source directory.
