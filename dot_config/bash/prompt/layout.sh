#!/usr/bin/env bash
# layout.sh: what the prompt shows, for bash-prompt-toolkit (prompt.sh).
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
# space. Turn a segment's line off to skip even the call.
#
# Each setting has its description in the comment above it. A setting with
# "#" directly in front of it is off: delete that "#" to turn it on, or add
# one to turn a setting off. `dots options WORD` searches every file.
#
# The rows below build each line from the toolkit's segments
# (prompt/toolkit/README.md, "Segment reference"); to show something else,
# call another _ps_seg_* function in a row's function. For a different
# prompt on one machine, call prompt_row and prompt_layout again in
# ~/.bashrc.local.

# ── Custom segments ───────────────────────────────────────────────────────
# The row functions below print the toolkit's segments straight out rather
# than collecting them with $( ): each $( ) forks the shell, one to three
# ms apiece, and every prompt pays it. Whether a separator is needed comes
# from what each segment reads (SHLVL, the job table, DISPLAY, the GIT_*
# globals ...), not from capturing its output.

# user@host:directory, user@host in color; the user in red for root.
_user_host_seg() {
    local uc="$PS_BGREEN"; [[ $EUID == 0 ]] && uc="$PS_BRED"
    printf '%s%s%s@%s%s%s:' "$uc" "$USER" "$PS_R" "$PS_BCYAN" "${HOSTNAME%%.*}" "$PS_R"
    _ps_seg_pwd
}

# ── Segments ──────────────────────────────────────────────────────────────

# @exit: ✓, or ✗ and the exit status of the last command.
prompt_segment exit             _ps_seg_exit



# ── Tuning ────────────────────────────────────────────────────────────────

# Seconds git information is reused before it is read again (default 5).
# Lower is fresher, higher is faster in big repositories.
#prompt_cache_ttl 5

# Seconds a prompt waits for git status. Past that it shows the last state
# read with a … mark, picks the result up at a later prompt, and lists no
# untracked files in that work tree for the rest of the shell. 0 waits
# until git is done.
prompt_git_budget 1



# ── Rows ──────────────────────────────────────────────────────────────────
# Single quotes, so \$ reaches PS1 as the prompt character ($, or # for root).

# top: shell depth and background jobs, a bar, then the root mark and
# user@host:directory.
_top_seg() {
    local s=0 j=0
    (( ${SHLVL:-1} > 1 )) && s=1
    jobs %% >/dev/null 2>&1 && j=1
    printf ' '
    (( s )) && { _ps_seg_shlvl; printf ' '; }
    (( j )) && { _ps_seg_jobs; printf ' '; }
    (( s || j )) && printf '| '
    _ps_seg_root
    _user_host_seg
}
prompt_segment top_seg _top_seg
prompt_row top '@top_seg'

# env: $DISPLAY and the tmux pane, a bar, then the conda environment and the
# virtualenv; left out when all four are empty.
_env_seg() {
    local d=0 t=0 c=0 v=0 sep='' tm
    [[ -n ${DISPLAY-} ]] && d=1
    _ps_tmux_into tm && t=1        # set but unreachable: no pane, no space
    [[ -n ${CONDA_DEFAULT_ENV-} && $CONDA_DEFAULT_ENV != base ]] && c=1
    [[ -n ${VIRTUAL_ENV-} ]] && v=1
    (( d )) && { _ps_seg_display; sep=' '; }
    (( t )) && { printf '%s%s' "$sep" "$tm"; sep=' '; }
    (( (d || t) && (c || v) )) && sep=' | '
    (( c )) && { printf '%s' "$sep"; _ps_seg_conda; sep=' '; }
    (( v )) && { printf '%s' "$sep"; _ps_seg_venv; }
    return 0
}
prompt_segment env_seg _env_seg
prompt_row env ' @env_seg'

# git: ⎇, the working tree's state, the branch and its commit, the upstream
# and its commit, ahead/behind, and … while git status runs past the budget.
# The commit is left out before the first one and on a detached HEAD, where
# the branch already is the commit.
_git_seg() {
    if (( GIT_PENDING )) && ! (( GIT_IN_REPO )); then
        printf '⎇  '; _ps_seg_git_pending
        return 0
    fi
    (( GIT_IN_REPO )) && [[ -n $GIT_BRANCH ]] || return 0
    printf '⎇  '
    _ps_seg_git_full_state
    printf ' %s' "$GIT_BRANCH"
    [[ -n $GIT_SHA && $GIT_SHA != "$GIT_BRANCH" ]] && printf ' (%s)' "$GIT_SHA"
    [[ -n $GIT_REMOTE ]] && printf ' → %s' "$GIT_REMOTE"
    [[ -n $GIT_REMOTE_SHA ]] && printf ' (%s)' "$GIT_REMOTE_SHA"
    [[ -n $GIT_REMOTE ]] && { printf ' ('; _ps_seg_git_ahead_behind; printf ')'; }
    (( GIT_PENDING )) && { printf ' '; _ps_seg_git_pending; }
    return 0
}
prompt_segment git_seg _git_seg
prompt_segment_needs _git_seg git
prompt_row git ' @git_seg'

# cmd: the line you type on, after the last command's result.
prompt_row cmd      ' @exit \$ '

# The rows in order, with a rail down the left side only.
prompt_layout --sides l top git env cmd

# A blank line above each prompt, so one command's output stands apart from
# the next. prompt_build rewrites PS1 at every prompt, so the line is added
# right after it. After Ctrl-L the screen starts with that blank line.
_prompt_gap() { PS1="\n$PS1"; }
[[ "$PROMPT_COMMAND" == *_prompt_gap* ]] || PROMPT_COMMAND="${PROMPT_COMMAND/prompt_build/prompt_build; _prompt_gap}"

