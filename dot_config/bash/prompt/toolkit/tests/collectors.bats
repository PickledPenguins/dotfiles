#!/usr/bin/env bats
# Tests for v0.1.5: the collector registry (prompt_collector,
# prompt_segment_needs, layout-driven planning, TTLs), the segments/ split,
# cmd_timer_install, and install.sh copying segments/.

load test_helper
bats_require_minimum_version 1.5.0   # run -N

setup() {
    ROOT="$DOTFILES_ROOT"
}

# A collector that counts its own runs in a global, plus a segment that
# needs it. Call after sourcing prompt.sh.
_counting_collector() {
    declare -gi RUNS=0
    _count() { RUNS+=1; }
    _show() { printf 'x'; }
    prompt_collector counter "$1" _count
    prompt_segment_needs _show counter
    prompt_segment show _show
}

# ── Planning: only collectors a shown row needs run ──────────────────────

@test "a collector runs only while a shown row uses a segment that needs it" {
    source "$ROOT/prompt.sh"
    _counting_collector 0
    prompt_row with '@show'
    prompt_row without 'plain text'
    prompt_layout without
    prompt_build; prompt_build
    [ "$RUNS" -eq 0 ]
    prompt_layout with
    prompt_build
    [ "$RUNS" -eq 1 ]
}

@test "a row defined but not in the layout does not arm its collectors" {
    source "$ROOT/prompt.sh"
    _counting_collector 0
    prompt_row shown 'plain'
    prompt_row hidden '@show'
    prompt_layout shown
    prompt_build
    [ "$RUNS" -eq 0 ]
}

@test "redefining a shown row replans the collectors" {
    source "$ROOT/prompt.sh"
    _counting_collector 0
    prompt_row r 'plain'
    prompt_layout r
    prompt_build
    [ "$RUNS" -eq 0 ]
    prompt_row r '@show'
    prompt_build
    [ "$RUNS" -eq 1 ]
}

@test "needs may be declared after the segment is registered and shown" {
    source "$ROOT/prompt.sh"
    declare -gi RUNS=0
    _count() { RUNS+=1; }
    _show() { printf 'x'; }
    prompt_collector counter 0 _count
    prompt_segment show _show
    prompt_row r '@show'
    prompt_layout r
    prompt_build
    [ "$RUNS" -eq 0 ]
    prompt_segment_needs _show counter
    prompt_build
    [ "$RUNS" -eq 1 ]
}

@test "a token that is only a prefix of a segment name arms nothing" {
    source "$ROOT/prompt.sh"
    _counting_collector 0
    prompt_row r '@sho'   # not @show: rendered literally, so nothing to collect
    prompt_layout r
    prompt_build
    [ "$RUNS" -eq 0 ]
}

@test "@fill does not arm a segment whose name is a prefix of fill" {
    source "$ROOT/prompt.sh"
    declare -gi RUNS=0
    _count() { RUNS+=1; }
    _fi() { printf 'x'; }
    prompt_collector counter 0 _count
    prompt_segment_needs _fi counter
    prompt_segment fi _fi
    prompt_row r 'a@fillb'
    prompt_layout r
    prompt_build
    [ "$RUNS" -eq 0 ]
}

@test "the collector plan is reused until a registration changes it" {
    source "$ROOT/prompt.sh"
    _counting_collector 0
    prompt_row r 'plain'
    prompt_layout r
    prompt_build
    _PS_ROWS[r]='@show'   # bypasses prompt_row, so nothing marks the plan stale
    prompt_build
    [ "$RUNS" -eq 0 ]
}

# ── TTLs and run order ───────────────────────────────────────────────────

@test "TTL 0: the collector runs on every prompt" {
    source "$ROOT/prompt.sh"
    _counting_collector 0
    prompt_row r '@show'
    prompt_layout r
    for _ in 1 2 3; do prompt_build; done
    [ "$RUNS" -eq 3 ]
}

