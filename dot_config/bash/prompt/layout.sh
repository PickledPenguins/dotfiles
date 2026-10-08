#!/usr/bin/env bash
# layout.sh -- what the prompt shows, for bash-prompt-toolkit (prompt.sh).
# Read by rc.d/60-prompt.sh after prompt.sh; this is the file to edit.
#
#   segment  a function that prints one piece of information; registered
#            with prompt_segment NAME FUNC, placed in a row as @NAME
#   row      a template:  prompt_row NAME 'text @segment text @fill text'
#   layout   the rows in order:  prompt_layout [--box STYLE] [--closed] ROW...
#
# A segment prints nothing when it does not apply (no git repository, no
# job running), so an unused one costs a function call per prompt and no
# space.  Turn a segment's line off to skip even the call.
#
# Each setting has its description in the comment above it.  A setting with
# "#" directly in front of it is off: delete that "#" to turn it on, or add
# one to turn a setting off.  `dots options WORD` searches every file.
#
# Knobs (set in ~/.bashrc.before):
#   DOTFILES_PROMPT_LAYOUT   box (default), hpc or minimal -- see the bottom

# ── Custom segments ───────────────────────────────────────────────────────

# user@host in color instead of the plain built-in one; the user in red for root.
_my_user_host() {
    local uc="$PS_BGREEN"; [[ $EUID == 0 ]] && uc="$PS_BRED"
    printf '%s%s%s@%s%s%s' "$uc" "$USER" "$PS_R" "$PS_BCYAN" "${HOSTNAME%%.*}" "$PS_R"
}

# ── Segments ──────────────────────────────────────────────────────────────

# @user_host: user@host, colored (the function above).
prompt_segment user_host        _my_user_host

# @root: ⚡ in a root shell only.
prompt_segment root             _ps_seg_root

# @pwd: the working directory, ~ for home.
prompt_segment pwd              _ps_seg_pwd

# @git_branch: the branch, or the commit when detached.
prompt_segment git_branch       _ps_seg_git_branch

# @git_remote: the branch's upstream, such as origin/main.
prompt_segment git_remote       _ps_seg_git_remote

# @git_ahead_behind: ↑N commits to push, ↓N to pull, ✓ when in step.
prompt_segment git_ahead_behind _ps_seg_git_ahead_behind

# @git_status: +N staged, ~N modified, ?N untracked files.
prompt_segment git_status       _ps_seg_git_status

# @git_stash: ⚑N stashed changes.
prompt_segment git_stash        _ps_seg_git_stash

# @git_conflicts: ⚠N files with merge conflicts.
prompt_segment git_conflicts    _ps_seg_git_conflicts

# @tmux: ⧉ session:window.pane inside tmux.
prompt_segment tmux             _ps_seg_tmux

# @display: $DISPLAY, when X forwarding is on.
prompt_segment display          _ps_seg_display

# @ssh: ⇄ ssh when logged in remotely.
prompt_segment ssh              _ps_seg_ssh

# @venv: the active python virtualenv.
prompt_segment venv             _ps_seg_venv

# @conda: the active conda environment, unless it is base.
prompt_segment conda            _ps_seg_conda

# @jobs: ⚙N background jobs.
prompt_segment jobs             _ps_seg_jobs

# @exit: ✓, or ✗ and the exit status of the last command.
prompt_segment exit             _ps_seg_exit

# @time: the time, HH:MM.
prompt_segment time             _ps_seg_time

# @cmd_time: how long the last command ran, when 2 s or more.
prompt_segment cmd_time         _ps_seg_cmd_time

# @shlvl: ⬇N in a shell started from another shell.
prompt_segment shlvl            _ps_seg_shlvl

# @load: ⚖N.NN load average, only when the machine is busy.
prompt_segment load             _ps_seg_load

# @disk: ⛁N% only when the file system here is 90% full or more.
prompt_segment disk             _ps_seg_disk

# ── HPC segments (silent off a cluster; turn off on a workstation) ────────

