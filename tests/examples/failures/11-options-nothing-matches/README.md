# A search that matches nothing

**Level:** failure

## What it shows

`dots options` with words that no setting contains prints nothing and exits 1, as grep does, so scripts can test for a setting; `--on` and `--off` together are a usage error.

## Expected

No output and `exit 1`, then the argparse message and `exit 2`. The exact output is `expected.txt`; `case.sh` is the script, run from a fresh HOME with `dots` on PATH and `$SRC` as a copy of this repository.
