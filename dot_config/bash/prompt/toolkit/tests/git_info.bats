load test_helper

setup() {
    load_prompt_lib
    make_git_repo
    git_info_cache_ttl 0   # disable TTL so every test sees a fresh refresh
}

@test "non-repo directory: GIT_IN_REPO is 0, returns a clean explicit status" {
    cd "$BATS_TEST_TMPDIR"
    run git_info_refresh
    [[ "$status" -eq 1 ]]
    [[ "$GIT_IN_REPO" == "0" ]]
}

@test "clean repo produces zero counts with NO stderr output" {
    echo x > f.txt && git add f.txt && git commit -qm init
    run bash -c "source '$DOTFILES_ROOT/lib/git_info.sh'; cd '$REPO_DIR'; git_info_refresh 2>&1 >/dev/null"
    [[ -z "$output" ]]
}

@test "clean repo: staged/modified/untracked/conflicts are all exactly 0" {
    echo x > f.txt && git add f.txt && git commit -qm init
    git_info_refresh
    [[ "$GIT_STAGED" == "0" ]]
    [[ "$GIT_MODIFIED" == "0" ]]
    [[ "$GIT_UNTRACKED" == "0" ]]
    [[ "$GIT_CONFLICTS" == "0" ]]
}

@test "arithmetic on a zero count does not throw a syntax error (regression: grep -c || echo 0 bug)" {
    echo x > f.txt && git add f.txt && git commit -qm init
    git_info_refresh
    (( GIT_STAGED > 0 )) || true   # must not error regardless of outcome
}

@test "staged, modified, and untracked are each counted correctly and independently" {
    echo x > f.txt && git add f.txt && git commit -qm init
    echo y >> f.txt                      # modified
    echo z > untracked.txt               # untracked
    echo w > staged.txt && git add staged.txt   # staged
    git_info_refresh
    [[ "$GIT_STAGED" == "1" ]]
    [[ "$GIT_MODIFIED" == "1" ]]
    [[ "$GIT_UNTRACKED" == "1" ]]
}

@test "merge conflict sets GIT_CONFLICTS, not silently 'clean'" {
    echo base > f.txt && git add f.txt && git commit -qm base
    git checkout -qb a && echo aaa > f.txt && git commit -qam a
    git checkout -q main 2>/dev/null || git checkout -q master
    git checkout -qb b && echo bbb > f.txt && git commit -qam b
    git merge a -q 2>/dev/null || true
    git_info_refresh
    [[ "$GIT_CONFLICTS" == "1" ]]
    [[ "$GIT_STAGED" == "0" ]]   # conflicted paths must not double-count as staged
}

@test "detached HEAD falls back to short SHA for GIT_BRANCH" {
    echo x > f.txt && git add f.txt && git commit -qm init
    git checkout -q "$(git rev-parse HEAD)"
    git_info_refresh
    [[ "$GIT_IN_REPO" == "1" ]]
    [[ -n "$GIT_BRANCH" ]]
    [[ "${#GIT_BRANCH}" -le 10 ]]   # short SHA, not a branch name
}

@test "ahead/behind counts reflect actual commit divergence" {
    echo x > f.txt && git add f.txt && git commit -qm init
    REMOTE_DIR="$BATS_TEST_TMPDIR/remote.git"
    git init -q --bare "$REMOTE_DIR"
    git remote add origin "$REMOTE_DIR"
    local_branch="$(git branch --show-current)"
    git push -q origin "HEAD:$local_branch"
    git branch -q --set-upstream-to="origin/$local_branch" "$local_branch"
    echo y >> f.txt && git commit -qam second
    git_info_refresh
    [[ "$GIT_AHEAD" == "1" ]]
    [[ "$GIT_BEHIND" == "0" ]]
}

@test "cache_valid returns false immediately after cd to a different repo" {
    echo x > f.txt && git add f.txt && git commit -qm init
    git_info_refresh
    OTHER_DIR="$BATS_TEST_TMPDIR/other"
    mkdir -p "$OTHER_DIR" && cd "$OTHER_DIR"
    ! git_info_cache_valid
}

@test "cache_valid returns true on an immediate second call with no changes" {
    echo x > f.txt && git add f.txt && git commit -qm init
    git_info_cache_ttl 30   # this test needs the TTL to actually hold
    git_info_refresh
    git_info_cache_valid
}

