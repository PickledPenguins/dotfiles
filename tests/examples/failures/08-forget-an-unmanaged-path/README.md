# forget on something dots does not manage

**Level:** failure

## What it shows

`forget` reports the path as not managed and exits 1, while still forgetting any managed paths named alongside it.

## Expected

`forget .vimrc` then `skip ... not managed`, exit 1.  The exact output is `expected.txt`; `case.sh` is the script, run from a fresh HOME with `dots` on PATH and `$SRC` as the source directory.
