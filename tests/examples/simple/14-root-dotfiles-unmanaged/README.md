# The repository's own dotfiles are not targets

**Level:** simple

## What it shows

Entries in the source root whose name starts with `.` -- `.git`, `.gitignore`, `.dotsignore` -- are skipped, so a git-managed source tree does not link its own metadata into HOME.

## Expected

Only `.bashrc` is managed. The exact output is `expected.txt`; `case.sh` is the script, run from a fresh HOME with `dots` on PATH and `$SRC` as the source directory.
