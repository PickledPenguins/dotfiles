# Two source files with one target

**Level:** failure

## What it shows

`dot_bashrc` and `private_dot_bashrc` both map to `~/.bashrc`. Every command refuses the source tree, naming both files, rather than relinking the target to each in turn on every apply.

## Expected

One line on stderr naming both sources and the target, exit 2, from `apply` and `status` alike; nothing linked. The exact output is `expected.txt`; `case.sh` is the script, run from a fresh HOME with `dots` on PATH and `$SRC` as the source directory.
