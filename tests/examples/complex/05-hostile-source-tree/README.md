# A source tree full of edge cases

**Level:** complex

## What it shows

Names that would map to the home directory itself (`dot_`, `private_`), a nested `private_` directory, file names with spaces and quotes, an empty file, a dotfile below the root, a `.dotsignore` with comments and globs, plus a real file in the way -- applied with `--force`.  The home directory must survive, the warnings must name the culprits, and every legitimate file must link with the right mode.

## Why the combination matters

`--force` is the one destructive switch, and a naming bug that resolved a target to `~` would hand the whole home directory to the backup routine; the traps are placed next to legitimate awkward names so the guard is shown to reject exactly the dangerous ones and nothing else.

## Expected

Two `dots: ignoring` warnings on stderr, exit 0, `precious` still in HOME, `.ssh` 700, the odd names linked, the ignored path absent.  The exact output is `expected.txt`; `case.sh` is the script, run from a fresh HOME with `dots` on PATH and `$SRC` as the source directory.
