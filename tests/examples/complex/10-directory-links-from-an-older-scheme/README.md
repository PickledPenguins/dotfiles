# A directory link into the source, from an older scheme

**Level:** complex

## What it shows

`~/.vim` is a symlink to the source's `dot_vim/`, as an older linking scheme left it.  Every file below it is the source file itself.  `apply --force` and `forget` both refuse it and say which directory to replace; once `~/.vim` is removed, a plain `apply` links file by file.

## Why the combination matters

Through the directory link, a target and its source are the same file.  A backup would move the source away and the new link would point at itself; a `forget` would delete both.  Each command looks at one target, so the case runs the whole migration to show the refusal holds in every command that removes something.

## Expected

`status` reports a conflict, `apply --force` and `forget` exit 1 with the source file untouched, and after `rm ~/.vim` the final status is `ok: 2`.  The exact output is `expected.txt`; `case.sh` is the script, run from a fresh HOME with `dots` on PATH and `$SRC` as the source directory.
