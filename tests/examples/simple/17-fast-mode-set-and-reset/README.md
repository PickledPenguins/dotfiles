# Set fast mode for this machine, then reset it

**Level:** simple

## What it shows

`dots fast MODE` writes the mode to `~/.config/bash/fast`, says when `DOTS_FAST` in the environment overrides that file, and `dots fast reset` removes the file, leaving the default (off).

## Expected

The file holding `auto`, then `on` with the override line, then the removal, and an empty directory. The exact output is `expected.txt`; `case.sh` is the script, run from a fresh HOME with `dots` on PATH and `$SRC` as the source directory.
