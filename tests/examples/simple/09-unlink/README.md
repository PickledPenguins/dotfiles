# Remove the links, keep the source

**Level:** simple

## What it shows

`dots unlink` removes every symlink `apply` made and nothing else; the source tree is untouched.

## Expected

`1 link(s) removed`, `~/.bashrc` gone, source file still there. The exact output is `expected.txt`; `case.sh` is the script, run from a fresh HOME with `dots` on PATH and `$SRC` as the source directory.
