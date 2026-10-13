# lib/cmd_timer.sh: the command timer's arithmetic, and when it claims
# the DEBUG trap.

load test_helper

setup() {
    ROOT="$DOTFILES_ROOT"
}

@test "cmd_timer: elapsed is 0 when never armed" {
    source "$ROOT/lib/cmd_timer.sh"
    cmd_timer_elapsed
    [ "$_CMD_TIMER_ELAPSED" -eq 0 ]
}

@test "cmd_timer: arm records a start time on the next DEBUG fire" {
    source "$ROOT/lib/cmd_timer.sh"
    cmd_timer_arm
    _cmd_timer_preexec        # simulate the DEBUG trap firing once
    [ "$_CMD_TIMER_START" -ge 0 ]
    [ "$_CMD_TIMER_ARMED" -eq 0 ]
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
