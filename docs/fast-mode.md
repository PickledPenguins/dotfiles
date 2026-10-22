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
| prompt git status (*directory*) | untracked files as `status.showUntrackedFiles` says | `-unormal`: untracked directories are not gone into |
| git looking for a repository | stops at `/home` and `/net` (`DOTFILES_GIT_CEILING`, `00-env.sh`): no lookup in an automounter or a slow NFS parent | the same |
| every git command (*directory*) | your git config | also `core.untrackedCache=true`, `core.trustctime=false`, `core.checkStat=minimal` through `GIT_CONFIG_COUNT` (git 2.31+): fewer stats and file reads per status; a change of the same size within the same second can go unseen |
| history file | `~/.local/state/bash/history`, one for every host | `history.HOST` next to it, this host's own (a copy of the shared one when first used), so the append at each prompt never mixes with another host's on an NFS home. Taken at shell start |
| shell start | the set-up dircolors, lesspipe, `fzf --bash`, `zoxide init` and `direnv hook` print is kept in `~/.cache/bash/eval.HOST` and read from there while each program (and `~/.dircolors`) keeps its modification time: a start runs none of them | the same |
| conda environment at start (`DOTFILES_CONDA_ENV`) | `conda activate`: a python start, about 1 s | what `conda activate` printed at an earlier start, kept in `~/.cache/bash/eval.HOST` while conda, the environment's `conda-meta/history` (written by every install and removal), `PATH` and `PS1` stay the same; only from a shell with no environment active. 1.1 s to 0.12 s here |
| vim swap files | `~/.vim/tmp/swap`, synced at each write | tmpfs (`$XDG_RUNTIME_DIR/vim-swap`, else `/dev/shm/vim-swap-USER`), never synced; ones older than 14 days go, looked for once a day. Taken from `DOTS_FAST_ACTIVE` when vim starts. Recovery works after vim dies, not after the machine does |
| Tab list (*directory*) | colors and `/ * @` marks (`colored-stats`, `visible-stats` in `~/.inputrc`) | neither: Tab stats nothing; the `/` after a completed directory name stays |
| after a cd (*directory*) | nothing | the first prompt there starts `ls -f` on it in the background, so the ls or Tab that follows reads the kernel's cache; one at a time, so a hung mount holds one process (`DOTS_FAST_PREFETCH`: `readdir`, `stat` each entry too, `off`) |
| ls colors (*directory*) | by type and by what a stat shows: executable, setuid, writable by others, orphan links | by type only, from the directory entry: ls stats nothing (`ls -F`, `ll` and links under `--group-directories-first` still do) |

Each module that has a fast form lists it in its header and here. The
rows marked *directory* also take their fast form under
`DOTS_FAST_PATHS` (below) while the mode is off.

## Fast directories

```bash
export DOTS_FAST_PATHS=/nfs/proj:/data:~/scratch   # in ~/.bashrc.before
```

Under these directories (each one and everything below it) the features
that depend on the directory take their fast form even while fast mode is
off: a slow NFS project does not need the whole shell in fast mode. A
leading `~` is `$HOME`; trailing slashes do not matter.

The shell looks again at each prompt whose directory changed, with a
string compare and no system call, before the prompt's git status. So the
prompt and Tab after a `cd` already see it; a command on the same line as
the `cd` (`cd /nfs/proj && ls`) does not. A directory reached through a
symbolic link counts by the path it was reached by (`$PWD`), not where
the link points.

The prompt shows cyan `fast-dir` there, and `dots fast` lists the paths
and says when the current directory is under one.

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
  - cyan `fast-dir` under `DOTS_FAST_PATHS` while the mode is off;
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

A feature that depends on the directory registers with
`dots_fast_dir_hook` instead: it is called with 1 in fast mode or under
`DOTS_FAST_PATHS`, 0 otherwise, now and whenever a mode change or a `cd`
changes that. `dots_fast_cd_hook` is called at the first prompt in each
new directory, with the same 1 or 0.

A module that evals what a program prints sources a kept copy instead:
`dots_eval_cached fzf --bash && source "$REPLY"` (`00-env.sh`).

Modules after `05-fast.sh` read `DOTS_FAST_ACTIVE` or register a hook;
`layout.sh` uses one for the git budget.