@test "TTL N: the collector runs once, then not again until N seconds pass" {
    source "$ROOT/prompt.sh"
    _counting_collector 1
    prompt_row r '@show'
    prompt_layout r
    for _ in 1 2 3; do prompt_build; done
    [ "$RUNS" -eq 1 ]
    sleep 1.2
    prompt_build
    [ "$RUNS" -eq 2 ]
}

@test "collectors run in registration order; re-registering keeps the place" {
    source "$ROOT/prompt.sh"
    ORDER=""
    _a() { ORDER+=a; }
    _b() { ORDER+=b; }
    _b2() { ORDER+=B; }
    _seg() { :; }
    prompt_collector ca 0 _a
    prompt_collector cb 0 _b
    prompt_collector ca 0 _a   # re-registered: stays first
    prompt_collector cb 0 _b2  # function replaced, place kept
    prompt_segment_needs _seg cb ca
    prompt_segment seg _seg
    prompt_row r '@seg'
    prompt_layout r
    prompt_build
    [ "$ORDER" = "aB" ]
}

@test "a TTL with a leading zero is decimal, not octal" {
    source "$ROOT/prompt.sh"
    _f() { :; }
    prompt_collector c 08 _f
    [ "${_PS_COLLECTOR_TTL[c]}" -eq 8 ]
}

@test "a failing collector does not stop the prompt rendering under errexit" {
    run bash -c '
        source "$1/prompt.sh"
        set -e
        _fail() { return 1; }
        _seg() { printf rendered; }
        prompt_collector failing 0 _fail
        prompt_segment_needs _seg failing
        prompt_segment seg _seg
        prompt_row r "@seg"
        prompt_layout r
        prompt_build
        printf "%s" "$PS1"
    ' _ "$ROOT"
    [ "$status" -eq 0 ]
    [ "$output" = "rendered" ]
}

# ── prompt_collector / prompt_segment_needs argument checks ──────────────

@test "prompt_collector: wrong argument count is a usage error" {
    source "$ROOT/prompt.sh"
    run prompt_collector onlyname
    [ "$status" -eq 1 ]
    [[ "$output" == *"usage: <name> <ttl_seconds> <function>"* ]]
}

@test "prompt_collector: rejects a name that is not an identifier" {
    source "$ROOT/prompt.sh"
    _f() { :; }
    run prompt_collector 'bad name' 0 _f
    [ "$status" -eq 1 ]
    [[ "$output" == *'bad name "bad name"'* ]]
}

@test "prompt_collector: rejects a TTL that is not a whole number" {
    source "$ROOT/prompt.sh"
    _f() { :; }
    run prompt_collector c 1.5 _f
    [ "$status" -eq 1 ]
    [[ "$output" == *'ttl "1.5" is not a whole number'* ]]
}

@test "prompt_collector: rejects an undefined function" {
    source "$ROOT/prompt.sh"
    run prompt_collector c 0 _no_such_function
    [ "$status" -eq 1 ]
    [[ "$output" == *'"_no_such_function" is not a defined function'* ]]
}

@test "prompt_segment_needs: a collector must be registered first" {
    source "$ROOT/prompt.sh"
    _seg() { :; }
    run prompt_segment_needs _seg later
    [ "$status" -eq 1 ]
    [[ "$output" == *'unknown collector "later" (registered: cmd_time git load disk gpu)'* ]]
}

@test "prompt_segment_needs: needs at least one collector" {
    source "$ROOT/prompt.sh"
    run prompt_segment_needs _seg
    [ "$status" -eq 1 ]
    [[ "$output" == *"usage: <function> <collector>..."* ]]
}

# ── Built-in segments live in segments/ ──────────────────────────────────

@test "sourcing prompt.sh registers the built-in collectors in run order" {
    source "$ROOT/prompt.sh"
    [ "${_PS_COLLECTOR_ORDER[*]}" = "cmd_time git load disk gpu" ]
    [ "${_PS_COLLECTOR_TTL[load]}" -eq 10 ]
    [ "${_PS_COLLECTOR_TTL[disk]}" -eq 30 ]
    [ "${_PS_COLLECTOR_TTL[gpu]}" -eq 10 ]
}

