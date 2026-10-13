# A real file in the way

**Level:** moderate

## What it shows

`apply` refuses to replace a real file and exits 1; `--force` moves it into `~/.dotfiles-backup/<timestamp>/` under its home-relative path and links. The backup keeps the user's content byte for byte.

## Expected

`conflict` and exit 1 first; then `replace` + `backup` lines, exit 0, and `cat` of the backup shows the original content. The exact output is `expected.txt`; `case.sh` is the script, run from a fresh HOME with `dots` on PATH and `$SRC` as the source directory.
