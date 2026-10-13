load test_helper

setup() {
    load_prompt_lib
}

@test "pwd segment collapses \$HOME to ~" {
    HOME="$BATS_TEST_TMPDIR"
    cd "$HOME"
    [[ "$(_ps_seg_pwd)" == "~" ]]
}

@test "pwd segment truncates long paths with a leading ellipsis" {
    mkdir -p "$BATS_TEST_TMPDIR/a/very/long/nested/path/that/exceeds/the/visible/width/limit/for/sure"
    cd "$BATS_TEST_TMPDIR/a/very/long/nested/path/that/exceeds/the/visible/width/limit/for/sure"
    result="$(_ps_seg_pwd)"
    [[ "$result" == "…"* ]]
    [[ "$(str_width "$result")" -le 35 ]]
}

@test "pwd segment truncation does not mangle multi-byte UTF-8 characters" {
    mkdir -p "$BATS_TEST_TMPDIR/café/données/very/long/path/segment/for/testing/truncation/logic"
    cd "$BATS_TEST_TMPDIR/café/données/very/long/path/segment/for/testing/truncation/logic"
    result="$(_ps_seg_pwd)"
    # a mangled multi-byte sequence would produce invalid UTF-8; python's
    # strict decode raises on any invalid byte sequence
    printf '%s' "$result" | python3 -c "import sys; sys.stdin.buffer.read().decode('utf-8')"
}

@test "pwd segment strips ANSI escape sequences from directory names" {
    evil_dir="$BATS_TEST_TMPDIR/evil$(printf '\033[31m')colored"
    mkdir -p "$evil_dir" 2>/dev/null || skip "filesystem rejected ANSI bytes in a filename"
    cd "$evil_dir"
    result="$(_ps_seg_pwd)"
    [[ "$result" != *$'\033'* ]]
}

@test "pwd segment strips raw control bytes from directory names" {
    evil_dir="$BATS_TEST_TMPDIR/evil$(printf '\x07')bell"
    mkdir -p "$evil_dir" 2>/dev/null || skip "filesystem rejected control bytes in a filename"
    cd "$evil_dir"
    result="$(_ps_seg_pwd)"
    [[ "$result" != *$'\x07'* ]]
}

@test "modules segment: two modules, no stray colons" {
    result=$(LOADEDMODULES="gcc/11:python/3.9" bash -c "source '$DOTFILES_ROOT/lib/colors.sh'; source '$DOTFILES_ROOT/lib/term_utils.sh'; source '$DOTFILES_ROOT/lib/git_info.sh'; source '$DOTFILES_ROOT/prompt.sh'; _ps_seg_modules")
    [[ "$result" == "⊞ 2" ]]
}

@test "modules segment: trailing colon does not overcount" {
    result=$(LOADEDMODULES="gcc/11:python/3.9:" bash -c "source '$DOTFILES_ROOT/lib/colors.sh'; source '$DOTFILES_ROOT/lib/term_utils.sh'; source '$DOTFILES_ROOT/lib/git_info.sh'; source '$DOTFILES_ROOT/prompt.sh'; _ps_seg_modules")
    [[ "$result" == "⊞ 2" ]]
}

@test "modules segment: leading colon does not overcount" {
    result=$(LOADEDMODULES=":gcc/11:python/3.9" bash -c "source '$DOTFILES_ROOT/lib/colors.sh'; source '$DOTFILES_ROOT/lib/term_utils.sh'; source '$DOTFILES_ROOT/lib/git_info.sh'; source '$DOTFILES_ROOT/prompt.sh'; _ps_seg_modules")
    [[ "$result" == "⊞ 2" ]]
}

@test "modules segment: doubled colon does not overcount" {
    result=$(LOADEDMODULES="gcc/11::python/3.9" bash -c "source '$DOTFILES_ROOT/lib/colors.sh'; source '$DOTFILES_ROOT/lib/term_utils.sh'; source '$DOTFILES_ROOT/lib/git_info.sh'; source '$DOTFILES_ROOT/prompt.sh'; _ps_seg_modules")
    [[ "$result" == "⊞ 2" ]]
}

