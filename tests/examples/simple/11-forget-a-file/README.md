# Stop managing a file

**Level:** simple

## What it shows

`dots forget` replaces the link with a real copy and deletes the source file, so the file stays in HOME but leaves the repository.

## Expected

`~/.vimrc` is a regular file with the same content; source gone; managed empty. The exact output is `expected.txt`; `case.sh` is the script, run from a fresh HOME with `dots` on PATH and `$SRC` as the source directory.
