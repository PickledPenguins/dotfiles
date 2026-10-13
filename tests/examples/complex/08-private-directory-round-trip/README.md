# A private directory: add, forget, apply

**Level:** complex

## What it shows

`~/.ssh` comes from `private_dot_ssh/`. A new `known_hosts` is added into that same source directory, then forgotten again, and a final `apply` leaves the directory as it found it.

## Why the combination matters

`add` names the source path from the target path alone; under a `private_` directory it has to reuse the existing source directory rather than create a `dot_ssh/` beside it, or `~/.ssh` would have two sources and its mode would depend on which one was walked. `forget` then has to hand back a real file inside the 700 directory.

## Expected

One source directory, `~/.ssh` at 700, `known_hosts` a real file again after `forget`, and `ok: 1`. The exact output is `expected.txt`; `case.sh` is the script, run from a fresh HOME with `dots` on PATH and `$SRC` as the source directory.
