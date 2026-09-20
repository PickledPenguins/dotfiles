# Status before and after apply

**Level:** simple

## What it shows

`dots status` lists targets that are not linked correctly and exits 1; after `apply` it prints only the ok count and exits 0.

## Expected

`missing` lines then exit 1; after apply `ok: 2` and exit 0.  The exact output is `expected.txt`; `case.sh` is the script, run from a fresh HOME with `dots` on PATH and `$SRC` as the source directory.