@test "a segment file sourced on its own fails with a message naming prompt.sh" {
    # ${_PS_ROOT:?...} failing in a non-interactive shell exits 127.
    run -127 bash -c 'source "$1/segments/git.sh"' _ "$ROOT"
    [[ "$output" == *"segments/git.sh is sourced by prompt.sh"* ]]
}

@test "prompt_debug lists collectors and which ones are active" {
    source "$ROOT/prompt.sh"
    prompt_segment branch _ps_seg_git_branch
    prompt_row r '@branch'
    prompt_layout r
    run prompt_debug
    [[ "$output" == *"@branch"*"(needs git)"* ]]
    [[ "$output" =~ git\ +ttl=0\ +active=yes ]]
    [[ "$output" =~ gpu\ +ttl=10\ +active=no ]]
}

# ── cmd_timer_install: the DEBUG trap is claimed only when needed ────────
# Each runs in its own bash: bats owns the DEBUG trap of the test process.

_trap_after() {   # $1: layout row template  $2...: env assignments
    local row="$1"; shift
    env -u CMD_TIMER_SKIP_TRAP "$@" bash -c '
        source "$1/prompt.sh"
        prompt_segment cmd_time _ps_seg_cmd_time
        prompt_segment pwd _ps_seg_pwd
        printf "after-source=[%s]\n" "$(trap -p DEBUG)"
        prompt_row r "$2"
        prompt_layout r
        prompt_build
        printf "after-build=[%s]\n" "$(trap -p DEBUG)"
    ' _ "$ROOT" "$row"
}

@test "cmd_timer: sourcing prompt.sh claims no DEBUG trap" {
    run _trap_after '@cmd_time'
    [[ "$output" == *"after-source=[]"* ]]
}

@test "cmd_timer: the first prompt showing @cmd_time claims the DEBUG trap" {
    run _trap_after '@cmd_time'
    [[ "$output" == *"after-build=[trap -- '_cmd_timer_preexec' DEBUG]"* ]]
}

@test "cmd_timer: a layout without @cmd_time never claims the DEBUG trap" {
    run _trap_after '@pwd'
    [[ "$output" == *"after-build=[]"* ]]
}

@test "cmd_timer: CMD_TIMER_SKIP_TRAP keeps the DEBUG trap unclaimed" {
    run _trap_after '@cmd_time' CMD_TIMER_SKIP_TRAP=1
    [[ "$output" == *"after-build=[]"* ]]
}

@test "cmd_timer: PS_SKIP_DEBUG_TRAP is still an alias for CMD_TIMER_SKIP_TRAP" {
    run _trap_after '@cmd_time' PS_SKIP_DEBUG_TRAP=1
    [[ "$output" == *"after-build=[]"* ]]
}

@test "cmd_timer_install: a second call leaves a later trap alone" {
    run env -u CMD_TIMER_SKIP_TRAP bash -c '
        source "$1/lib/cmd_timer.sh"
        cmd_timer_install
        trap ":" DEBUG
        cmd_timer_install
        trap -p DEBUG
    ' _ "$ROOT"
    [ "$output" = "trap -- ':' DEBUG" ]
}

# ── install.sh ───────────────────────────────────────────────────────────

@test "install.sh: the installed copy includes segments/ and renders a prompt" {
    target="$BATS_TEST_TMPDIR/installed"
    run "$ROOT/install.sh" "$target"
    [ "$status" -eq 0 ]
    [ -f "$target/segments/git.sh" ]
    run bash -c '
        source "$1/prompt.sh"
        prompt_segment exit _ps_seg_exit
        prompt_row r "@exit"
        prompt_layout r
        prompt_build
        printf "%s" "$PS1"
    ' _ "$target"
    [ "$status" -eq 0 ]
    [[ "$(plain "$output")" == "✓" ]]
}
