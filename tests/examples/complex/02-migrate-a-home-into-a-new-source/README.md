# Turn an existing home into a repository

**Level:** complex

## What it shows

Starting from an empty source tree and a lived-in home directory: `add` a mix of files -- readable, secret (600), executable, nested under `.config` -- in one command, commit the result, `forget` the one that should not have been added, and verify the source layout, the modes, and that every link resolves.

## Why the combination matters

`add` has to get every attribute right across files that differ only in mode, and a mistake there is permanent once committed; the case runs the whole import-commit-correct cycle so the git history, the modes and the links are checked against each other rather than one at a time.

## Expected

Source names carry the right prefixes, git commits eight files, `forget` leaves a regular `.netrc` and a git deletion, final status `ok: 7`. The exact output is `expected.txt`; `case.sh` is the script, run from a fresh HOME with `dots` on PATH and `$SRC` as the source directory.
