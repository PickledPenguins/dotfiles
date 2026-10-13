# Every local override at once

**Level:** complex

## What it shows

The repository applied, then every per-machine hook used together: `~/.bashrc.before` knobs (minimal prompt, extra PATH), `~/.config/bash/disabled` (conda, hpc, title), `~/.bashrc.local` (an alias that overrides a module's, and `unalias` switching the safe-rm aliases off for this machine), `~/.vimrc.before` and `~/.vimrc.local`, `~/.tmux.conf.local`, `~/.gitconfig.local`. Each program is asked what it ended up with.

## Why the combination matters

The hooks are read at different moments (before, during, after the modules) by four programs, and an ordering mistake in any loader would let a module silently undo a local setting; asking each program for its final value is the only check that covers the precedence end to end.

## Expected

bash: 11 modules loaded, 3 skipped, alias overridden, knob PATH first; vim: width 4 from before, scrolloff from local; tmux: history 7; git: identity and a push.default override. The exact output is `expected.txt`; `case.sh` is the script, run from a fresh HOME with `dots` on PATH and `$SRC` as the source directory.
