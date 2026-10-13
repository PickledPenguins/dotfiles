# add, then commit the source tree

**Level:** moderate

## What it shows

The source tree is a git repository. `add` moves a file in; `git status` shows it as a new file; after the commit, `status` is clean and the HOME link still resolves.

## Expected

git sees `dot_vimrc` as untracked, then committed; dots status `ok: 1`. The exact output is `expected.txt`; `case.sh` is the script, run from a fresh HOME with `dots` on PATH and `$SRC` as the source directory.