@test "modules segment: unset LOADEDMODULES produces no output" {
    result=$(unset LOADEDMODULES; bash -c "source '$DOTFILES_ROOT/lib/colors.sh'; source '$DOTFILES_ROOT/lib/term_utils.sh'; source '$DOTFILES_ROOT/lib/git_info.sh'; source '$DOTFILES_ROOT/prompt.sh'; _ps_seg_modules")
    [[ -z "$result" ]]
}

@test "exit segment shows a checkmark for success" {
    PROMPT_LAST_EXIT=0
    [[ "$(plain "$(_ps_seg_exit)")" == "✓" ]]
}

@test "exit segment shows the code for failure" {
    PROMPT_LAST_EXIT=127
    [[ "$(plain "$(_ps_seg_exit)")" == "✗ 127" ]]
}

@test "git_conflicts segment is silent when there are no conflicts" {
    GIT_IN_REPO=1
    GIT_CONFLICTS=0
    [[ -z "$(_ps_seg_git_conflicts)" ]]
}

@test "git_conflicts segment shows the count when conflicts exist" {
    GIT_IN_REPO=1
    GIT_CONFLICTS=2
    [[ "$(plain "$(_ps_seg_git_conflicts)")" == "⚠2" ]]
}

@test "git_full_state segment is silent outside a repo" {
    GIT_IN_REPO=0
    [[ -z "$(_ps_seg_git_full_state)" ]]
}

@test "git_full_state segment shows (✓) when every count is zero" {
    GIT_IN_REPO=1 GIT_STAGED=0 GIT_MODIFIED=0 GIT_UNTRACKED=0 GIT_STASH=0 GIT_CONFLICTS=0
    [[ "$(plain "$(_ps_seg_git_full_state)")" == "(✓)" ]]
}

@test "git_full_state segment shows the nonzero counts in order, one space apart" {
    GIT_IN_REPO=1 GIT_STAGED=2 GIT_MODIFIED=0 GIT_UNTRACKED=3 GIT_STASH=1 GIT_CONFLICTS=4
    [[ "$(plain "$(_ps_seg_git_full_state)")" == "(+2 ?3 ⚑1 ⚠4)" ]]
    GIT_STAGED=0 GIT_UNTRACKED=0 GIT_STASH=0 GIT_CONFLICTS=0 GIT_MODIFIED=5
    [[ "$(plain "$(_ps_seg_git_full_state)")" == "(~5)" ]]
}

@test "pwd segment truncation keeps whole characters when they reach the cut" {
    long=$(printf 'é%.0s' {1..40})
    mkdir -p "$BATS_TEST_TMPDIR/$long"
    cd "$BATS_TEST_TMPDIR/$long"
    [[ "$(_ps_seg_pwd)" == "…$(printf 'é%.0s' {1..32})" ]]
}

@test "pwd segment collapses \$HOME only at a path boundary" {
    HOME="$BATS_TEST_TMPDIR/a"
    mkdir -p "$HOME/sub" "${HOME}2"
    cd "${HOME}2"
    [[ "$(_ps_seg_pwd)" != "~"* ]]
    cd "$HOME/sub"
    [[ "$(_ps_seg_pwd)" == "~/sub" ]]
}

@test "disk collector shows usage at 90% and above" {
    mkdir "$BATS_TEST_TMPDIR/bin"
    printf '#!/bin/sh\necho "Filesystem 1024-blocks Used Available Capacity Mounted on"\necho "/dev/x 100 95 5 95%% /"\n' \
        > "$BATS_TEST_TMPDIR/bin/df"
    chmod +x "$BATS_TEST_TMPDIR/bin/df"
    PATH="$BATS_TEST_TMPDIR/bin:$PATH" _ps_collect_disk
    [[ "$(plain "$(_ps_seg_disk)")" == "⛁95%" ]]
}

