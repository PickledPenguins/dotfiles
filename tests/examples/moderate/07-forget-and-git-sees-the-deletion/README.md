# forget in a git-tracked source

**Level:** moderate

## What it shows

After `forget`, the source file is gone, so `git status` in the source tree shows a deletion, while HOME keeps a working copy.

## Expected

`D dot_vimrc` from git; `~/.vimrc` is a regular file.  The exact output is `expected.txt`; `case.sh` is the script, run from a fresh HOME with `dots` on PATH and `$SRC` as the source directory.
