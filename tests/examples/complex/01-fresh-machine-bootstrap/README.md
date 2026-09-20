# Bootstrap a machine that already has dotfiles

**Level:** complex

## What it shows

The full repository applied onto a home directory in the state a new machine is usually in: a distribution `.bashrc` and `.profile`, a hand-written `.vimrc`, a `.gitconfig` with identity in it, and a `.tmux.conf` symlinked from an old dotfiles scheme.  `status` reports each, `apply` links everything it can and exits 1 for the rest, `apply --force` finishes the job, and the identity is moved to `~/.gitconfig.local` so git still knows who you are.

## Why the combination matters

Each conflict kind (real file, real file with data to keep, foreign symlink) appears together with dozens of clean targets, which is the state `--force` was designed for: the danger is losing the one file that mattered among many, and the check is that every original is in the backup tree and git identity survives the swap.

## Expected

Conflicts named, a partial apply with exit 1, then a clean status; bash loads all 14 modules, `git config user.name` still answers, and the backup tree holds the four originals under their home-relative paths.  The exact output is `expected.txt`; `case.sh` is the script, run from a fresh HOME with `dots` on PATH and `$SRC` as the source directory.
