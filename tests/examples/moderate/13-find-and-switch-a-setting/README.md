# Find a setting, then switch it on

**Level:** moderate

## What it shows

The real configuration: `dots options` finds `nocasematch` without knowing which file holds it; deleting the `#` in front of its line (here with sed, in the source tree the link points to) turns it on in the next shell, and `dots options` then reports it `on`.

## Expected

The file and the setting's line, then `off` from bash, then `on` from dots and from bash.  The exact output is `expected.txt`; `case.sh` is the script, run from a fresh HOME with `dots` on PATH and `$SRC` as a copy of this repository.
