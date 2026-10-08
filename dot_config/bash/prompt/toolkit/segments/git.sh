#!/usr/bin/env bash
# Toolkit version: 0.1.7
# ════════════════════════════════════════════════════════════════════════════
# segments/git.sh — branch, upstream, ahead/behind, working tree, stash,
# conflicts
#
# Sourced by prompt.sh; not usable on its own. Every segment here reads the
# GIT_* globals that lib/git_info.sh fills, so none of them runs git itself.
# The "git" collector refreshes those globals once per prompt, and only
# when a row the layout shows uses one of these segments.
#
# Segments: _ps_seg_git_branch  _ps_seg_git_remote  _ps_seg_git_ahead_behind
#           _ps_seg_git_status  _ps_seg_git_stash   _ps_seg_git_conflicts
# Collector: git (every prompt; git_info.sh's own mtime+TTL check decides
#            whether git actually runs)
# Settings:  prompt_cache_ttl <seconds>
# ════════════════════════════════════════════════════════════════════════════

source "${_PS_ROOT:?segments/git.sh is sourced by prompt.sh}/lib/git_info.sh"

# Collect: refresh the GIT_* globals unless the cached state still holds.
_ps_collect_git() { git_info_cache_valid || git_info_refresh; }
prompt_collector git 0 _ps_collect_git

# Seconds git state is reused before a forced refresh (default 5).
prompt_cache_ttl() { git_info_cache_ttl "$@"; }

# Current branch name, or short SHA when HEAD is detached.
_ps_seg_git_branch() {
    (( GIT_IN_REPO )) || return
    printf '%s' "$GIT_BRANCH"
}

# Upstream tracking branch, silent when the branch has no remote.
_ps_seg_git_remote() {
    (( GIT_IN_REPO )) && [[ -n "$GIT_REMOTE" ]] || return
    printf '%s' "$GIT_REMOTE"
}

# ↑N ahead (green)  ↓N behind (yellow)  ✓ if up to date  — silent if no remote
_ps_seg_git_ahead_behind() {
    (( GIT_IN_REPO )) && [[ -n "$GIT_REMOTE" ]] || return
    if (( GIT_AHEAD == 0 && GIT_BEHIND == 0 )); then
        printf '%s✓%s' "$C_GREEN" "$C_R"
        return
    fi
    local r=""
    (( GIT_AHEAD  > 0 )) && r+="${C_GREEN}↑${GIT_AHEAD}${C_R} "
    (( GIT_BEHIND > 0 )) && r+="${C_YELLOW}↓${GIT_BEHIND}${C_R}"
    printf '%s' "${r% }"
}

# +N staged (green)  ~N modified (yellow)  ?N untracked (dim) — silent if clean
_ps_seg_git_status() {
    (( GIT_IN_REPO )) || return
    local r=""
    (( GIT_STAGED    > 0 )) && r+="${C_GREEN}+${GIT_STAGED}${C_R} "
    (( GIT_MODIFIED  > 0 )) && r+="${C_YELLOW}~${GIT_MODIFIED}${C_R} "
    (( GIT_UNTRACKED > 0 )) && r+="${C_DIM}?${GIT_UNTRACKED}${C_R}"
    [[ -n "$r" ]] && printf '%s' "${r% }"
}

# ⚑N stash count — silent when no stashes or not in a repo
_ps_seg_git_stash() {
    (( GIT_IN_REPO && GIT_STASH > 0 )) || return
    printf '⚑%d' "$GIT_STASH"
}

# ⚠N unmerged/conflicted paths (bold red) — silent when none or not in a repo
_ps_seg_git_conflicts() {
    (( GIT_IN_REPO && GIT_CONFLICTS > 0 )) || return
    printf '%s⚠%d%s' "$C_BRED" "$GIT_CONFLICTS" "$C_R"
}

prompt_segment_needs _ps_seg_git_branch       git
prompt_segment_needs _ps_seg_git_remote       git
prompt_segment_needs _ps_seg_git_ahead_behind git
prompt_segment_needs _ps_seg_git_status       git
prompt_segment_needs _ps_seg_git_stash        git
prompt_segment_needs _ps_seg_git_conflicts    git
