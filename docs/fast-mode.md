# Fast mode

For a server whose disk, NFS mounts, CPU or memory is slow. In fast mode
the shell and vim give up the features that stat every file, write to disk
or wait on a slow program at each prompt, for cheaper forms of the same.
Back to the [README](../README.md); the module is `05-fast.sh`
([configuration.md](configuration.md#bash-modules-configbashrcd)).

## Turning it on

```bash
dots fast            # the mode, where it comes from, and every signal
dots fast auto       # decide at each shell start (below)
dots fast on         # always on on this machine
dots fast off        # always off, even when auto would turn it on
dots fast reset      # remove the setting: off
DOTS_FAST=on bash    # one shell, over the setting
```

The mode comes from the first of:

1. `DOTS_FAST` in the environment (`on`, `off` or `auto`), for one shell or
   set in `~/.bashrc.before` for this machine;
2. `~/.config/bash/fast`, which `dots fast` writes;
3. off.

`dots fast off` is how to overrule auto: it wins over any signal. A word
that is not `on`, `off` or `auto` is reported and taken as off.

`dots fast X` applies at once in the shell that ran it (the `dots` shell
function decides again); other open shells keep their mode until they
start again.

## What changes

| Where | Always | In fast mode |
|-------|--------|--------------|
| prompt git status | waits at most 1 s, then shows `…` and picks the result up later | waits at most 0.2 s |

Each module that has a fast form lists it in its header and here.

## Auto

Auto decides at shell start. It never tests a disk itself: it reads what
the kernel already counts, and what earlier shells on this host measured.

Host signals, read from `/proc` with shell builtins (no PSI, which RHEL
kernels lack):

| Signal | Source | On at | Knob |
|--------|--------|-------|------|
| blocked | `procs_blocked`, `/proc/stat`: tasks waiting on I/O now | 2 or more | `DOTS_FAST_BLOCKED` |
| iowait | cpu line of `/proc/stat` | 20 % or more | `DOTS_FAST_IOWAIT` |
| load | 1-minute load, `/proc/loadavg`, per CPU | 150 % or more | `DOTS_FAST_LOAD` |
| steal | cpu line of `/proc/stat` | 10 % or more | `DOTS_FAST_STEAL` |
| mem | `MemAvailable` of `MemTotal`, `/proc/meminfo` | 10 % or less | `DOTS_FAST_MEM` |
| swapin | `pswpin`, `/proc/vmstat`, pages per second | 100 or more | `DOTS_FAST_SWAPIN` |

iowait, steal and swapin are rates over the time since the last shell or
prompt on this host looked (between 1 s and 10 minutes ago; otherwise they
are left out that time). On Linux the load counts tasks stuck on I/O as
well as running ones, so a hung NFS mount raises it on an idle CPU.

Samples: each shell start (from the process start in `/proc/$$/stat` to
the end of `~/.bashrc`) and each prompt git status that had to run git is
a sample, slow at `DOTS_FAST_STARTUP_MS` (300) and `DOTS_FAST_GIT_MS`
(200) ms. A git status that ran past the prompt's budget is slow. The last
10 samples on this host are kept.

Verdict:

- on when a host signal is over its threshold now, or 2 of the last 5
  samples were slow;
- once on, off only after the last 10 samples are all fast, so a disk that
  is slow every other minute does not flip the mode at every shell;
- in a running shell, auto turns on after 2 of its last 5 git refreshes
  were slow, with the notice. It never turns off mid-session.

NFS and disk times differ from one run to the next; one slow sample out of
five does not turn it on, and one fast one does not turn it off.

To pick thresholds, run `sprobe` (linuxbin) on the server when it feels
slow and when it does not: it prints the same signals, the disk times of
each path you work on, git and shell start, against the same `DOTS_FAST_*`
variables.

## Seeing it

- At shell start, on stderr, bold and reversed:
  `FAST MODE ON  auto: iowait 23% >= 20` or
  `FAST MODE ON  forced: dots fast on`. The same line when auto turns on
  mid-session.
- The prompt's top row, before the bar:
  - nothing while all is well;
  - yellow `slow blk3 ld1.8 mem7% git340` while signals are over their
    thresholds and the mode is off (blk tasks blocked, io iowait, ld load
    per CPU, st steal, mem memory available, swp pages swapped in per
    second, git the last git status in ms);
  - reverse red `FAST` and the values when auto turned it on;
  - reverse red `FAST!` when forced on;
  - `DOTS_FAST_PROMPT=always`: the values, dim, even when all is well.

  The values are read every 10 s.
- Vim's status line shows `[FAST]` when the shell that started it was in
  fast mode (`DOTS_FAST_ACTIVE=1`, exported while fast mode is on).

## Where samples are kept

In tmpfs: `$XDG_RUNTIME_DIR`, else `/dev/shm/dots-UID`, else
`/tmp/dots-UID` (made mode 700, and used only when it is the user's own).
Three files per host, `dots-fast.HOST.ring` (10 lines), `.state` (the last
verdict) and `.base` (the counters the rates start from); nothing grows,
so a server up for years needs no reboot to clear them. Without any of
those directories auto has the host signals only.

## For modules

```bash
_my_fast() { if (( $1 )); then cheap_form; else full_form; fi; }
dots_fast_hook _my_fast      # called now with 1 or 0, and on every change
```

Modules after `05-fast.sh` read `DOTS_FAST_ACTIVE` or register a hook;
`layout.sh` uses one for the git budget.
