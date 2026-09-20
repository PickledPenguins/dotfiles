# .dotsignore skips targets

**Level:** simple

## What it shows

Target paths listed in `.dotsignore` (glob patterns, `#` comments) are never managed; the file itself, like any root dotfile, is not managed either.

## Expected

`managed` lists `.bashrc` only; README.md and .dotsignore are absent.  The exact output is `expected.txt`; `case.sh` is the script, run from a fresh HOME with `dots` on PATH and `$SRC` as the source directory.