@test "git_info.sh sourced on its own: fresh after a refresh, stale once the TTL elapses" {
    # A bare bash, not load_prompt_lib: git_info.sh must load cache.sh itself.
    echo x > f.txt && git add f.txt && git commit -qm init
    run bash -c '
        source "$1/lib/git_info.sh"
        git_info_refresh
        echo "in_repo=$GIT_IN_REPO"
        git_info_cache_valid && echo fresh
        git_info_cache_ttl 1
        sleep 1.2   # real elapsed time: cache.sh prefers EPOCHSECONDS on bash 5+
        git_info_cache_valid || echo stale
    ' _ "$DOTFILES_ROOT"
    [ "$output" = $'in_repo=1\nfresh\nstale' ]
}

@test "stash count is reflected in GIT_STASH" {
    echo x > f.txt && git add f.txt && git commit -qm init
    echo y >> f.txt
    git stash -q
    git_info_refresh
    [[ "$GIT_STASH" == "1" ]]
}

@test "a refresh does not rewrite the index (another git command would find index.lock)" {
    echo x > f.txt && git add f.txt && git commit -qm init
    touch -d '+1 minute' f.txt
    before=$(stat -c %y .git/index)
    git_info_refresh
    [[ "$(stat -c %y .git/index)" == "$before" ]]
}

# An upstream without a remote repository: origin/main is a ref here, and
# the branch tracks it. Moving that ref is what a fetch does.
fake_upstream() {
    git update-ref refs/remotes/origin/main HEAD
    git config remote.origin.url "$BATS_TEST_TMPDIR/none.git"
    git config remote.origin.fetch '+refs/heads/*:refs/remotes/origin/*'
    git config branch.main.remote origin
    git config branch.main.merge refs/heads/main
}

# The cache check fails. A function, because bats ignores the status of
# `! cmd` anywhere but on a test's last line.
stale() { ! git_info_cache_valid; }

@test "GIT_SHA and GIT_REMOTE_SHA are the short SHAs of HEAD and the upstream" {
    echo x > f.txt && git add f.txt && git commit -qm init
    fake_upstream
    git commit -q --allow-empty -m second
    git_info_refresh
    [[ "$GIT_SHA" == "$(git rev-parse --short HEAD)" ]]
    [[ "$GIT_REMOTE_SHA" == "$(git rev-parse --short '@{u}')" ]]
    [[ "$GIT_SHA" != "$GIT_REMOTE_SHA" ]]
    [[ "$(_ps_seg_git_sha)" == "$GIT_SHA" ]]
    [[ "$(_ps_seg_git_remote_sha)" == "$GIT_REMOTE_SHA" ]]
}

@test "no upstream: GIT_REMOTE_SHA is empty and its segment silent" {
    echo x > f.txt && git add f.txt && git commit -qm init
    git_info_refresh
    [[ -n "$GIT_SHA" ]]
    [[ -z "$GIT_REMOTE_SHA" ]]
    [[ -z "$(_ps_seg_git_remote_sha)" ]]
}

@test "before the first commit: the branch shows, GIT_SHA is empty" {
    git_info_refresh
    [[ "$GIT_BRANCH" == "main" ]]
    [[ -z "$GIT_SHA" ]]
    [[ -z "$(_ps_seg_git_sha)" ]]
}

@test "detached HEAD: GIT_SHA is the same short SHA as GIT_BRANCH" {
    echo x > f.txt && git add f.txt && git commit -qm init
    git checkout -q --detach
    git_info_refresh
    [[ "$GIT_SHA" == "$GIT_BRANCH" ]]
    [[ "$GIT_SHA" == "$(git rev-parse --short HEAD)" ]]
}

@test "a cache hit starts no process" {
    echo x > f.txt && git add f.txt && git commit -qm init
    fake_upstream
    git_info_cache_ttl 30
    git_info_refresh
    mkdir sub && cd sub
    PATH=/nonexistent git_info_cache_valid
}

@test "cd within the same work tree keeps the cache, through a symlink too" {
    echo x > f.txt && git add f.txt && git commit -qm init
    git_info_cache_ttl 30
    git_info_refresh
    mkdir -p a/b && cd a/b
    git_info_cache_valid
    ln -s "$REPO_DIR" "$BATS_TEST_TMPDIR/link"
    cd "$BATS_TEST_TMPDIR/link/a"
    git_info_cache_valid
}

