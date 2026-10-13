# apply leaves conflicts behind

**Level:** failure

## What it shows

When real files stand in the way, `apply` still links everything else, counts the conflicts in its summary, and exits 1 so a script can stop.

## Expected

One link, one conflict, `1 change(s), 1 conflict(s) left`, exit 1. The exact output is `expected.txt`; `case.sh` is the script, run from a fresh HOME with `dots` on PATH and `$SRC` as the source directory.
