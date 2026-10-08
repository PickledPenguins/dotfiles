#!/usr/bin/env bash
# layout.sh -- what the prompt shows, for bash-prompt-toolkit (prompt.sh).
# Read by rc.d/60-prompt.sh after prompt.sh; this is the file to edit.
#
#   segment  a function that prints one piece of information; registered
#            with prompt_segment NAME FUNC, placed in a row as @NAME
#   row      a template:  prompt_row NAME 'text @segment text @fill text'
#   layout   the rows in order:
#            prompt_layout [--box STYLE] [--sides SPEC] [--closed] ROW...
#
# A segment prints nothing when it does not apply (no git repository, no
# job running), so an unused one costs a function call per prompt and no
# space.  Turn a segment's line off to skip even the call.
#
# Each setting has its description in the comment above it.  A setting with
# "#" directly in front of it is off: delete that "#" to turn it on, or add
# one to turn a setting off.  `dots options WORD` searches every file.
#
# The rows below build each line from the toolkit's segments
# (prompt/toolkit/README.md, "Segment reference"); to show something else,
# call another _ps_seg_* function in a row's function.  For a different
# prompt on one machine, call prompt_row and prompt_layout again in
# ~/.bashrc.local.

# ── Custom segments ───────────────────────────────────────────────────────

# user@host:directory, user@host in color; the user in red for root.
_user_host_seg() {
    local uc="$PS_BGREEN"; [[ $EUID == 0 ]] && uc="$PS_BRED"
    printf '%s%s%s@%s%s%s:%s' "$uc" "$USER" "$PS_R" "$PS_BCYAN" "${HOSTNAME%%.*}" "$PS_R" "$(_ps_seg_pwd)"
}

# ── Segments ──────────────────────────────────────────────────────────────

# @exit: ✓, or ✗ and the exit status of the last command.
prompt_segment exit             _ps_seg_exit

# @cmd_time: how long the last command ran, when 2 s or more, and a space
# after it, so a fast command leaves one space before the $.
_cmd_time_seg() {
    local t=$(_ps_seg_cmd_time)
    [[ -n "$t" ]] && printf '%s ' "$t"
}
prompt_segment cmd_time _cmd_time_seg
prompt_segment_needs _cmd_time_seg cmd_time

# ── Tuning ────────────────────────────────────────────────────────────────

# Seconds git information is reused before it is read again (default 5).
# Lower is fresher, higher is faster in big repositories.
#prompt_cache_ttl 5

# Seconds a command must run before @cmd_time shows it (default 2).
#prompt_cmd_time_threshold 2

# ── Rows ──────────────────────────────────────────────────────────────────
# Single quotes, so \$ reaches PS1 as the prompt character ($, or # for root).

# top: shell depth and background jobs, a bar, then the root mark and
# user@host:directory.
_top_seg() {
    local row=''
    local s=$(_ps_seg_shlvl)
    local j=$(_ps_seg_jobs)
    local r=$(_ps_seg_root)
    [[ -n "$s" ]] && row+="$s "
    [[ -n "$j" ]] && row+="$j "
    [[ -n "$row" ]] && row+="| "
    [[ -n "$r" ]] && row+="$r"
    row+=$(_user_host_seg)
    echo " $row"
}
prompt_segment top_seg _top_seg
prompt_row top '@top_seg'

# env: $DISPLAY and the tmux pane, a bar, then the conda environment and the
# virtualenv; left out when all four are empty.
_env_seg() {
    local row=''
    local tmp=''
    local d=$(_ps_seg_display)
    local t=$(_ps_seg_tmux)
    local c=$(_ps_seg_conda)
    local v=$(_ps_seg_venv)
    [[ -n "$d" ]] && row+="$d "
    [[ -n "$t" ]] && row+="$t "
    [[ -n "$c" ]] && tmp+="$c "
    [[ -n "$v" ]] && tmp+="$v "
    [[ -n "$row" && -n "$tmp" ]] && row+="| "
    row+="$tmp"
    printf '%s' "${row% }"
}
prompt_segment env_seg _env_seg
prompt_row env ' @env_seg'

# git: ⎇, the working tree's state, the branch and its commit, the upstream
# and its commit, ahead/behind.  The commit is left out before the first one and
# on a detached HEAD, where the branch already is the commit.
_git_seg() {
    local row=''
    local b=$(_ps_seg_git_branch)
    if [[ -n "$b" ]]; then
        row+="⎇  "
        local s=$(_ps_seg_git_full_state)
        local sha=$(_ps_seg_git_sha)
        local r=$(_ps_seg_git_remote)
        local rsha=$(_ps_seg_git_remote_sha)
        local ab=$(_ps_seg_git_ahead_behind)
        [[ -n "$s" ]] && row+="$s "
        row+="$b"
        [[ -n "$sha" && "$sha" != "$b" ]] && row+=" ($sha)"
        [[ -n "$r" ]] && row+=" → $r"
        [[ -n "$rsha" ]] && row+=" ($rsha)"
        [[ -n "$ab" ]] && row+=" ($ab)"
    fi
    printf '%s' "$row"
}
prompt_segment git_seg _git_seg
prompt_segment_needs _git_seg git
prompt_row git ' @git_seg'

# cmd: the line you type on, after the last command's result.
prompt_row cmd      ' @exit @cmd_time\$ '

# The rows in order, with a rail down the left side only.
prompt_layout --sides l top git env cmd