@test "cd into a nested repository or a linked worktree invalidates" {
    echo x > f.txt && git add f.txt && git commit -qm init
    git_info_cache_ttl 30
    git_info_refresh
    git init -q nested
    cd nested
    stale
    cd "$REPO_DIR"
    git_info_cache_valid
    git worktree add -q "$BATS_TEST_TMPDIR/wt" 2>/dev/null
    cd "$BATS_TEST_TMPDIR/wt"
    stale
}

@test "a branch switch invalidates" {
    echo x > f.txt && git add f.txt && git commit -qm init
    git_info_cache_ttl 30
    git_info_refresh
    git checkout -qb other
    stale
}

@test "HEAD naming another branch invalidates, the index untouched" {
    echo x > f.txt && git add f.txt && git commit -qm init
    git branch other
    git_info_cache_ttl 30
    git_info_refresh
    git symbolic-ref HEAD refs/heads/other
    stale
}

@test "a commit or reset that leaves the index alone invalidates" {
    echo x > f.txt && git add f.txt && git commit -qm init
    git commit -q --allow-empty -m second
    git_info_cache_ttl 30
    git_info_refresh
    git reset -q --soft HEAD~1
    stale
    git_info_refresh
    [[ "$GIT_SHA" == "$(git rev-parse --short HEAD)" ]]
}

@test "a commit in a linked worktree invalidates that worktree's cache" {
    echo x > f.txt && git add f.txt && git commit -qm init
    git worktree add -q "$BATS_TEST_TMPDIR/wt" 2>/dev/null
    cd "$BATS_TEST_TMPDIR/wt"
    git_info_cache_ttl 30
    git_info_refresh
    git commit -q --allow-empty -m in-worktree
    stale
}

@test "an upstream that moves (a fetch) invalidates" {
    echo x > f.txt && git add f.txt && git commit -qm init
    git commit -q --allow-empty -m second
    fake_upstream
    git_info_cache_ttl 30
    git_info_refresh
    git update-ref refs/remotes/origin/main HEAD~1
    stale
    git_info_refresh
    [[ "$GIT_AHEAD" == "1" ]]
    [[ "$GIT_REMOTE_SHA" == "$(git rev-parse --short HEAD~1)" ]]
}

@test "git add invalidates" {
    echo x > f.txt && git add f.txt && git commit -qm init
    git_info_cache_ttl 30
    git_info_refresh
    echo y > g.txt && git add g.txt
    stale
    git_info_refresh
    git_info_cache_valid
}

@test "an unstaged edit shows once the TTL runs out" {
    echo x > f.txt && git add f.txt && git commit -qm init
    git_info_cache_ttl 30
    git_info_refresh
    echo y > f.txt
    git_info_cache_valid
    # Back-date the last refresh past the TTL rather than sleep 30 s
    (( _CACHE_TOUCHED[git_info] -= 31 ))
    stale
    git_info_refresh
    [ "$GIT_MODIFIED" -eq 1 ]
}

@test "inside .git the branch still shows" {
    echo x > f.txt && git add f.txt && git commit -qm init
    cd .git
    git_info_refresh
    [[ "$GIT_IN_REPO" == "1" ]]
    [[ "$GIT_BRANCH" == "main" ]]
}

# A git on PATH that logs each call's arguments to $GIT_LOG, then runs the
# real one. REJECT, when set, is an option it fails on the way git before
# 2.35 fails on --show-stash.
logging_git() {
    local real; real=$(command -v git)
    mkdir -p "$BATS_TEST_TMPDIR/bin"
    cat > "$BATS_TEST_TMPDIR/bin/git" <<STUB
#!/usr/bin/env bash
printf '%s\n' "\$*" >> "$BATS_TEST_TMPDIR/git.log"
for a; do [[ -n "\${REJECT-}" && "\$a" == "\$REJECT" ]] && exit 129; done
exec "$real" "\$@"
STUB
    chmod +x "$BATS_TEST_TMPDIR/bin/git"
    PATH="$BATS_TEST_TMPDIR/bin:$PATH"
    : > "$BATS_TEST_TMPDIR/git.log"
}