# @pbs_job: the PBS job this shell runs in.
prompt_segment pbs_job          _ps_seg_pbs_job

# @pbs_queue: the queue of the PBS job this shell runs in.
prompt_segment pbs_queue        _ps_seg_pbs_queue

# @pbs_nodes: nodes of the current PBS job.
prompt_segment pbs_nodes        _ps_seg_pbs_nodes

# @slurm_job: the Slurm job this shell runs in.
prompt_segment slurm_job        _ps_seg_slurm_job

# @slurm_queue: the partition of the Slurm job this shell runs in.
prompt_segment slurm_queue      _ps_seg_slurm_queue

# @slurm_nodes: nodes of the current Slurm job.
prompt_segment slurm_nodes      _ps_seg_slurm_nodes

# @modules: ⊞N loaded environment modules.
prompt_segment modules          _ps_seg_modules

# @gpu: GPU utilization, cached for a few seconds.
prompt_segment gpu              _ps_seg_gpu

# ── Tuning ────────────────────────────────────────────────────────────────

# Seconds git information is reused before it is read again (default 5).
# Lower is fresher, higher is faster in big repositories.
#prompt_cache_ttl 5

# Seconds a command must run before @cmd_time shows it (default 2).
#prompt_cmd_time_threshold 2

# ── Rows ──────────────────────────────────────────────────────────────────
# Single quotes, so \$ reaches PS1 as the prompt character ($, or # for root).

# top: user@host at the left, the directory at the right.
prompt_row top      '─[ @root@user_host ]@fill[ @pwd ]─'

# env: where this shell runs and what is active in it.
prompt_row env      '  @shlvl  @load  @disk  @ssh  @tmux  @display  @conda  @venv  @jobs'

# git: branch, upstream, ahead/behind.
prompt_row git      '  ⎇  @git_branch  →  @git_remote  @git_ahead_behind'

# status: the working tree's changes.
prompt_row status   '     @git_status  @git_stash  @git_conflicts'

# hpc: scheduler jobs, modules, GPU.
prompt_row hpc      '  @pbs_job  @pbs_queue  @pbs_nodes  @slurm_job  @slurm_queue  @slurm_nodes  @modules  @gpu'

# cmd: the line you type on, after the last command's result.
prompt_row cmd      '─[@exit] @cmd_time \$ '

# footer: the last command's result and the time, closing the box.
prompt_row footer   '─[@exit]@fill[ @time ]─'

# line1 and line2: the two rows of the minimal layout.
prompt_row line1    '[ @user_host ] ⎇ @git_branch @git_ahead_behind @pwd'
prompt_row line2    '[@exit] @cmd_time \$ '

# ── Layouts ───────────────────────────────────────────────────────────────

# The layout named by DOTFILES_PROMPT_LAYOUT:
#
# box (default)
#   ╭─[ chris@devbox ]────────────────────[ ~/projects/myapp ]─╮
#   │  ⇄ ssh  ⧉ proj:2.1  (py311)                              │
#   │  ⎇  feature/auth  →  origin/feature/auth  ↑3 ↓1          │
#   │     +2 ~5 ?3  ⚑1                                          │
#   ╰─[✓] 5s $
# hpc: the same box plus the scheduler row, closed, the cursor on its own line
# minimal
#   [ chris@devbox ] ⎇ main ✓ ~/projects/myapp
#   [✓] $
case "${DOTFILES_PROMPT_LAYOUT:-box}" in
    box)     prompt_layout --box rounded  top  env  git  status  cmd ;;
    hpc)     prompt_layout --box rounded --closed  top  env  git  status  hpc  footer ;;
    minimal) prompt_layout  line1  line2 ;;
    *)
        echo "layout.sh: unknown DOTFILES_PROMPT_LAYOUT '$DOTFILES_PROMPT_LAYOUT'" >&2
        prompt_layout --box rounded  top  env  git  status  cmd ;;
esac
