#!/usr/bin/env bash
# layout.sh -- prompt configuration for bash-prompt-toolkit (prompt.sh).
# Sourced by rc.d/60-prompt.sh after prompt.sh.  This is the file to edit.
#
#   segment  a function that prints a piece of text; register with
#            prompt_segment NAME FUNC, reference as @NAME in a row
#   row      a template string:  prompt_row NAME 'text @seg text @fill text'
#   layout   the ordered rows:   prompt_layout [--box STYLE] [--closed] ROW...
#
# Every built-in segment is silent when it does not apply, so an unused
# @token costs one function call per prompt and nothing on screen.
# Comment out any prompt_segment line to skip even that.

# ── Custom segments ───────────────────────────────────────────────────────

# Colored user@host instead of the plain built-in
_my_user_host() {
    printf '%s%s%s@%s%s%s' \
        "$PS_BGREEN" "$USER"           "$PS_R" \
        "$PS_BCYAN"  "${HOSTNAME%%.*}" "$PS_R"
}

# ── Segments ──────────────────────────────────────────────────────────────

prompt_segment user_host        _my_user_host              # colored user@host
prompt_segment root             _ps_seg_root               # ⚡ only in a root shell
prompt_segment pwd              _ps_seg_pwd                # working directory
prompt_segment git_branch       _ps_seg_git_branch         # branch / detached SHA
prompt_segment git_remote       _ps_seg_git_remote         # tracking remote
prompt_segment git_ahead_behind _ps_seg_git_ahead_behind   # ↑N ↓N or ✓
prompt_segment git_status       _ps_seg_git_status         # +staged ~modified ?untracked
prompt_segment git_stash        _ps_seg_git_stash          # ⚑N stash count
prompt_segment git_conflicts    _ps_seg_git_conflicts      # ⚠N unmerged paths
prompt_segment tmux             _ps_seg_tmux               # ⧉ session:win.pane
prompt_segment display          _ps_seg_display            # $DISPLAY
prompt_segment ssh              _ps_seg_ssh                # ⇄ ssh when remote
prompt_segment venv             _ps_seg_venv               # (virtualenv)
prompt_segment conda            _ps_seg_conda              # conda env, not "base"
prompt_segment jobs             _ps_seg_jobs               # ⚙ N background jobs
prompt_segment exit             _ps_seg_exit               # ✓ or ✗ N
prompt_segment time             _ps_seg_time               # HH:MM
prompt_segment cmd_time         _ps_seg_cmd_time           # last command duration (≥2 s)
prompt_segment shlvl            _ps_seg_shlvl              # ⬇N when nested
prompt_segment load             _ps_seg_load               # ⚖N.NN only when busy
prompt_segment disk             _ps_seg_disk               # ⛁N% only when ≥90% full

# HPC -- all silent off-cluster; comment out on a workstation to save the calls
prompt_segment pbs_job          _ps_seg_pbs_job
prompt_segment pbs_queue        _ps_seg_pbs_queue
prompt_segment pbs_nodes        _ps_seg_pbs_nodes
prompt_segment slurm_job        _ps_seg_slurm_job
prompt_segment slurm_queue      _ps_seg_slurm_queue
prompt_segment slurm_nodes      _ps_seg_slurm_nodes
prompt_segment modules          _ps_seg_modules            # ⊞N loaded modules
prompt_segment gpu              _ps_seg_gpu                # GPU N%, TTL-cached

# ── Tuning ────────────────────────────────────────────────────────────────
# prompt_cache_ttl 5              # seconds before a forced git refresh
# prompt_cmd_time_threshold 2     # seconds before @cmd_time appears

# ── Rows ──────────────────────────────────────────────────────────────────
# Single quotes so \$ survives as the PS1 prompt-character escape.

prompt_row top      '─[ @root@user_host ]@fill[ @pwd ]─'
prompt_row env      '  @shlvl  @load  @disk  @ssh  @tmux  @display  @conda  @venv  @jobs'
prompt_row git      '  ⎇  @git_branch  →  @git_remote  @git_ahead_behind'
prompt_row status   '     @git_status  @git_stash  @git_conflicts'
prompt_row hpc      '  @pbs_job  @pbs_queue  @pbs_nodes  @slurm_job  @slurm_queue  @slurm_nodes  @modules  @gpu'
prompt_row cmd      '─[@exit] @cmd_time \$ '
prompt_row footer   '─[@exit]@fill[ @time ]─'

# ── Layout: uncomment exactly one ─────────────────────────────────────────

# A: env header, git below (default)
#   ╭─[ chris@devbox ]────────────────────[ ~/projects/myapp ]─╮
#   │  ⇄ ssh  ⧉ proj:2.1  (py311)                              │
#   │  ⎇  feature/auth  →  origin/feature/auth  ↑3 ↓1          │
#   │     +2 ~5 ?3  ⚑1                                          │
#   ╰─[✓] 5s $
prompt_layout --box rounded  top  env  git  status  cmd

# B: with the HPC row, closed box, cursor on its own line
# prompt_layout --box rounded --closed  top  env  git  status  hpc  footer

# C: minimal, no box
# prompt_row line1  '[ @user_host ] ⎇ @git_branch @git_ahead_behind @pwd'
# prompt_row line2  '[@exit] @cmd_time \$ '
# prompt_layout  line1  line2
