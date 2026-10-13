# Bring an existing dotfile under management

**Level:** simple

## What it shows

`dots add` moves a real file from HOME into the source tree under its `dot_` name and leaves a symlink in its place.

## Expected

`add` line, source file exists, HOME path is now a link. The exact output is `expected.txt`; `case.sh` is the script, run from a fresh HOME with `dots` on PATH and `$SRC` as the source directory.
