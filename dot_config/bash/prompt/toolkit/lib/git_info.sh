#!/usr/bin/env bash
# Toolkit version: 0.1.10
# ════════════════════════════════════════════════════════════════════════════
# lib/git_info.sh — Cached git repository state for bash scripts
#
# Provides current branch, commit, remote tracking, ahead/behind counts,
# and file-status counts in plain globals.  A cache avoids re-running git
# on every call; a hit starts no process at all — builtin reads and file
# tests only.
#
# Depends on lib/cache.sh (sourced automatically, same directory) for the
# TTL half of cache validity — the ref and index checks below are this
# file's own, since they catch changes cache.sh's flat clock alone would miss.
#
# Usage:
#   source lib/git_info.sh
#   git_info_cache_valid || git_info_refresh
#   echo "$GIT_BRANCH  ↑$GIT_AHEAD ↓$GIT_BEHIND  +$GIT_STAGED ~$GIT_MODIFIED"
#
# Public globals (populated by git_info_refresh):
#   GIT_IN_REPO    — 1 if the current directory is inside a git repo, else 0
#   GIT_BRANCH     — short branch name, or short SHA in detached-HEAD state
#   GIT_SHA        — short SHA of HEAD (empty before the first commit)
#   GIT_REMOTE     — upstream tracking branch (empty if none)
#   GIT_REMOTE_SHA — short SHA of the upstream branch (empty if none)
#   GIT_AHEAD      — commits ahead of remote
#   GIT_BEHIND     — commits behind remote
#   GIT_STAGED     — files with staged changes
#   GIT_MODIFIED   — files with unstaged modifications
#   GIT_UNTRACKED  — untracked files
#   GIT_CONFLICTS  — unmerged/conflicted paths (mid-merge or mid-rebase)
#   GIT_STASH      — stash entries
#
# Public functions:
#   git_info_refresh        — collect all git data
#   git_info_cache_valid    — returns 0 if cached data is still fresh
#   git_info_cache_ttl <N>  — set the worktree-staleness TTL (default 5 s)
#
# Cache invalidation triggers:
#   • cd to a directory in another repo   (a `cd` within the same work tree
#     keeps the cache; a nested repo or submodule is another repo)
#   • .git/HEAD contents changed          (checkout, switch, detach)
#   • the branch's ref contents changed   (commit, reset, merge, rebase)
#   • the upstream's ref contents changed (fetch, pull, push)
#   • .git/index newer than this shell's last refresh (add, reset, rm)
#   • _GIT_CACHE_TTL seconds elapsed      (catches unstaged edits, new files)
#
# Refs are read from their loose files; a packed ref reads as empty until
# the next commit writes it loose again, and the reftable backend keeps no
# loose refs at all — there, only the index and the TTL catch a change.
# The index is compared against a timestamp file this shell writes at each
# refresh, created once per shell with mktemp in $XDG_RUNTIME_DIR (else
# $TMPDIR or /tmp) and left there when the shell exits.  Without one the
# check always fails and every prompt refreshes.
#
# Non-repo directories are cached by PWD alone: once confirmed as non-repo,
# the git rev-parse is skipped on every subsequent prompt in that directory.
# ════════════════════════════════════════════════════════════════════════════

[[ -n "${_GIT_INFO_SH_LOADED-}" ]] && return 0
readonly _GIT_INFO_SH_LOADED=1

_GIT_INFO_DIR="$(CDPATH='' cd -- "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${_GIT_INFO_DIR}/cache.sh"
unset _GIT_INFO_DIR

# [v0.1.3] Fail loudly and immediately if cache.sh didn't load, rather
# than leaving cache_stale/cache_touch undefined and only surfacing that
# as a cryptic "command not found" the next time git_info_cache_valid or
# git_info_refresh actually runs.
if ! declare -F cache_stale >/dev/null; then
    printf 'git_info.sh: lib/cache.sh not found or failed to load — keep it in the same directory as this file\n' >&2
    return 1
fi

# ── Public state ──────────────────────────────────────────────────────────
declare -g    GIT_IN_REPO=0
declare -g    GIT_BRANCH=""   GIT_REMOTE=""
declare -g    GIT_SHA=""      GIT_REMOTE_SHA=""
declare -gi GIT_AHEAD=0     GIT_BEHIND=0
declare -gi GIT_STAGED=0    GIT_MODIFIED=0
declare -gi GIT_UNTRACKED=0 GIT_STASH=0     GIT_CONFLICTS=0

