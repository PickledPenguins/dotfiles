# Unlink one tool, reapply later

**Level:** moderate

## What it shows

`unlink PATH` removes links under one path only; `status` then shows them missing while the rest stay ok; `apply` puts them back.

## Expected

2 links removed under `.config`, status mixed, apply relinks 2. The exact output is `expected.txt`; `case.sh` is the script, run from a fresh HOME with `dots` on PATH and `$SRC` as the source directory.
