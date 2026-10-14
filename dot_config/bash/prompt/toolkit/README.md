# Bash Prompt Toolkit

**Version:** 0.1.14

A composable bash `PS1` builder for terminal-centric HPC workflows — cached
git state, PBS/Slurm awareness, and a segment/row/layout system for
building your own prompt without touching string-concatenation spaghetti.

## Contents

**Using it**
- [What it looks like](#what-it-looks-like)
- [Installation](#installation)
- [Requirements](#requirements)
- [Segment reference](#segment-reference)
- [Customization](#customization)
- [Configuration and API reference](#configuration-and-api-reference)
- [Environment variables](#environment-variables)
- [Assumptions and limitations](#assumptions-and-limitations)

**Developing it**
- [Architecture](#architecture)
- [Project structure](#project-structure)
- [Testing](#testing)
- [Future work](#future-work)
- [Known issues](#known-issues)
- [Version history](#version-history)

## What it looks like

The default layout from `prompt_example.sh`, rendered in a git repo
inside a tmux session over SSH:

```
╭─[ chris@devbox ]────────────────────────────────[ ~/projects/myapp ]─╮
│  ⬇2  ⇄ ssh  ⧉ proj:2.1  :0  (py311)  ⚙ 2                              │
│  ⎇  feature/auth  →  origin/feature/auth  ↑3 ↓1                       │
│     +2 ~5 ?3  ⚑1                                                       │
╰─[✓] $
```

Every field is optional and every one is silent when it doesn't apply —
on a plain workstation outside a repo, the same configuration collapses
to just the identity row and the prompt character.

### Row 1 — identity and location

| Field | Token | Meaning | Shown when |
|---|---|---|---|
| `⚡` | `@root` | Running as root | `$EUID` is 0 |
| `chris@devbox` | `@user_host` | User and short hostname | Always |
| `~/projects/myapp` | `@pwd` | Working directory, `$HOME` collapsed to `~`, truncated to 35 columns with a leading `…` | Always |

### Row 2 — environment

| Field | Token | Meaning | Shown when |
|---|---|---|---|
| `⬇2` | `@shlvl` | Nested shell depth | `$SHLVL` > 1 |
| `⚖1.42` | `@load` | 1-minute load average | Load exceeds core count |
| `⛁92%` | `@disk` | Filesystem usage for `$PWD` | Usage ≥ 90% |
| `⇄ ssh` | `@ssh` | Shell arrived over SSH | `$SSH_CLIENT`/`$SSH_TTY` set |
| `⧉ proj:2.1` | `@tmux` | tmux session:window.pane | Inside tmux |
| `:0` | `@display` | X11 display | `$DISPLAY` set |
| `(py311)` | `@venv` | Python virtualenv name | `$VIRTUAL_ENV` set |
| `(myenv)` | `@conda` | Conda environment name | Set and not `base` |
| `⚙ 2` | `@jobs` | Background job count | At least one job |

### Row 3 — git branch and tracking

| Field | Token | Meaning | Shown when |
|---|---|---|---|
| `feature/auth` | `@git_branch` | Branch name, or short SHA when detached | Inside a repo |
| `origin/feature/auth` | `@git_remote` | Upstream tracking branch | Branch has an upstream |
| `↑3` / `↓1` / `✓` | `@git_ahead_behind` | Commits ahead (green), behind (yellow), or in sync | Branch has an upstream |
| `3efd58d` | `@git_sha` | Short SHA of HEAD | A commit exists |
| `9c1e0a2` | `@git_remote_sha` | Short SHA of the upstream branch | Branch has an upstream |

### Row 4 — git working tree

| Field | Token | Meaning | Shown when |
|---|---|---|---|
| `+2` | `@git_status` | Staged files (green) | Any staged |
| `~5` | `@git_status` | Modified files (yellow) | Any unstaged modifications |
| `?3` | `@git_status` | Untracked files (dim) | Any untracked |
| `⚑1` | `@git_stash` | Stash entry count | Stash is non-empty |
| `⚠1` | `@git_conflicts` | Unmerged/conflicted paths (bold red) | Mid-merge or mid-rebase |
| `(+2 ~5 ?3 ⚑1)` / `(✓)` | `@git_full_state` | The five counts above in one segment, or `✓` when all are zero | Inside a repo |

### Row 5 — status line

| Field | Token | Meaning | Shown when |
|---|---|---|---|
| `✓` / `✗ 127` | `@exit` | Last command's exit status | Always |

| `14:32` | `@time` | Wall clock, `HH:MM` | Only in layouts that use it |

### HPC row (not shown above — silent off-cluster)

| Field | Token | Meaning | Shown when |
|---|---|---|---|
| `PBS 819234` | `@pbs_job` | PBS job ID, suffix stripped | `$PBS_JOBID` set |
| `normal` | `@pbs_queue` | PBS queue name | `$PBS_QUEUE` set |
| `64 nodes` | `@pbs_nodes` | Unique nodes in `$PBS_NODEFILE` | Nodefile readable |
| `SLURM 4471` | `@slurm_job` | Slurm job ID | `$SLURM_JOB_ID` set |
| `gpu-a100` | `@slurm_queue` | Slurm partition | `$SLURM_JOB_PARTITION` set |
| `8 nodes` | `@slurm_nodes` | Slurm node count | `$SLURM_NNODES` set |
| `⊞ 6` | `@modules` | Loaded environment-module count | `$LOADEDMODULES` non-empty |
| `GPU 47%` | `@gpu` | GPU utilization, TTL-cached | `nvidia-smi` available |
## Installation

**Automated:**

```bash
./install.sh ~/dotfiles          # copies lib/, segments/, prompt.sh, prompt_example.sh there
                                  # and prints the two .bashrc lines below
```

`install.sh` also checks your bash version against the requirements
below and warns (doesn't block) if it's older than recommended.

**Manual:** copy `lib/`, `segments/`, `prompt.sh`, and `prompt_example.sh` to a
directory of your choice, then add to `.bashrc`, in this order:

```bash
source ~/dotfiles/prompt.sh
source ~/dotfiles/prompt_example.sh
```

`prompt.sh` auto-sources `lib/cache.sh`, `lib/term_utils.sh` and
`lib/colors.sh`, then every built-in segment file in `segments/` (`git.sh`
sources `lib/git_info.sh`), relative to its own
location — keep `lib/` and `segments/` alongside it. The segment files
define and declare the built-in segments; `prompt_example.sh` registers
the ones it shows.
`prompt_example.sh` is a working configuration you edit directly
(register segments, define rows, pick a layout) — it's meant to be
copied and customized, not left as a black box.

## Requirements

- **bash 4.0+** — associative arrays (`declare -A`), used throughout.
- **bash 5.0+ recommended** — `lib/cache.sh` uses
  `EPOCHSECONDS` when available for TTL bookkeeping that can't be
  disrupted by an unrelated `SECONDS=0` elsewhere in the shell. Bash
  4.x still works via a `$SECONDS`-based fallback with its own (weaker)
  defense against that specific case — see the [version history](#version-history).
- **Linux** — this targets Linux. It has not been tested on BSD/macOS.
- **Runtime dependencies** (all optional except `git`; every segment
  that needs one degrades to silent/empty if it's missing): `git`,
  `tmux`, `nvidia-smi`, `df`, `nproc`, `mktemp`, `tput`, `date`, `awk`,
  `sort`, `cut`, `tr`, `timeout`. None of these are external to a
  typical Linux install except `nvidia-smi` (GPU nodes only) and `tmux`
  (only if you use it).

## Segment reference

All segments are silent (empty output, zero visual footprint) when
not applicable — an `@venv` segment outside a virtualenv costs one
cheap function call, not a blank space.

| Segment | Shows | Silent when |
|---|---|---|
| `_ps_seg_user` / `_ps_seg_host` / `_ps_seg_user_host` | `user@host` | never |
| `_ps_seg_root` | `⚡` privileged-shell indicator | not running as root |
| `_ps_seg_pwd` | Working directory, `$HOME`→`~`, truncated past 35 visible chars | never |
| `_ps_seg_git_branch` | Branch name, or short SHA if detached | outside a git repo |
| `_ps_seg_git_remote` | Upstream tracking branch | no upstream configured |
| `_ps_seg_git_ahead_behind` | `↑N ↓N` | no divergence from upstream |
| `_ps_seg_git_status` | `+staged ~modified ?untracked` | working tree is clean |
| `_ps_seg_git_stash` | `⚑N` stash count | no stashes |
| `_ps_seg_git_conflicts` | `⚠N` unmerged paths | no active conflict |
| `_ps_seg_git_full_state` | `(+N ~N ?N ⚑N ⚠N)`, the nonzero ones; `(✓)` when all are zero | outside a git repo |
| `_ps_seg_git_sha` | Short SHA of HEAD | before the first commit |
| `_ps_seg_git_remote_sha` | Short SHA of the upstream branch | no upstream configured |
| `_ps_seg_tmux` | `⧉ session:win.pane` | not inside tmux, or the server does not answer |
| `_ps_seg_display` | `$DISPLAY` value | unset |
| `_ps_seg_ssh` | `⇄ ssh` | local session |
| `_ps_seg_venv` | Active virtualenv name | not activated |
| `_ps_seg_conda` | Active conda env (unless `base`) | not activated |
| `_ps_seg_jobs` | `⚙ N` background jobs | none |
| `_ps_seg_exit` | `✓` or `✗ N` | never (always shows last exit state) |
| `_ps_seg_time` | `HH:MM` | never |

| `_ps_seg_shlvl` | `⬇N` nesting depth | top-level shell |
| `_ps_seg_modules` | `⊞N` loaded HPC modules | `$LOADEDMODULES` unset |
| `_ps_seg_load` | `⚖N.NN` 1-min load average | load ≤ core count |
| `_ps_seg_disk` | `⛁N%` filesystem usage | below 90% |
| `_ps_seg_gpu` | `GPU N%` utilization (TTL-cached) | no `nvidia-smi`, or off-GPU node |
| `_ps_seg_pbs_job` / `_ps_seg_pbs_queue` / `_ps_seg_pbs_nodes` | PBS job context | outside a PBS job |
| `_ps_seg_slurm_job` / `_ps_seg_slurm_queue` / `_ps_seg_slurm_nodes` | Slurm job context | outside a Slurm allocation |

## Customization

Write a segment, register it, reference it in a row:

```bash
_my_seg() { printf '%s' "some text"; }   # use $PS_* vars for color
prompt_segment myname _my_seg
prompt_row myrow '@myname  @pwd'
prompt_layout --box rounded myrow
```

**The one rule for segment authors: a segment formats, it does not
collect.** Segments run inside a command substitution — a subshell — so
any variable a segment sets, including any caching bookkeeping, is
discarded the moment it returns. A segment that caches its own data
silently re-does the expensive work on every keystroke.

```bash
# WRONG — cache_touch runs in a subshell; the TTL never takes effect,
# and `expensive_thing` runs on every single render with no error shown.
_my_thing() {
    if cache_stale mything 10; then
        MY_VALUE=$(expensive_thing)
        cache_touch mything
    fi
    printf '%s' "$MY_VALUE"
}

# RIGHT — collect in a collector, format in the segment.
_my_collect() { MY_VALUE=$(expensive_thing); }
_my_thing()   { [[ -n "$MY_VALUE" ]] && printf '%s' "$MY_VALUE"; }
prompt_collector mything 10 _my_collect   # at most once per 10 seconds
prompt_segment_needs _my_thing mything
prompt_segment mything _my_thing
```

A collector runs in `prompt_build`, in the shell's own process, and only
while a row in the active layout uses a segment that needs it. TTL `0`
runs it every prompt; the TTL bookkeeping is done for you.

If the data you need is one the toolkit already collects, declare the
dependency and read the globals — no collector of your own needed:

```bash
_my_branch() { printf '⎇ %s' "$GIT_BRANCH"; }
prompt_segment_needs _my_branch git
prompt_segment mybranch _my_branch
```

Built-in collectors: `git`, `load`, `disk`, `gpu`.
`prompt_segment_needs` may come before or after `prompt_segment`, but the
collector must already be registered. Skipping this step means the
collector never runs for that segment and it renders blank forever.

**Tuning:**

```bash
prompt_cache_ttl 5             # seconds before forcing a git refresh (default 5)
```

**Row templates** use single quotes so `\$` survives as the literal
bash prompt-escape sequence (rendered as `$`, or `#` for root) rather
than being shell-expanded at registration time. Tokens have no end
delimiter — avoid a segment name that's a literal prefix of adjacent
template text.

**Segment output is shown as typed.** `_ps_expand` escapes `\`, `$` and
backtick in what a segment prints, so a directory or branch name cannot
run code or act as a prompt escape. A segment that wants a prompt escape
(`\u`, `\$`) cannot print one; put it in the row template instead.

**Box styles:** `rounded` (╭╮╰╯), `sharp` (┌┐└┘), `double` (╔╗╚╝),
`ascii` (++++) — pass as `prompt_layout --box <style> ...`. The word after
`--box` is taken as the style only when it names one of these, so
`prompt_layout --box top cmd` is a rounded box with rows `top` and `cmd`.

**Box edges:** `--box` draws the top, right and left edges; `--closed`
adds the bottom one. `--sides SPEC` draws only the edges named, any of
`t`, `r`, `b` and `l`, commas optional, and turns the box on by itself
(`--box <style>` still picks the style). With `COLUMNS=10` and rows
`X`, `X`, `X \$ `:

```
--sides l          --sides l,b        --sides t,l
╭X                 ╭X                 ╭X────────
│X                 │X                 │X
╰X $               ╰X $ ────          ╰X $
                   $
```

A rail ends in its corners (`╭`/`╰`, `╮`/`╯`) whatever else is drawn,
and takes one column. A row is filled out only where an edge needs it:
the first row with `─` under `t`, the last row with `─` under `b` (which
also puts the cursor on its own line below), the rows between with
spaces under `r`. A left rail alone leaves no trailing spaces. An
unknown letter prints `prompt_layout: --sides 'SPEC': use the letters
t, r, b and l` and returns 1, leaving the layout as it was.

## Configuration and API reference

All configuration happens by calling these functions from a config file
sourced after `prompt.sh` (see `prompt_example.sh`). There are no
command-line arguments to the library itself; `install.sh` is the only
executable, and takes one optional positional argument.

### Public functions

| Function | Arguments | Purpose |
|---|---|---|
| `prompt_segment` | `<name> <function>` | Register `<function>` as the `@name` token usable in row templates. |
| `prompt_collector` | `<name> <ttl_seconds> <function>` | Register a data collector. `prompt_build` runs it in the shell's own process while a shown row needs it: every prompt at TTL `0`, at most once per TTL seconds otherwise. Re-registering a name replaces its TTL and function and keeps its place in the run order. Returns 1 on a name that is not an identifier, a TTL that is not a whole number, or an undefined function. |
| `prompt_segment_needs` | `<function> <collector>…` | Declare the collectors a segment function reads from (`git`, `load`, `disk`, `gpu`, or your own). Order relative to `prompt_segment` does not matter; the collectors must already be registered. Built-in segments are pre-declared. |
| `prompt_row` | `<name> <template>` | Define a named row template: literal text, `@segment` tokens, and at most one `@fill`. A row whose segments all print nothing is left out of the prompt, unless it is the last row. |
| `prompt_layout` | `[--box [style]] [--sides SPEC] [--closed] [--no-box] <row>…` | Set the ordered row list and box decoration, and wire `prompt_build` into `PROMPT_COMMAND`. Idempotent. `--sides` draws only the edges in SPEC (`t`, `r`, `b`, `l`); returns 1 on any other letter. |
| `prompt_build` | none | Rebuild `PS1`. Called automatically via `PROMPT_COMMAND`; rarely called directly. |
| `prompt_debug` | none | Print the layout, rows, segments with their needs, and each collector's TTL, whether a shown row needs it, and its age, to stderr. |
| `prompt_cache_ttl` | `<seconds>` | Set the git-state staleness window (default 5). |


### Library functions (usable standalone)

| Function | Arguments | Purpose |
|---|---|---|
| `strip_ansi` | `[-v VAR] <string>` | Remove ANSI escapes and readline `\001..\002` markers. |
| `str_width` | `[-v VAR] <string>` | Visible column count, locale- and Unicode-safe. |
| `str_repeat` | `[-v VAR] <char> <n>` | Repeat a character `n` times, multi-byte safe. |
| `colors_init` | `[prompt\|raw]` | (Re)initialize `C_*`/`PS_*` color variables in the given mode. |
| `c_fg` / `c_bg` | `<0-255>` | 256-color foreground/background escape, mode-aware. |
| `cache_stale` | `<key> [ttl]` | Whether `<key>` has gone stale (returns 0 if stale). |
| `cache_touch` | `<key>` | Record `<key>` as refreshed now. |
| `cache_age` | `<key>` | Seconds since last touch, or `-1`. |
| `git_info_refresh` | none | Populate the `GIT_*` globals. |
| `git_info_cache_valid` | none | Whether the cached git state is still fresh. |
| `git_info_cache_ttl` | `<seconds>` | Set the git TTL. |


### install.sh

```
./install.sh [target_dir]      # default: ~/.local/share/bash-prompt-toolkit
```

Copies `lib/`, `segments/`, `prompt.sh`, `prompt_example.sh`, and `README.md` to
`target_dir` and prints the two lines to add to `.bashrc`. Refuses to
overwrite an existing target. Warns (does not block) on bash older than
recommended. It does not modify `.bashrc` — shell startup files are left
under the user's own control.

## Assumptions and limitations

**Assumptions:**

- Linux. Untested on BSD/macOS.
- A UTF-8-capable terminal for the default box-drawing characters. The
  `ascii` box style exists for terminals that can't render them.
- One prompt configuration per shell. Sourcing two configs that both
  call `prompt_layout` means the last one wins.

**Limitations:**

- **Segments must not collect their own cached data.** `_ps_expand`
  invokes each segment via command substitution — a subshell — so any
  variable a segment assigns, including `cache_touch`, is discarded when
  it exits. Collection belongs in `prompt_build`; segments format
  already-collected globals. See [Customization](#customization).
- **Git state is per-process.** Each shell maintains its own cache; ten
  panes in the same repo each run their own `git status` on a cache miss.
  Each shell also leaves one empty timestamp file, `bash-prompt-git.*`,
  in `$XDG_RUNTIME_DIR` (else `$TMPDIR` or `/tmp`).
- **The git cache reads loose refs.** A packed branch ref reads as empty
  until the next commit writes it loose again; under git's reftable
  backend no ref is loose, and only the index and the TTL catch a change.

- **Disk usage uses `df`, not real quotas.** Quota semantics vary too
  much across NFS/Lustre/GPFS to handle generically.

- **Row templates have no token end-delimiter.** Avoid a segment name
  that is a literal prefix of adjacent template text.

## Future work

- Build real line/branch coverage into the test workflow (needs `kcov`;
  see [Testing](#testing)).
- Optional shared cross-shell git cache, so panes in the same repo don't
  each pay their own cache miss.
- Verify or explicitly drop BSD/macOS support — currently untested.
- A `prompt_layout --preview` mode to render a layout once without
  installing it into `PROMPT_COMMAND`, for faster iteration.
## Environment variables

| Variable | Effect |
|---|---|
| `NO_COLOR` | Disables all color output (both raw and prompt mode) — [no-color.org](https://no-color.org) convention |

| `PS_DEBUG_SEGMENTS` | Set to `1` to surface a failing segment's stderr and a `segment "<name>" exited <code>` message instead of silently rendering it as empty. Off by default — one broken custom segment still can't take down the whole prompt. |

Raw-mode color also auto-disables when stdout isn't a terminal (e.g.
piped to a log file) — no environment variable needed for that case.

## Architecture

```
Segment → Row → Layout → PS1
```

- **Segment** — a function that writes one piece of prompt content to
  stdout (branch name, exit code, working directory, …). Segments know
  nothing about layout; they use `C_*`/`PS_*` color variables and stay
  silent (empty output) when not applicable.
- **Row** — a named template string referencing segments by `@name`
  token, plus an optional `@fill` token that pads to the row's width.
  When every segment a row names prints nothing, the row is left out
  rather than drawn as a blank line, and a box closes around the rows
  that remain; a row with no segments, and the last row, are always
  drawn.
- **Layout** — an ordered list of rows, optionally wrapped in a Unicode
  box (`--box <style>`), open or `--closed`, or in only some of its
  edges (`--sides l,b`).
- **Collector** — a function that gathers data for segments into globals
  (git state, load, disk, GPU), registered with a TTL.
  Segments declare which collectors they read with
  `prompt_segment_needs`.

`prompt.sh` is the engine only. The built-in segments live in
`segments/`, one file per topic, each holding its segment functions,
its collectors and their needs declarations.

```
╭─[ chris@devbox ]────────────────────────────────[ ~/projects/myapp ]─╮
│  ⬇2  ⇄ ssh  ⧉ proj:2.1  :0  (py311)  ⚙ 2                              │
│  ⎇  feature/auth  →  origin/feature/auth  ↑3 ↓1                       │
│     +2 ~5 ?3  ⚑1                                                       │
╰─[✓] $
```
(see [What it looks like](#what-it-looks-like) for a field-by-field
breakdown of that render)

### Where data collection happens

`prompt_build` runs in the shell's own process. It runs the collectors
the active layout needs — those declared by a segment some shown row
uses — in registration order, honoring each one's TTL, and only then
expands the rows. Which collectors are needed is worked out again only
after a segment, row, layout, collector or needs declaration changes, so
the per-prompt planning cost is one integer test.

Row expansion invokes each segment as `val=$(segfunc)`, which is a
**subshell**. That's the single most important fact about this
architecture:

- Anything a segment *assigns* — a variable, a `cache_touch` — is
  discarded when that subshell exits. The parent never sees it.
- So a segment that tries to cache its own data will re-do the expensive
  work on every render, forever, with no error to indicate it.

Hence the rule enforced throughout: **collect in `prompt_build`, format
in the segment.** Built-in segments declare their collectors in their own
`segments/` file; custom ones do the same with `prompt_collector` and
`prompt_segment_needs`.

Git state is cached per-process (`git_info.sh`). A cache hit starts no
process: it reads `HEAD`, the branch's ref and the upstream's ref with
the `read` builtin, compares the index against a timestamp file with
`-nt`, and checks the TTL. A `cd` within the same work tree keeps the
cache.

## Project structure

| File | Purpose |
|---|---|
| `lib/colors.sh` | `C_*`/`PS_*` ANSI color variables; raw mode (scripts) and readline-safe `\001..\002`-wrapped prompt mode |
| `lib/term_utils.sh` | `strip_ansi`, `str_width` (locale-safe code-point count), `str_repeat` — fork-free, and with `-v VAR` free of a subshell too |
| `lib/cache.sh` | Generic TTL bookkeeping (`cache_stale`/`cache_touch`/`cache_age`) — shared by `git_info.sh` and the collector TTLs (key `collector:<name>`) |
| `lib/git_info.sh` | Cached git branch/SHA/status/ahead-behind/conflicts/stash state |

| `prompt.sh` | The segment/row/layout/collector engine itself; sources `segments/` at the end |
| `segments/identity.sh` | User, host, user@host, root marker, working directory |
| `segments/command.sh` | Exit status, clock |
| `segments/git.sh` | Branch, upstream, SHAs, ahead/behind, working tree, stash, conflicts; the `git` collector |
| `segments/shell.sh` | tmux, display, ssh, venv, conda, jobs, shell level |
| `segments/system.sh` | Load, disk, GPU and their collectors |
| `segments/hpc.sh` | Environment modules, PBS and Slurm jobs |
| `prompt_example.sh` | Working configuration — segments registered, rows defined, one active layout |
| `tests/` | Bats test suite — 9 `.bats` files plus `test_helper.bash` (see [Testing](#testing)) |
| `install.sh` | Copies the toolkit to a target directory and prints the `.bashrc` lines to add — see [Installation](#installation) |

## Testing

```bash
bats tests/                    # requires bats-core; apt install bats
shellcheck lib/*.sh prompt.sh segments/*.sh prompt_example.sh install.sh
```

**162 tests across 9 files**, all passing against v0.1.14:

| File | Tests | Covers |
|---|---|---|
| `cache.bats` | 5 | stale and fresh keys, TTL elapsing, `cache_age`, a clock set back |

| `collectors.bats` | 27 | collector planning by layout, built-in segments under other names, declared needs, TTLs, run order, argument checks, collected data reaching the parent shell, `install.sh` copying `segments/` |
| `colors.bats` | 12 | raw/prompt modes, `NO_COLOR`, tty detection, `PS_*` mirrors, helper name |
| `git_info.bats` | 28 | counts, conflicts, detached HEAD, ahead/behind, stash, SHAs, index left alone; cache: no process on a hit, `cd` within a work tree, nested repo, worktree, checkout, commit, fetch, add, TTL with `git_info.sh` sourced on its own |
| `nounset.bats` | 6 | `set -u` safety across all modules |
| `prompt_box.bats` | 27 | open/closed boxes, single- and multi-row, `@fill`, layout idempotence, `--box` style parsing, rows left out when their segments print nothing, each `--sides` edge and its errors |
| `prompt_segments.bats` | 33 | pwd and tmux sanitizing with no program on `PATH`, tmux silent outside tmux or with no server, venv name, pwd truncation, `~` at a path boundary, module counting, exit, conflict and full-state segments, disk usage and a hung `df`, PBS node count; registration, `_ps_expand` token scanning, `PS_DEBUG_SEGMENTS` |
| `security.bats` | 8 | segment text shown as typed (`$(...)`, backticks, `\w`, `@fill`, `$` for root), `promptvars` left on for `PS0`, `CDPATH` |
| `term_utils.bats` | 16 | ANSI stripping, width (with no UTF-8 locale), repeat (multi-byte, `&`, count 0 or below), no `sed` or `awk` forked, `-v VAR` (any name; count 0 empties it) |

`tests/test_helper.bash` provides `$DOTFILES_ROOT`, `load_prompt_lib`,
`make_git_repo`, and `plain`.

Tests carrying `[SECURITY]` or `[nounset]` labels document
previously-open vulnerabilities and gaps that are now **fixed** — they
pass today and exist to catch a regression, not to signal pending work.

### Coverage

`kcov` isn't in this sandbox's apt repositories and wasn't built from
source for this pass — building it needs `cmake` plus several dev
libraries, which felt like too much for a supporting metric on top of
everything else in this round. If it's available in your environment:

```bash
kcov --include-path=lib,prompt.sh,prompt_example.sh coverage/ bats tests/
```

In its place, an executed (not aspirational) function-level audit —
which functions in `lib/*.sh`, `prompt.sh` and `segments/*.sh` are
referenced by name anywhere in `tests/`:

**37 / 67 functions (55%)** referenced by at least one test (v0.1.5).
The uncovered half is almost entirely trivial single-line environment-
variable formatters (`_ps_seg_host`, `_ps_seg_ssh`, `_ps_seg_time`,
the Slurm segments) plus the built-in `_ps_collect_*` functions, which
are exercised through `prompt_build` but not called by name.

This is a real measured number, not an estimate — but function-name
reference is a weaker signal than line or branch execution. Treat it
as a floor, and use `kcov` above for real numbers.

## Known issues

No code-level issues currently open — everything found in the v0.1.1,
v0.1.2, and v0.1.3 production-readiness audits is fixed, each captured
as a permanent regression test in `tests/`.

One measurement gap remains open:

- **Coverage is a function-name audit, not real line/branch coverage.**
  `kcov` wasn't available in the environment this was assembled in. See
  [Coverage](#coverage) for the command to run and
  [Future work](#future-work).

## Version history

### v0.1.14

**Removed:** `@cmd_time`, its `cmd_time` collector,
`prompt_cmd_time_threshold`, `lib/cmd_timer.sh` (`cmd_timer_install`,
`cmd_timer_arm`, `cmd_timer_elapsed`) and the `CMD_TIMER_SKIP_TRAP` and
`PS_SKIP_DEBUG_TRAP` variables. The duration was wrong: the timer was
armed inside `prompt_build`, so the DEBUG trap recorded the start at the
next command of `PROMPT_COMMAND`, and a duration included the time spent
at the prompt (`true` after 4 s idle showed `4s`). The toolkit no longer
claims the `DEBUG` trap. `tests/cmd_timer.bats` (8 tests) went with it.

### v0.1.13

**Changed:** `@pwd`, `@tmux` and `@venv` fork nothing but `tmux`
itself; a prompt at the top of a git repository takes 13.5 ms where it
took 22, 16 where it took 28 inside tmux (with a stub `tmux`).
`strip_ansi`, `str_width` and `str_repeat` take `-v VAR` to assign the
result, as `printf -v` does, in place of a `$(...)` subshell; `prompt.sh`
and the segments pass it. Control bytes in a directory or tmux session
name are deleted in bash under `LC_ALL=C`, where `tr -d` did, and
`@venv` takes the last path component with an expansion, not
`basename`.

**Added:** `_ps_tmux_into VAR`, the `@tmux` text into VAR; it fails
outside tmux or when the server does not answer, so a layout can space
the pane only when there is one. Six tests in `term_utils.bats` and
`prompt_segments.bats`.

### v0.1.12

**Added:** `_ps_seg_git_full_state`, the working tree's state in one
segment: `(+N ~N ?N ⚑N ⚠N)` with only the nonzero counts, or `(✓)` when
all five are zero; silent outside a repository. Registered as
`@git_full_state` in `prompt_example.sh`. Three tests in
`prompt_segments.bats`.

### v0.1.11

**Fixed:** the `@disk` collector runs `df` under `timeout 1`, as `@gpu`
runs `nvidia-smi`. `statfs` on a hung NFS mount, or a loaded Lustre or
GPFS one, could block `df`, and every prompt with it. Two tests in
`prompt_segments.bats`.

### v0.1.10

**Added:** `prompt_layout --sides SPEC` draws only some edges of the
box: any of `t`, `r`, `b` and `l`, so a left rail alone (`l`) or a left
rail and a bottom line (`l,b`). `--box` is `--sides t,r,l` and
`--closed` adds `b`; both draw what they drew before. The width a row
gets is the terminal's less one column per side rail, so a left rail
alone gives rows one more column than `--box`. `prompt_debug` prints
`sides=` in place of `closed=`. 12 tests in `prompt_box.bats`.

### v0.1.9

**Changed:**

- **A git cache hit starts no process.** It ran `stat` twice (about
  6 ms a prompt); it now reads `HEAD` and the branch's and upstream's
  loose refs with `read` and compares the index against a per-shell
  timestamp file with `-nt` (about 0.3 ms). GNU `stat` is no longer
  needed.
- **The cache catches more.** A commit or `reset --soft` that leaves the
  index alone, and a fetch that moves the upstream, now refresh at once
  instead of after the TTL. The old check watched the mtime of `HEAD`,
  which a commit does not change.
- **A `cd` within the same work tree keeps the cache.** It is keyed on
  the work tree, found by walking up to the nearest `.git`, instead of
  `$PWD`; a nested repository, a submodule or a linked worktree is
  another work tree.

**Added:** `GIT_SHA` and `GIT_REMOTE_SHA` globals and the `@git_sha` and
`@git_remote_sha` segments, filled in the same refresh as the rest; 14
tests in `git_info.bats`.

### v0.1.8

**Changed:**

- **A row whose segments all print nothing is left out.** It used to be
  drawn as a blank line, or as its literal text alone (`⎇  →` outside a
  git repository). The box corners go on the first and last rows that
  remain. A row with no segments is kept, and so is the last row, which
  holds the prompt character. `prompt_build` now expands each row once
  with `_ps_expand_into`, in its own process, so a prompt forks once
  less per row.

**Added:** six tests in `prompt_box.bats`.

### v0.1.7

**Fixed:**

- **`@fill` printed by a segment was taken for the spacer.** A directory
  or branch named `@fill` moved the fill into the name and made the row
  about 70 columns too wide. The spacer placeholder is now a `\x1f` byte,
  deleted from segment output first.
- **The prompt's `git status` rewrote the index.** It took `index.lock`
  while refreshing stat data, so a `git add` or `git commit` in another
  shell could fail. It now runs with `GIT_OPTIONAL_LOCKS=0`.
- **`prompt_layout --box ROW ...` took the row name as the box style.**
  The next word is the style only when it names one.
- **`@pwd` truncation cut UTF-8 characters in half.** `cut -c` counts
  bytes, not characters; truncation now drops whole characters in bash.
- **`str_width` needed the `C.UTF-8` locale.** Without it (RHEL/CentOS 7)
  every `─` counted as 3 and `@fill` rows came out short. It now counts
  UTF-8 lead bytes in pure bash, with no `wc` fork.
- **`@pwd` turned `/home/a2` into `~2`** for `HOME=/home/a`; `~` now
  replaces `$HOME` only at a path boundary.
- `colors_init` no longer deletes a user function named `_e` (its helper
  is `_colors_e`).
- Sourcing `prompt.sh` by a relative path with a matching `CDPATH` entry
  no longer breaks every `source` (`CDPATH='' cd --`).

**Added:** eight tests, one per fix above.

### v0.1.6

**Fixed:**

- **`promptvars` is left on.** v0.1.1 turned it off for the whole shell,
  which broke every other user of the option: kitty's shell integration
  puts `$(...)` in `PS0`, and printed it literally before every command.
  `_ps_expand` now escapes each segment's output instead (`\` becomes
  `\\\\`, `$` and backtick get `\\` before them), so the text reaches the
  screen as typed and nothing in it runs.
- **Backslashes in segment output were prompt escapes.** Bash decodes
  `\w`, `\[`, `\n` and `\D{...}` in `PS1` whether or not `promptvars` is
  on, so a directory named `a\wb` showed the full working directory and
  overflowed the box. The same escaping closes it, for custom segments
  too.
- A row without `@fill` is padded by the width of the text as shown, not
  as escaped.

**Added:** three `security.bats` tests (backslash and substitution text,
`$` for root, padding); the `promptvars`-off test now checks that a `PS0`
holding `$(...)` expands.

### v0.1.5

**Changed:**

- **Built-in segments moved out of `prompt.sh` into `segments/`**, one
  file per topic (`identity`, `command`, `git`, `shell`, `system`,
  `hpc`), each holding its segment functions, its collectors and their
  needs declarations. `prompt.sh` is now the engine only (729 to 526
  lines) and sources the six files at the end. `install.sh` copies
  `segments/`; a manual install must too.
- **Data collection is a registry of collectors**, replacing the fixed
  `git`/`gpu`/`disk`/`load` refresh flags. `prompt_collector <name>
  <ttl> <function>` registers one; `prompt_segment_needs` now takes any
  registered collector name (and `cmd_time`), may be called before or
  after `prompt_segment`, and reports `unknown collector "<name>"` with
  the registered list. Custom segments can now have collected, TTL-gated
  data without hand-written `cache_stale`/`cache_touch` bookkeeping.
- **Collectors run only for what the layout shows.** Previously a
  collector armed as soon as a segment needing it was registered, shown
  or not; `prompt_example.sh` registers every built-in segment, so git,
  load, disk and GPU were collected on every prompt even when no row
  displayed them. Now only segments used by a row in the active layout
  count. The plan is rebuilt only after a registration changes.
- **The `DEBUG` trap is claimed at the first prompt that shows a
  segment needing `cmd_time`**, via the new `cmd_timer_install`, not
  when `lib/cmd_timer.sh` is sourced. A layout without `@cmd_time` never
  takes the trap. `CMD_TIMER_SKIP_TRAP` may now be set any time before
  the first prompt; `PS_SKIP_DEBUG_TRAP` still has to be set before
  sourcing `prompt.sh`.
- `prompt_debug` prints each segment's needs and each collector's TTL,
  whether a shown row needs it, and its age.
- GPU, load and disk TTL bookkeeping uses cache keys
  `collector:<name>` (was `gpu` and friends).

**Removed:** `_ps_refresh_load`, `_ps_refresh_disk`, `_ps_refresh_gpu`
and the `_PS_HAS_*` flags (internal; replaced by `_ps_collect_*` and the
registry).

**Fixed:**

- `install.sh` was committed without its executable bit, so the
  documented `./install.sh` failed with "Permission denied".
- `lib/cmd_timer.sh`'s header claimed it chains onto an existing `DEBUG`
  trap; it replaces it, as it has since v0.1.1.
- `prompt.sh`'s setup comment named `prompt.example.sh` under
  `~/dotfiles`; it is `prompt_example.sh` under the install directory.

**Added:** `tests/collectors.bats` (28 tests); the v0.1.4 refresh-gating
tests now check the collector plan instead of the removed flags. The
`pbs_nodes` declaration check reads `segments/hpc.sh` and fails if the
function is not found, rather than passing against a file that no longer
holds it.

### v0.1.4

**Fixed:**

- **Refresh gating was keyed on the segment's registered NAME, not its
  function**, so any alias silently broke it. `prompt_segment gpu_util
  _ps_seg_gpu` or `prompt_segment branch _ps_seg_git_branch` left the
  corresponding refresh disarmed, and the segment rendered blank
  forever with no error — the worst failure mode, in exactly the
  situation the row-template system invites. Dependencies are now
  declared per-function in `_PS_SEG_NEEDS`, so a built-in segment works
  under any name.
- **`_ps_seg_pbs_nodes` mis-declared its locals.** `local -A seen=()
  line n=0` applies `-A` to all three names, making `line` and `n`
  associative arrays. It produced correct output only because bash
  routes the bare read and increment through index `[0]` — accident,
  not rule. Each variable is now declared with its intended type.
- Corrected the README's test claims, which cited a suite size and file
  count the package did not contain.

**Added:**

- `prompt_segment_needs <function> <git|gpu|disk|load>` — lets a custom
  segment declare a dependency on collected data, the supported
  replacement for the name-matching that used to be inferred.
- `tests/test_helper.bash` — the seven original `.bats` files all
  `load test_helper`, which was missing from the tree, so none of them
  could run. Provides `$DOTFILES_ROOT`, `load_prompt_lib`,
  `make_git_repo`, and `plain`, plus the `CMD_TIMER_SKIP_TRAP=1` opt-out
  that keeps the toolkit's `DEBUG` trap from colliding with bats-core's.
  Reconciled against the original: the trap opt-out moved to file scope
  (several `.bats` files source `prompt.sh` directly without going
  through `load_prompt_lib`, and would otherwise claim the trap);
  `make_git_repo` now pins the default branch and disables commit
  signing, so a global `commit.gpgsign=true` can't break the suite; and
  `plain` no longer delegates to the library's own `strip_ansi`, since a
  helper built on the code under test can mask a regression in exactly
  that function. Both versions pass all 92 tests against v0.1.4.
- Six regression tests for the two fixes above.

**Changed:**

- README restructured user-facing-first, opening with a rendered prompt
  mockup and a field-by-field table for every row. Added
  [Configuration and API reference](#configuration-and-api-reference),
  [Assumptions and limitations](#assumptions-and-limitations), and
  [Future work](#future-work); renamed "File layout" to
  "Project structure" and "Changelog" to "Version history".
- The segment-authoring contract — collect in `prompt_build`, format in
  the segment — is now documented in
  [Customization](#customization) with correct and incorrect examples,
  and in [Architecture](#architecture). It previously appeared only
  inside a changelog bug narrative, despite being the rule whose
  violation caused the v0.1.3 GPU cache bug.
- Every function in `lib/*.sh` and `prompt.sh` now carries a brief
  descriptive comment (21 were missing, including `prompt_segment`).
- Obsolete `[FAIL pending fix]` and "EXPECTED TO FAIL" labels removed
  from `security.bats` and `nounset.bats` — those fixes landed in
  v0.1.1 and the tests have been passing since.

### v0.1.3

**Fixed — all found during a production-readiness review, each with a
permanent regression test in `tests/`:**

- **[CRITICAL] The `@gpu` segment's TTL cache never worked — verified
  via a mocked `nvidia-smi`, every render re-forked it regardless of
  the 10s TTL.** Root cause: `_ps_seg_gpu` ran the actual collection
  and called `cache_touch` from *inside itself* — but `_ps_expand`
  invokes every segment as `val=$(segfunc)`, a command-substitution
  subshell. Any variable a segment assigns is discarded the instant
  that subshell exits, so the cache state never reached the parent
  shell. This generalizes past the one segment it was found in: **data
  collection now happens in `prompt_build` (the parent shell); `_seg_*`
  functions only format already-collected globals** — the same
  separation the git segments always had, by construction. Applied
  consistently to `@disk` and `@load` too, which had the identical
  latent bug (unverified until this pass, since neither had been
  checked the way `@gpu` was).
- **[CRITICAL] `str_repeat '&' N` silently produced spaces instead of
  ampersands** — a regression from v0.1.2's fork-free rewrite. `&` is
  special in bash's `${var//pat/repl}` replacement text (it means "the
  matched text"); the old awk-based version didn't have this quirk.
  Fixed by escaping the replacement character first. Caught because a
  broader input sweep was run against the fork-free rewrite this time,
  not just the handful of characters exercised in v0.1.2's tests.
- **[CRITICAL] `PS_DEBUG_SEGMENTS` changed rendered output, not just
  diagnostic visibility.** A segment that printed partial output before
  failing rendered that partial text in debug mode and correctly
  rendered nothing in normal mode — the debug branch was missing the
  `|| val=""` fallback the normal branch already had. A diagnostic flag
  must be observation-only; fixed to clear `val` on failure in both
  branches, same as before.
- **[HIGH] `SECONDS=0` — an extremely ordinary "time this operation"
  idiom — silently disabled all TTL caching**, making `cache_stale`
  report "fresh" indefinitely once the clock appeared to run backwards.
  `lib/cache.sh` and `lib/cmd_timer.sh` now prefer `EPOCHSECONDS`
  (bash 5.0+), which no ordinary script has a reason to reassign; the
  `$SECONDS` fallback on older bash now treats a negative elapsed time
  as stale rather than trusting it.
- **[HIGH] `_ps_seg_load` and `_ps_seg_disk` forked `nproc`/`df`/`awk`
  on every render even though they render nothing the vast majority of
  the time** — the fork happened before the "should I show anything"
  check could skip it. `nproc`'s result is invariant for the life of
  the shell and is now read once at source time instead of once per
  render. `df`'s result is now collected the same way `@gpu` is — TTL
  cached (30s) via `prompt_build`, not re-forked every render.
- **[HIGH] Shell startup cost of ~175–215ms** from `prompt_segment`
  re-sorting the entire segment-name list via `awk | sort | cut` on
  *every* registration call — a typical config registering ~30
  segments paid for ~30 re-sorts of a list only the final state of
  which mattered. The sort is now deferred to a lazy rebuild
  (`_ps_resort_segments`), a no-op unless something registered since
  the last render. Verified: startup dropped to ~9ms.
  - *A regression introduced by this exact fix, caught by re-running
    the full test suite rather than trusting the isolated checks*:
    deferring the sort meant `_ps_expand` implicitly depended on
    `prompt_build` having run first — called directly (as several
    tests and the collision-bug regression test do), the segment list
    was empty and nothing expanded. `_ps_expand` now also calls the
    (cheap, idempotent) resort itself, so it's self-sufficient again
    regardless of caller.

**Changed:**
- `_ps_seg_jobs`, `git_info.sh`'s `GIT_STASH` count, and
  `_ps_seg_pbs_nodes` no longer fork `wc`/`tr`/`sort` for line-counting
  and deduplication — replaced with `mapfile` or a plain bash read loop.
  `pbs_nodes` in particular had no TTL cache and PBS_NODEFILE doesn't
  change during a job, so this one forked all three, every render, for
  the entire life of any PBS job.
- `git_info.sh` now gives an immediate, clear error if `lib/cache.sh`
  is missing, instead of a confusing `command not found: cache_stale`
  the next time the git cache is actually checked.
- Fork count per render (default layout, in a git repo, in tmux):
  measured ~29 in v0.1.1, ~25 in v0.1.2, **~13 in v0.1.3**. The
  remainder is almost entirely `tr` (control-byte stripping — a
  security-relevant sanitizer, deliberately not touched) and `wc`
  (`str_width`'s non-ASCII fallback, deliberately left as-is per the
  v0.1.2 changelog's own reasoning — still stands).

**Not changed on purpose, considered and rejected:**
- A fork-free bash-native replacement for `_ps_seg_load`'s remaining
  `awk` float comparison. Prototyping it required parsing a load
  average's fractional digits into bash arithmetic, which hits bash's
  octal-literal gotcha (a fractional part like `"08"` is invalid octal
  and errors `(( ))` outright) unless every value is forced through a
  `10#` base prefix. One awk fork on an already TTL-gated,
  already-guarded path is a better trade than a hand-rolled numeric
  parser with its own footgun, freshly discovered while trying to
  avoid it.

### v0.1.2

**Added:**
- `lib/cache.sh` — generic TTL bookkeeping (`cache_stale`/`cache_touch`/
  `cache_age`). Tracks *when* a key was last refreshed, not the cached
  value itself, so it composes with a caller's own smarter invalidation
  (like `git_info.sh`'s mtime checks) instead of replacing it.
- `lib/cmd_timer.sh` — command-duration tracking split out of `prompt.sh`
  (the `DEBUG`-trap arm/elapsed logic behind `@cmd_time`). Nothing about
  it is prompt-specific; it's a standalone "how long did that take"
  utility now, like `colors.sh`, `term_utils.sh`, and `git_info.sh`
  already were.
- `PS_DEBUG_SEGMENTS` — opt-in diagnostic mode. A failing or misnamed
  segment normally renders as silent empty output (by design — one
  broken custom segment shouldn't take down the whole prompt); this
  surfaces its stderr and exit code instead, for when "why is `@foo`
  blank" needs an answer.

**Fixed:**
- **`_ps_expand` token-collision bug.** Segment expansion worked by
  repeatedly substituting `@name` across the *entire accumulated row
  string*, one registered name at a time. If an earlier segment's own
  output happened to contain literal text shaped like `@othername` — a
  branch called `feature/@venv-fix`, a path, a hostname — a later pass
  could match that accidental text and overwrite it with a completely
  unrelated segment's value, even when that segment was never referenced
  in the row's template. Rewritten as a single left-to-right scan over
  the original template that never revisits already-emitted segment
  output, which closes the whole bug class rather than the one instance
  found. Covered by a permanent regression test that reproduces it
  directly (`tests/prompt_segments.bats`).
- `term_utils.sh`'s `strip_ansi` and `str_repeat` no longer fork
  `sed`/`awk` — rewritten as pure bash (a builtin regex loop, and
  parameter-expansion substitution on a `printf`-padded string).
  Verified to produce byte-identical output to the old implementations
  across representative and edge-case input. One less external-tool
  dependency per colored segment and per padded row, which is a
  robustness property (nothing to be absent, wrong version, or behave
  differently across systems) as much as a speed one.

**Changed:**
- `git_info.sh`'s TTL bookkeeping and the `@gpu` segment's cache now
  both sit on `lib/cache.sh` instead of each independently reinventing
  `$SECONDS`-based TTL tracking. A future cached segment (a live
  Slurm/PBS queue poll, say) gets correct TTL handling by using
  `cache.sh` directly instead of writing a third version of the same
  logic.
- `PS_SKIP_DEBUG_TRAP` is now a compatibility alias: `prompt.sh` forwards
  it to `lib/cmd_timer.sh`'s own `CMD_TIMER_SKIP_TRAP` if the latter
  isn't already set, so existing configs keep working unchanged.

### v0.1.1

**Added:**
- `_ps_seg_root` (`⚡`), `_ps_seg_load` (`⚖`), `_ps_seg_disk` (`⛁`),
  `_ps_seg_gpu` (`GPU N%`, TTL-cached) — wired into the top/env/hpc
  rows in `prompt_example.sh`.

**Fixed (critical):**
- **PS1 command injection via `promptvars`.** Bash re-executes literal
  `$(...)` sitting in `$PS1`'s stored value on every prompt render. A
  directory name, git branch, `$VIRTUAL_ENV` path, `$USER`, or
  `$HOSTNAME` containing `$(...)` reached PS1 unmodified and executed
  repeatedly. Fixed with `shopt -u promptvars` at load time (replaced in
  v0.1.6 by escaping segment output, with `promptvars` left on) — confirmed
  to fully close this with zero effect on `\$`/`\n` prompt-escape
  handling (a separate, always-on bash mechanism).

**Fixed (high):**
- **DEBUG trap coexistence.** The v0.1.0 chaining fix broke bats-core's
  own DEBUG trap (which does call-stack introspection with hardcoded
  frame-depth assumptions). Automatic detection proved unreliable
  across execution contexts more broadly. Replaced with an explicit
  `PS_SKIP_DEBUG_TRAP=1` opt-out; default behavior is unchanged.
- **Function-scoped `declare` bug.** Every top-level `declare` across
  all four files needed `-g` added. Without it, sourcing this toolkit
  from *within* a bash function — exactly what a test-helper wrapper
  does, and a legitimate pattern for a reusable library — silently
  scopes all of prompt.sh's own state as local to that function,
  vanishing the instant it returns.
- **`set -u` (nounset) safety.** Bare references to `$PROMPT_COMMAND`,
  `$USER`, and `$PROMPT_LAST_EXIT` failed under `set -u`. Invisible in
  an interactive `.bashrc`, relevant when sourced as a library into a
  script that uses nounset. The `$USER` fix also closes a real gap
  independent of nounset: it's a plain env var, not bash-guaranteed
  like `$HOSTNAME`, and can be legitimately unset (confirmed in a
  minimal/containerized context).
- `git_info_refresh` returned git's raw internal exit code (128) via a
  bare `return` rather than a clean, predictable status.

**Fixed (lint hygiene, no behavior change):** quoted git's `@{u}`
syntax and made the space-padding `printf '%*s'` call explicit rather
than relying on implicit argument-exhaustion behavior.

### v0.1.0 — first tagged release

Baseline audit and fix pass across all four files.

**Fixed:**
- Git status counters (`GIT_STAGED`/`MODIFIED`/`UNTRACKED`) threw a
  bash arithmetic error on nearly every refresh — `grep -c` exits 1 on
  zero matches, which tripped an `|| echo 0` fallback and left each
  counter holding two lines instead of one.
- Merge conflicts were invisible — unmerged paths (`UU`/`AA`/etc.)
  matched none of the staged/modified/untracked patterns and read as
  a clean working tree. Added `GIT_CONFLICTS` and the `@git_conflicts`
  segment.
- A single-row box (open *or* closed) rendered as a bare top border
  with no prompt escape at all — `i == 0` was checked before
  `is_last`, so a row that's simultaneously first and last always hit
  the "top of a multi-row box" branch.
- `_ps_seg_pwd`/`_ps_seg_tmux` didn't sanitize control bytes or ANSI
  escapes from directory/session names, which can legally contain
  either.
- `_ps_seg_modules` overcounted on a leading, trailing, or doubled
  colon in `$LOADEDMODULES`.
- The DEBUG trap was silently overwritten if another tool had already
  claimed it.
- Redundant `git rev-parse --git-dir` call (ran twice; one discarded).
- Three `grep -c` forks per refresh consolidated into one `awk` pass.
- `colors_init` forked a subshell per color variable (16 total) —
  switched to `printf -v` for direct assignment.
- Added `NO_COLOR` and non-tty support to `colors.sh`.
- Broadened `strip_ansi` to cover cursor-movement and OSC/BEL
  sequences, not just SGR/erase-line — matching its documented scope.
- Tightened `prompt_layout`'s dedup guard from a bare substring match
  to the exact call token.

**Added:** `GIT_CONFLICTS` global and `@git_conflicts` segment;
version tags across all four files.