@test "disk collector gives up on a df that hangs (a stuck network mount)" {
    mkdir "$BATS_TEST_TMPDIR/bin"
    printf '#!/bin/sh\nexec sleep 10\n' > "$BATS_TEST_TMPDIR/bin/df"
    chmod +x "$BATS_TEST_TMPDIR/bin/df"
    SECONDS=0
    PATH="$BATS_TEST_TMPDIR/bin:$PATH" _ps_collect_disk || true
    (( SECONDS < 3 ))
    [ -z "$_PS_DISK_CACHE_VAL" ]
}

@test "pbs_nodes: counts unique nodes, and its locals are correctly typed" {
    nodefile="$BATS_TEST_TMPDIR/nodes"
    printf 'n1\nn1\nn2\nn3\nn3\nn3\n' > "$nodefile"
    PBS_NODEFILE="$nodefile"
    [ "$(_ps_seg_pbs_nodes)" = "3 nodes" ]
}

@test "pbs_nodes: does not declare its scalar locals as associative arrays" {
    # `local -A seen=() line n=0` would apply -A to all three names.
    run grep -A6 '^_ps_seg_pbs_nodes()' "$DOTFILES_ROOT/segments/hpc.sh"
    [ "$status" -eq 0 ]   # the function is found, so the check below means something
    [[ "$output" != *'local -A seen=() line'* ]]
}

# ── Registration and expansion: prompt_segment, _ps_expand ──────────────

@test "prompt_segment: registering N segments forks the sort at most once, not N times" {
    run bash -c "
        source '$DOTFILES_ROOT/prompt.sh'
        _t() { :; }
        for i in \$(seq 1 10); do prompt_segment \"seg\$i\" _t; done
        echo \"dirty_after_registering=\$_PS_SEGS_DIRTY\"
        _ps_resort_segments
        echo \"dirty_after_one_resort=\$_PS_SEGS_DIRTY\"
        echo \"sorted_count=\${#_PS_SEGS_SORTED[@]}\"
    "
    [[ "$output" == *"dirty_after_registering=1"* ]]
    [[ "$output" == *"dirty_after_one_resort=0"* ]]
    # >=10: includes whatever built-in-adjacent state exists in a fresh source
    [[ "$output" =~ sorted_count=([0-9]+) ]]
    [ "${BASH_REMATCH[1]}" -ge 10 ]
}

@test "_ps_expand: a segment's own output is never re-scanned for other tokens" {
    _test_emitter() { printf 'value@victimTAIL'; }
    _test_victim()  { printf 'SHOULD_NOT_APPEAR'; }
    prompt_segment emitter_longname _test_emitter
    prompt_segment victim           _test_victim

    out="$(_ps_expand '@emitter_longname' 100)"
    [ "$out" = 'value@victimTAIL' ]
}

@test "_ps_expand: an unmatched bare @ passes through literally" {
    [ "$(_ps_expand 'email@example.com' 100)" = "email@example.com" ]
}

@test "_ps_expand: longest-match-first still resolves a real prefix collision" {
    _test_git() { printf 'SHORT'; }
    _test_git_branch() { printf 'LONG'; }
    prompt_segment git         _test_git
    prompt_segment git_branch  _test_git_branch
    [ "$(_ps_expand '@git_branch' 100)" = "LONG" ]
}

@test "_ps_expand: works when called directly, without prompt_build having run first" {
    _test_direct() { printf 'DIRECT'; }
    prompt_segment direct _test_direct
    # No prompt_build call before this — _ps_expand must not depend on it.
    [ "$(_ps_expand '@direct' 100)" = "DIRECT" ]
}

@test "PS_DEBUG_SEGMENTS: a failing segment's stderr is surfaced, not swallowed" {
    run bash -c "
        source '$DOTFILES_ROOT/prompt.sh'
        _test_broken() { echo boom >&2; return 1; }
        prompt_segment broken _test_broken
        PS_DEBUG_SEGMENTS=1 _ps_expand '@broken' 100
    "
    [[ "$output" == *boom* ]]
    [[ "$output" == *'segment "broken"'* ]]
}

@test "PS_DEBUG_SEGMENTS unset: a failing segment stays silent (default behavior unchanged)" {
    _test_broken() { echo "boom" >&2; return 1; }
    prompt_segment broken _test_broken
    run _ps_expand '@broken' 100
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}