# ── Cache keys (private) ──────────────────────────────────────────────────
declare -g    _GIT_CACHE_DIR=""        # $PWD when cache was last populated
declare -g    _GIT_CACHE_TOP=""        # work tree top level ("" outside one)
declare -g    _GIT_CACHE_GIT_DIR=""    # absolute path to the .git directory
declare -g    _GIT_CACHE_HEAD_REF=""   # the branch's loose ref file ("" if detached)
declare -g    _GIT_CACHE_UP_REF=""     # the upstream's loose ref file ("" if none)
declare -g    _GIT_CACHE_REFS=""       # HEAD|branch ref|upstream ref, as read at refresh
declare -g    _GIT_CACHE_STAMP=""      # timestamp file written at each refresh
declare -g    _GIT_CACHE_STAMP_PID=""  # $BASHPID that created it
declare -g    _GIT_REFS=""             # _git_info_refs' result
declare -gi _GIT_CACHE_TTL=5       # max seconds between forced full refreshes

# Adjust the worktree-staleness window.
git_info_cache_ttl() { _GIT_CACHE_TTL="${1:-5}"; }

# Set _GIT_REFS to the contents of HEAD, the branch's ref and the upstream's
# ref, joined: a checkout changes the first, a commit the second, a fetch
# the third.  Builtin reads only; a missing file reads as empty.
_git_info_refs() {
    local head="" ref="" up=""
    { IFS= read -r head < "$_GIT_CACHE_GIT_DIR/HEAD"; } 2>/dev/null || true
    [[ -z "$_GIT_CACHE_HEAD_REF" ]] || { IFS= read -r ref < "$_GIT_CACHE_HEAD_REF"; } 2>/dev/null || true
    [[ -z "$_GIT_CACHE_UP_REF" ]]   || { IFS= read -r up  < "$_GIT_CACHE_UP_REF"; }   2>/dev/null || true
    _GIT_REFS="$head|$ref|$up"
}

# ── Cache validity ────────────────────────────────────────────────────────

# Returns 0 (cache is fresh) or 1 (must call git_info_refresh).
# Starts no process: builtin reads, file tests and string comparisons.
git_info_cache_valid() {
    # Another directory: still fresh if the nearest .git above it is the
    # cached work tree's.  -ef, so a symlinked path to the same tree counts.
    if [[ "$PWD" != "$_GIT_CACHE_DIR" ]]; then
        (( GIT_IN_REPO )) && [[ -n "$_GIT_CACHE_TOP" ]] || return 1
        local d="$PWD"
        until [[ -e "$d/.git" ]]; do
            [[ -n "$d" ]] || return 1
            d="${d%/*}"
        done
        [[ "${d:-/}" -ef "$_GIT_CACHE_TOP" ]] || return 1
    fi

    # Non-repo: valid as long as the directory hasn't changed
    (( GIT_IN_REPO )) || return 0

    # Verify the .git directory still exists (e.g. repo not deleted under us)
    [[ -d "$_GIT_CACHE_GIT_DIR" ]] || return 1

    # HEAD, branch and upstream refs (checkout, commit, fetch)
    _git_info_refs
    [[ "$_GIT_REFS" == "$_GIT_CACHE_REFS" ]] || return 1

    # Index written since the last refresh (git add, git reset, git rm)
    [[ "$_GIT_CACHE_GIT_DIR/index" -nt "$_GIT_CACHE_STAMP" ]] && return 1

    # TTL: catch unstaged edits and new untracked files
    cache_stale git_info "$_GIT_CACHE_TTL" && return 1

    return 0
}

# ── Refresh ───────────────────────────────────────────────────────────────