@test "a refresh runs two git processes, upstream and stash included" {
    echo x > f.txt && git add f.txt && git commit -qm init
    fake_upstream
    git commit -q --allow-empty -m second
    echo y >> f.txt && git stash -q
    logging_git
    git_info_refresh
    [[ "$(wc -l < "$BATS_TEST_TMPDIR/git.log")" == 2 ]]
    [[ "$GIT_AHEAD" == 1 && "$GIT_STASH" == 1 && -n "$GIT_REMOTE_SHA" ]]
}

@test "outside a repository a refresh runs one git process" {
    cd "$BATS_TEST_TMPDIR"
    logging_git
    git_info_refresh || true
    [[ "$(wc -l < "$BATS_TEST_TMPDIR/git.log")" == 1 ]]
}

@test "a packed upstream ref still gives GIT_REMOTE_SHA" {
    echo x > f.txt && git add f.txt && git commit -qm init
    fake_upstream
    git commit -q --allow-empty -m second
    git pack-refs --all
    [[ ! -e .git/refs/remotes/origin/main ]]
    git_info_refresh
    [[ "$GIT_REMOTE_SHA" == "$(git rev-parse --short=7 '@{u}')" ]]
    [[ "$GIT_SHA" == "$(git rev-parse --short=7 HEAD)" ]]
}

@test "an upstream that is gone leaves GIT_REMOTE empty" {
    echo x > f.txt && git add f.txt && git commit -qm init
    fake_upstream
    git update-ref -d refs/remotes/origin/main
    git_info_refresh
    [[ -z "$GIT_REMOTE" && -z "$GIT_REMOTE_SHA" ]]
    [[ "$GIT_AHEAD" == 0 && "$GIT_BEHIND" == 0 ]]
}

@test "git without --show-stash: counts still come, and later refreshes leave it out" {
    echo x > f.txt && git add f.txt && git commit -qm init
    echo y >> f.txt
    logging_git
    REJECT=--show-stash git_info_refresh
    [[ "$GIT_MODIFIED" == 1 && "$GIT_STASH" == 0 ]]
    : > "$BATS_TEST_TMPDIR/git.log"
    REJECT=--show-stash git_info_refresh
    ! grep -q -- --show-stash "$BATS_TEST_TMPDIR/git.log"
}

@test "inside .git under errexit the branch still shows: rev-parse fails there, and must not end the refresh" {
    echo x > f.txt && git add f.txt && git commit -qm init
    run bash -ec "source '$DOTFILES_ROOT/lib/git_info.sh'; cd '$REPO_DIR/.git'; git_info_refresh; echo \"\$GIT_BRANCH \$GIT_SHA\""
    [[ "$status" -eq 0 ]]
    [[ "$output" == "main $(git rev-parse --short=7 HEAD)" ]]
}

# A git that logs its arguments, and sleeps before status for the seconds in
# $BATS_TEST_TMPDIR/slow while that file exists
sleepy_git() {
    local real; real=$(command -v git)
    mkdir -p "$BATS_TEST_TMPDIR/bin"
    cat > "$BATS_TEST_TMPDIR/bin/git" <<STUB
#!/usr/bin/env bash
printf '%s\n' "\$*" >> "$BATS_TEST_TMPDIR/git.log"
[[ "\$1" != status || ! -e "$BATS_TEST_TMPDIR/slow" ]] || sleep "\$(< "$BATS_TEST_TMPDIR/slow")"
exec "$real" "\$@"
STUB
    chmod +x "$BATS_TEST_TMPDIR/bin/git"
    PATH="$BATS_TEST_TMPDIR/bin:$PATH"
    : > "$BATS_TEST_TMPDIR/git.log"
}

@test "with a budget, a fast status reads as it does without one" {
    echo x > f.txt && git add f.txt && git commit -qm init
    echo y >> f.txt && touch new.txt
    git_info_budget 5
    git_info_refresh
    [[ "$GIT_PENDING" == 0 && "$GIT_MODIFIED" == 1 && "$GIT_UNTRACKED" == 1 ]]
    [[ "$GIT_SHA" == "$(git rev-parse --short=7 HEAD)" ]]
}

