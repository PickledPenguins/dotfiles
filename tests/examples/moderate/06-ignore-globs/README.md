# Ignore patterns: globs and directories

**Level:** moderate

## What it shows

A pattern matches the target-relative path. `*` crosses `/`, a bare directory name skips everything under it, and patterns are anchored at the top (`README.md` does not match `docs/README.md`).

## Expected

`.config/x.local` and everything under `.cache` skipped; `.config/docs/README.md` kept. The exact output is `expected.txt`; `case.sh` is the script, run from a fresh HOME with `dots` on PATH and `$SRC` as the source directory.