# Collect all git state in one pass.  Call via:
#   git_info_cache_valid || git_info_refresh
git_info_refresh() {
    GIT_IN_REPO=0; GIT_BRANCH=""; GIT_REMOTE=""; GIT_SHA=""; GIT_REMOTE_SHA=""
    GIT_AHEAD=0;   GIT_BEHIND=0
    GIT_STAGED=0;  GIT_MODIFIED=0; GIT_UNTRACKED=0; GIT_STASH=0; GIT_CONFLICTS=0
    _GIT_CACHE_TOP=""; _GIT_CACHE_HEAD_REF=""; _GIT_CACHE_UP_REF=""

    # Always record current dir so non-repo directories are cached too
    _GIT_CACHE_DIR="$PWD"

    # One call for the .git directory (per worktree), the common directory
    # that holds the refs, and the top level.  Inside .git the top level
    # fails, and the call with it, after printing the other two.
    local -a dirs; mapfile -t dirs < <(git rev-parse --git-dir --git-common-dir --show-toplevel 2>/dev/null)
    [[ -n "${dirs[0]-}" ]] || return 1
    GIT_IN_REPO=1
    local git_dir="${dirs[0]}" common_dir="${dirs[1]-${dirs[0]}}"
    [[ "$git_dir" == /* ]]    || git_dir="$PWD/$git_dir"
    [[ "$common_dir" == /* ]] || common_dir="$PWD/$common_dir"
    _GIT_CACHE_GIT_DIR="$git_dir"
    _GIT_CACHE_TOP="${dirs[2]-}"

    # The ref files the cache check reads: the branch's, from HEAD, and the
    # upstream's, from the same call that names it.
    local head=""; { IFS= read -r head < "$git_dir/HEAD"; } 2>/dev/null || true
    [[ "$head" != "ref: "* ]] || _GIT_CACHE_HEAD_REF="$common_dir/${head#ref: }"
    local -a up; mapfile -t up < <(git rev-parse --symbolic-full-name '@{u}' --abbrev-ref '@{u}' 2>/dev/null)
    if (( ${#up[@]} == 2 )); then
        _GIT_CACHE_UP_REF="$common_dir/${up[0]}"
        GIT_REMOTE="${up[1]}"
    fi

    # Record the refs and the time before reading the state they describe,
    # so a change made while this runs shows up as stale next time.  One
    # timestamp file per shell: a subshell gets its own.
    if [[ "$_GIT_CACHE_STAMP_PID" != "$BASHPID" ]]; then
        local tmp="${XDG_RUNTIME_DIR-}"
        [[ -d "$tmp" && -w "$tmp" ]] || tmp="${TMPDIR:-/tmp}"
        _GIT_CACHE_STAMP=$(mktemp "$tmp/bash-prompt-git.XXXXXX" 2>/dev/null) || _GIT_CACHE_STAMP=""
        _GIT_CACHE_STAMP_PID="$BASHPID"
    fi
    [[ -z "$_GIT_CACHE_STAMP" ]] || { echo > "$_GIT_CACHE_STAMP"; } 2>/dev/null || true
    _git_info_refs
    _GIT_CACHE_REFS="$_GIT_REFS"

    # Branch name; falls back to short SHA in detached-HEAD state
    if GIT_BRANCH=$(git symbolic-ref --short HEAD 2>/dev/null); then
        GIT_SHA=$(git rev-parse --short HEAD 2>/dev/null) || true   # none before the first commit
    else
        GIT_BRANCH=$(git rev-parse --short HEAD 2>/dev/null) || {
            GIT_IN_REPO=0; return 1  # corrupted/unreadable HEAD, or bare-repo edge case
        }
        GIT_SHA="$GIT_BRANCH"
    fi

    # Upstream SHA, and ahead/behind in a single rev-list call — "behind<TAB>ahead"
    if [[ -n "$GIT_REMOTE" ]]; then
        GIT_REMOTE_SHA=$(git rev-parse --short '@{u}' 2>/dev/null) || true
        local counts
        counts=$(git rev-list --count --left-right '@{u}...HEAD' 2>/dev/null) || true
        if [[ "$counts" =~ ^([0-9]+)$'\t'([0-9]+)$ ]]; then
            GIT_BEHIND=${BASH_REMATCH[1]}
            GIT_AHEAD=${BASH_REMATCH[2]}
        fi
    fi

    # File-status counts from a single --porcelain call, classified in one
    # awk pass (previously 3 grep forks; `grep -c` also exits 1 on zero
    # matches, which tripped the old `|| echo 0` fallback and left each
    # GIT_* var holding two lines instead of one — a bash arithmetic error
    # on nearly every clean-file-status refresh). Unmerged paths get their
    # own category so a conflicted repo doesn't read as "clean".
    # GIT_OPTIONAL_LOCKS=0: a background status must not refresh and write
    # the index, or a git add/commit in another shell can hit index.lock.
    # (--no-optional-locks does the same but is git 2.15+; old git ignores
    # the variable.)
    local porcelain; porcelain=$(GIT_OPTIONAL_LOCKS=0 git status --porcelain 2>/dev/null) || true
    if [[ -n "$porcelain" ]]; then
        local counts; counts=$(awk '
            { xy = substr($0,1,2) }
            xy == "??" { untracked++; next }
            xy=="DD"||xy=="AU"||xy=="UD"||xy=="UA"||xy=="DU"||xy=="AA"||xy=="UU" { conflicts++; next }
            substr(xy,1,1) ~ /[MADRCT]/ { staged++ }
            substr(xy,2,1) ~ /[MD]/     { modified++ }
            END { printf "%d %d %d %d", staged+0, modified+0, untracked+0, conflicts+0 }
        ' <<< "$porcelain")
        read -r GIT_STAGED GIT_MODIFIED GIT_UNTRACKED GIT_CONFLICTS <<< "$counts"
    fi
    local -a _stash_lines; mapfile -t _stash_lines < <(git stash list 2>/dev/null)
    GIT_STASH=${#_stash_lines[@]}

    cache_touch git_info
}