@test "over the budget: pending, old values stand, the result comes in later without waiting" {
    echo x > f.txt && git add f.txt && git commit -qm init
    sleepy_git
    git_info_budget 0.2
    git_info_refresh
    [[ "$GIT_BRANCH" == main && "$GIT_MODIFIED" == 0 ]]
    echo y >> f.txt
    echo 1 > "$BATS_TEST_TMPDIR/slow"
    git_info_refresh
    [[ "$GIT_PENDING" == 1 && "$GIT_BRANCH" == main && "$GIT_MODIFIED" == 0 ]]
    ! git_info_cache_valid
    local t0=$SECONDS
    git_info_refresh                       # still running: returns at once
    [[ "$GIT_PENDING" == 1 ]] && (( SECONDS - t0 < 1 ))
    sleep 1.2
    git_info_refresh
    [[ "$GIT_PENDING" == 0 && "$GIT_MODIFIED" == 1 ]]
}

@test "a work tree that went over the budget is listed with -uno from then on" {
    echo x > f.txt && git add f.txt && git commit -qm init
    touch new.txt
    sleepy_git
    git_info_budget 0.2
    echo 0.6 > "$BATS_TEST_TMPDIR/slow"
    git_info_refresh
    [[ "$GIT_PENDING" == 1 ]]
    sleep 0.8
    git_info_refresh
    [[ "$GIT_PENDING" == 0 ]]
    command rm "$BATS_TEST_TMPDIR/slow"
    : > "$BATS_TEST_TMPDIR/git.log"
    git_info_refresh
    grep -q -- '^status .*-uno' "$BATS_TEST_TMPDIR/git.log"
    [[ "$GIT_UNTRACKED" == 0 ]]
}

@test "a cd to another work tree while pending shows nothing, then that tree" {
    echo x > f.txt && git add f.txt && git commit -qm init
    local other="$BATS_TEST_TMPDIR/other"
    git init -q -b side "$other"
    sleepy_git
    git_info_budget 0.2
    git_info_refresh
    echo 0.5 > "$BATS_TEST_TMPDIR/slow"
    git_info_refresh
    [[ "$GIT_PENDING" == 1 && "$GIT_BRANCH" == main ]]
    command rm "$BATS_TEST_TMPDIR/slow"
    cd "$other"
    git_info_refresh
    [[ "$GIT_PENDING" == 0 && "$GIT_BRANCH" == side ]]
    echo 0.5 > "$BATS_TEST_TMPDIR/slow"
    cd "$REPO_DIR"
    git_info_refresh
    [[ "$GIT_PENDING" == 1 && "$GIT_IN_REPO" == 0 && -z "$GIT_BRANCH" ]]
}

@test "the pending segment marks a status still running" {
    GIT_PENDING=1
    [[ "$(strip_ansi "$(_ps_seg_git_pending)")" == "…" ]]
    GIT_PENDING=0
    [[ -z "$(_ps_seg_git_pending)" ]]
}

@test "git_info_untracked passes -uMODE to status, and refuses another mode" {
    echo x > f.txt && git add f.txt && git commit -qm init
    logging_git
    git_info_untracked normal
    git_info_refresh
    grep -q -- '^status .*-unormal' "$BATS_TEST_TMPDIR/git.log"
    run git_info_untracked some
    [[ "$status" == 1 && "$output" == "git_info_untracked: MODE must be no, normal or all, not some" ]]
    run git_info_budget 1s
    [[ "$status" == 1 && "$output" == "git_info_budget: SECS must be a number, not 1s" ]]
}

@test "the first refresh removes files of shells that are gone, and keeps live ones" {
    local tmp="$BATS_TEST_TMPDIR/rt"
    mkdir "$tmp"
    export XDG_RUNTIME_DIR="$tmp"
    sleep 30 & local live=$!
    ( exit 0 ) & local dead=$!; wait "$dead"
    touch "$tmp/bash-prompt-git.$dead.abc123" "$tmp/bash-prompt-git.$dead.abc123.0" \
          "$tmp/bash-prompt-git.$live.def456" "$tmp/other"
    _GIT_CACHE_STAMP_PID=""
    git_info_refresh
    kill "$live"
    [[ ! -e "$tmp/bash-prompt-git.$dead.abc123" && ! -e "$tmp/bash-prompt-git.$dead.abc123.0" ]]
    [[ -e "$tmp/bash-prompt-git.$live.def456" && -e "$tmp/other" ]]
    [[ "$_GIT_CACHE_STAMP" == "$tmp/bash-prompt-git.$BASHPID."* ]]
}
