#!/usr/bin/env bash
# Toolkit version: 0.1.16
# ════════════════════════════════════════════════════════════════════════════
# lib/git_info.sh — Cached git repository state for bash scripts
#
# Provides current branch, commit, remote tracking, ahead/behind counts,
# and file-status counts in plain globals. A cache avoids re-running git
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
#   GIT_PENDING    — 1 while a status that went over the budget still runs:
#                    the values above are the last ones read, or empty
#                    after a cd to another work tree
# Public functions:
#   git_info_refresh        — collect all git data
#   git_info_cache_valid    — returns 0 if cached data is still fresh
#   git_info_cache_ttl <N>  — set the worktree-staleness TTL (default 5 s)
#   git_info_budget <SECS>  — wait at most SECS for git (default 0: no limit)
#   git_info_untracked <M>  — status -uM: no, normal or all (default: git's
#                             own status.showUntrackedFiles)
#
# Time budget (bash 4.1+; older bash always waits): with a budget, git runs
# in the background and the refresh waits at most SECS for it. Past that
# the refresh returns with GIT_PENDING=1, and each later refresh in the
# same directory picks the result up once it is there, without waiting.
# A cd elsewhere drops the pending status: it runs to its end and its
# output is thrown away. A work tree whose status went over the budget
# lists no untracked files (-uno) for the rest of the shell, so
# GIT_UNTRACKED stays 0 there.
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
# $TMPDIR or /tmp), named bash-prompt-git.PID.XXXXXX. A background status
# writes next to it, to the same name plus a number. The first refresh in a
# shell removes the files of shells that are gone, so none depends on a
# reboot to go. Without a timestamp file the index check always fails,
# every prompt refreshes, and git runs without a budget.
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
declare -gi GIT_PENDING=0

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
declare -g    _GIT_BUDGET=0            # seconds to wait for git; 0 waits for ever
declare -g    _GIT_UNTRACKED=""        # status -u mode; "" leaves it to git
declare -gA   _GIT_SLOW=()             # work tree tops whose status went over budget

# Adjust the worktree-staleness window.
git_info_cache_ttl() { _GIT_CACHE_TTL="${1:-5}"; }

# Wait at most SECS (a decimal, 0 for no limit) for git at each refresh.
# Bash before 4.1 has no {fd} redirection, so there it always waits.
git_info_budget() {
    [[ "${1-}" =~ ^[0-9]*\.?[0-9]+$ ]] || { printf 'git_info_budget: SECS must be a number, not %q\n' "${1-}" >&2; return 1; }
    _GIT_BUDGET="$1"
    (( BASH_VERSINFO[0] > 4 || (BASH_VERSINFO[0] == 4 && BASH_VERSINFO[1] >= 1) )) || _GIT_BUDGET=0
}

# List untracked files as status -uMODE does (no, normal, all), or as git
# is configured when MODE is empty.
git_info_untracked() {
    [[ "${1-}" =~ ^(no|normal|all|)$ ]] || { printf 'git_info_untracked: MODE must be no, normal or all, not %q\n' "$1" >&2; return 1; }
    _GIT_UNTRACKED="${1-}"
}

# Set _GIT_REFS to the contents of HEAD, the branch's ref and the upstream's
# ref, joined: a checkout changes the first, a commit the second, a fetch
# the third. Builtin reads only; a missing file reads as empty.
_git_info_refs() {
    local head="" ref="" up=""
    { IFS= read -r head < "$_GIT_CACHE_GIT_DIR/HEAD"; } 2>/dev/null || true
    [[ -z "$_GIT_CACHE_HEAD_REF" ]] || { IFS= read -r ref < "$_GIT_CACHE_HEAD_REF"; } 2>/dev/null || true
    [[ -z "$_GIT_CACHE_UP_REF" ]]   || { IFS= read -r up  < "$_GIT_CACHE_UP_REF"; }   2>/dev/null || true
    _GIT_REFS="$head|$ref|$up"
}

# ── Cache validity ────────────────────────────────────────────────────────

# Returns 0 when $PWD is the cached directory, or in the cached work tree:
# the nearest .git above it is the cached top's. -ef, so a symlinked path
# to the same tree counts.
_git_info_same_tree() {
    [[ "$PWD" != "$_GIT_CACHE_DIR" ]] || return 0
    (( GIT_IN_REPO )) && [[ -n "$_GIT_CACHE_TOP" ]] || return 1
    local d="$PWD"
    until [[ -e "$d/.git" ]]; do
        [[ -n "$d" ]] || return 1
        d="${d%/*}"
    done
    [[ "${d:-/}" -ef "$_GIT_CACHE_TOP" ]]
}

# Returns 0 (cache is fresh) or 1 (must call git_info_refresh).
# Starts no process: builtin reads, file tests and string comparisons.
git_info_cache_valid() {
    (( ! GIT_PENDING )) || return 1
    _git_info_same_tree || return 1

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

declare -ga   _GIT_LINES=()            # what _git_info_collect printed
declare -gi _GIT_NO_SHOW_STASH=0     # git before 2.35: status has no --show-stash

# Print the state for _git_info_parse: rev-parse's .git directory (per
# worktree), common directory (which holds the refs) and top level, a "--"
# line, then `git status --porcelain=v2 --branch --show-stash`. Two
# processes in all; nothing after rev-parse when this is no repository.
# Inside .git the top level fails, and rev-parse with it, after printing the
# other two; status fails there too, and says so with a "status-failed"
# line. GIT_OPTIONAL_LOCKS=0: a background status must not refresh and
# write the index, or a git add/commit in another shell can hit index.lock
# (--no-optional-locks does the same but is git 2.15+; old git ignores the
# variable).
_git_info_collect() {
    local dirs
    dirs=$(git rev-parse --git-dir --git-common-dir --show-toplevel 2>/dev/null) || true
    [[ -n "$dirs" ]] || return 0
    printf '%s\n--\n' "$dirs"
    local -a args=(--porcelain=v2 --branch) top=()
    mapfile -t top <<< "$dirs"
    if [[ -n "${top[2]-}" && -n "${_GIT_SLOW[${top[2]}]-}" ]]; then
        args+=(-uno)
    elif [[ -n "$_GIT_UNTRACKED" ]]; then
        args+=("-u$_GIT_UNTRACKED")
    fi
    (( _GIT_NO_SHOW_STASH )) || args+=(--show-stash)
    GIT_OPTIONAL_LOCKS=0 git status "${args[@]}" 2>/dev/null && return 0
    # git before 2.35 rejects --show-stash: once more without it, and tell
    # the parser so later refreshes leave it out.
    if (( ! _GIT_NO_SHOW_STASH )) && GIT_OPTIONAL_LOCKS=0 git status "${args[@]:0:${#args[@]}-1}" 2>/dev/null; then
        printf '# no-show-stash\n'
        return 0
    fi
    printf 'status-failed\n'
}

# Fill the GIT_* globals and the cache keys from _GIT_LINES. Returns 1
# outside a repository, or when HEAD cannot be read.
_git_info_parse() {
    local n=${#_GIT_LINES[@]} i=0
    local -a dirs=()
    while (( i < n )) && [[ "${_GIT_LINES[i]}" != -- ]]; do
        dirs+=("${_GIT_LINES[i]}"); i=$(( i + 1 ))
    done
    i=$(( i + 1 ))
    [[ -n "${dirs[0]-}" ]] || return 1
    GIT_IN_REPO=1
    local git_dir="${dirs[0]}" common_dir="${dirs[1]-${dirs[0]}}"
    [[ "$git_dir" == /* ]]    || git_dir="$PWD/$git_dir"
    [[ "$common_dir" == /* ]] || common_dir="$PWD/$common_dir"
    _GIT_CACHE_GIT_DIR="$git_dir"
    _GIT_CACHE_TOP="${dirs[2]-}"

    # One pass over status: the branch headers, then one line per path
    # ("1"/"2" changed, "u" unmerged, "?" untracked). XY is the staged and
    # the unstaged state, "." for unchanged.
    local line oid="" branch="" up="" ab="" failed=0 xy
    for (( ; i < n; i++ )); do
        line="${_GIT_LINES[i]}"
        case "$line" in
            '? '*)                 GIT_UNTRACKED+=1 ;;
            [12]' '*)
                xy="${line:2:2}"
                [[ "${xy:0:1}" == [MADRCT] ]] && GIT_STAGED+=1
                [[ "${xy:1:1}" == [MD] ]] && GIT_MODIFIED+=1 ;;
            'u '*)                 GIT_CONFLICTS+=1 ;;
            '# branch.oid '*)      oid="${line#\# branch.oid }" ;;
            '# branch.head '*)     branch="${line#\# branch.head }" ;;
            '# branch.upstream '*) up="${line#\# branch.upstream }" ;;
            '# branch.ab '*)       ab="${line#\# branch.ab }" ;;
            '# stash '*)           GIT_STASH="${line#\# stash }" ;;
            '# no-show-stash')     _GIT_NO_SHOW_STASH=1 ;;
            status-failed)         failed=1 ;;
        esac
    done

    # The branch's loose ref file, from HEAD, for the cache check.
    local head=""; { IFS= read -r head < "$git_dir/HEAD"; } 2>/dev/null || true
    [[ "$head" != "ref: "* ]] || _GIT_CACHE_HEAD_REF="$common_dir/${head#ref: }"

    # Inside .git (or a bare repository) status fails: the branch and its
    # commit come from HEAD and the branch's loose ref instead.
    if (( failed )); then
        if [[ "$head" == "ref: refs/heads/"* ]]; then
            branch="${head#ref: refs/heads/}"
            oid=""; { IFS= read -r oid < "$_GIT_CACHE_HEAD_REF"; } 2>/dev/null || oid="(initial)"
        elif [[ "$head" =~ ^[0-9a-f]{40,}$ ]]; then
            branch="(detached)"; oid="$head"
        else
            GIT_IN_REPO=0; return 1      # unreadable HEAD
        fi
    fi

    # Short SHAs are the first 7 hex digits: git's own --short can be longer
    # in a big repository, where 7 may not be unique.
    if [[ "$branch" == "(detached)" ]]; then
        GIT_BRANCH="${oid:0:7}"; GIT_SHA="$GIT_BRANCH"
    else
        GIT_BRANCH="$branch"
        [[ "$oid" == "(initial)" ]] || GIT_SHA="${oid:0:7}"
    fi

    # branch.ab is there only when the upstream exists: one that is gone
    # leaves GIT_REMOTE empty. Its commit comes from its loose ref file,
    # which the cache check reads anyway; a packed ref needs one rev-parse.
    if [[ "$ab" =~ ^\+([0-9]+)\ -([0-9]+)$ ]]; then
        GIT_AHEAD=${BASH_REMATCH[1]}
        GIT_BEHIND=${BASH_REMATCH[2]}
        GIT_REMOTE="$up"
        _GIT_CACHE_UP_REF="$common_dir/refs/remotes/$up"
        [[ -e "$_GIT_CACHE_UP_REF" ]] || [[ ! -e "$common_dir/refs/heads/$up" ]] \
            || _GIT_CACHE_UP_REF="$common_dir/refs/heads/$up"
        local sha=""; { IFS= read -r sha < "$_GIT_CACHE_UP_REF"; } 2>/dev/null || true
        if [[ -n "$sha" ]]; then
            GIT_REMOTE_SHA="${sha:0:7}"
        else
            GIT_REMOTE_SHA=$(git rev-parse --short=7 '@{u}' 2>/dev/null) || true
        fi
    fi
    return 0
}

# The background status, when one is pending (private)
declare -g    _GIT_JOB_FD=""           # read end: a line, or EOF, once it is done
declare -g    _GIT_JOB_OUT=""          # file it writes _git_info_collect's output to
declare -g    _GIT_JOB_DIR=""          # $PWD it started in
declare -gi _GIT_JOB_N=0             # out file number: an abandoned job keeps writing to its own
declare -ga   _GIT_JOB_GONE=()         # out files of abandoned jobs, removed at the next result

# Create this shell's timestamp file, once per $BASHPID (a subshell gets
# its own), and remove the files of shells that are gone. kill -0 rather
# than /proc, which not every system has. A pid now taken by another of
# this user's processes keeps its files until that one goes too.
_git_info_stamp_init() {
    local tmp="${XDG_RUNTIME_DIR-}" f pid
    [[ -d "$tmp" && -w "$tmp" ]] || tmp="${TMPDIR:-/tmp}"
    local -a gone=()
    for f in "$tmp"/bash-prompt-git.*; do
        pid="${f#"$tmp"/bash-prompt-git.}"; pid="${pid%%.*}"
        [[ "$pid" =~ ^[0-9]+$ ]] && ! kill -0 "$pid" 2>/dev/null && gone+=("$f")
    done
    (( ${#gone[@]} == 0 )) || command rm -f -- "${gone[@]}"
    _GIT_CACHE_STAMP_PID="$BASHPID"
    _GIT_CACHE_STAMP=$(mktemp "$tmp/bash-prompt-git.$_GIT_CACHE_STAMP_PID.XXXXXX" 2>/dev/null) || _GIT_CACHE_STAMP=""
    _GIT_JOB_FD=""; GIT_PENDING=0
}

# Start _git_info_collect in the background, writing to its own file. Its
# process substitution prints a line when it is done.
_git_info_job_start() {
    _GIT_JOB_OUT="$_GIT_CACHE_STAMP.$_GIT_JOB_N"
    _GIT_JOB_DIR="$PWD"
    exec {_GIT_JOB_FD}< <(_git_info_collect > "$_GIT_JOB_OUT" 2>/dev/null; echo)
}

# Wait at most SECS for the job. Returns 0 once it is done, its output in
# _GIT_LINES and its descriptor closed; 1 while it still runs. read -t 0
# only looks: 0 once a line or EOF is there, 1 (not over 128) before.
_git_info_job_wait() {
    local _
    if [[ "$1" == 0 ]]; then
        read -t 0 -u "$_GIT_JOB_FD" _ || return 1
    else
        read -r -t "$1" -u "$_GIT_JOB_FD" _ || { (( $? <= 128 )) || return 1; }   # timed out; EOF means done
    fi
    exec {_GIT_JOB_FD}<&-
    _GIT_JOB_FD=""
    mapfile -t _GIT_LINES < "$_GIT_JOB_OUT"
    if (( ${#_GIT_JOB_GONE[@]} )); then
        command rm -f -- "${_GIT_JOB_GONE[@]}"
        _GIT_JOB_GONE=()
    fi
    return 0
}

# Stop waiting for the job: close its descriptor and give the next one
# another file, since this one may still write to its own.
_git_info_job_drop() {
    exec {_GIT_JOB_FD}<&-
    _GIT_JOB_FD=""
    _GIT_JOB_GONE+=("$_GIT_JOB_OUT")
    _GIT_JOB_N+=1
}

_git_info_reset() {
    GIT_IN_REPO=0; GIT_BRANCH=""; GIT_REMOTE=""; GIT_SHA=""; GIT_REMOTE_SHA=""
    GIT_AHEAD=0;   GIT_BEHIND=0
    GIT_STAGED=0;  GIT_MODIFIED=0; GIT_UNTRACKED=0; GIT_STASH=0; GIT_CONFLICTS=0
    _GIT_CACHE_TOP=""; _GIT_CACHE_HEAD_REF=""; _GIT_CACHE_UP_REF=""
}

# Fill the globals from _GIT_LINES and record what the cache checks
_git_info_finish() {
    GIT_PENDING=0
    _git_info_reset
    _git_info_parse || return 1

    # The refs as they are now. A commit made while status ran reads as
    # current here. The TTL catches it.
    _git_info_refs
    _GIT_CACHE_REFS="$_GIT_REFS"
    cache_touch git_info
}

# Collect all git state in one pass. Call via:
#   git_info_cache_valid || git_info_refresh
# Returns 1 outside a repository; 0 in one, and while a status is pending.
git_info_refresh() {
    [[ "$_GIT_CACHE_STAMP_PID" == "$BASHPID" ]] || _git_info_stamp_init

    # A status still running from an earlier refresh: its result once it is
    # there, without waiting, as long as this is still where it started.
    if (( GIT_PENDING )); then
        if [[ "$PWD" == "$_GIT_JOB_DIR" ]]; then
            _git_info_job_wait 0 || return 0
            _git_info_finish
            return
        fi
        _git_info_job_drop
    fi

    local same=0
    _git_info_same_tree && same=1

    # Always record current dir so non-repo directories are cached too
    _GIT_CACHE_DIR="$PWD"

    # The time before reading the state it describes, so an index written
    # while git runs shows up as stale next time.
    [[ -z "$_GIT_CACHE_STAMP" ]] || { echo > "$_GIT_CACHE_STAMP"; } 2>/dev/null || true

    if [[ "$_GIT_BUDGET" == 0 || -z "$_GIT_CACHE_STAMP" ]]; then
        mapfile -t _GIT_LINES < <(_git_info_collect)
        _git_info_finish
        return
    fi

    _git_info_job_start
    if _git_info_job_wait "$_GIT_BUDGET"; then
        _git_info_finish
        return
    fi

    # Over budget. The work tree, when rev-parse has printed it, lists no
    # untracked files from now on. The old values stand while this is the
    # same work tree. In another, nothing shows until the status is in.
    GIT_PENDING=1
    local -a head=()
    { mapfile -t -n 4 head < "$_GIT_JOB_OUT"; } 2>/dev/null || true
    [[ "${head[3]-}" != -- || -z "${head[2]-}" ]] || _GIT_SLOW[${head[2]}]=1
    (( same )) || _git_info_reset
    return 0
}
