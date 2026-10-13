#!/usr/bin/env bats
# The collector registry: prompt_collector, prompt_segment_needs,
# layout-driven planning, TTLs, collected data reaching the parent shell,
# the segments/ split, and install.sh copying segments/.

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

@test "collector gating: a built-in segment registered under a CUSTOM alias still arms its collector" {
    source "$ROOT/prompt.sh"
    prompt_segment gpu_util   _ps_seg_gpu          # not named "gpu"
    prompt_segment branchname _ps_seg_git_branch   # not prefixed "git_"
    prompt_segment freespace  _ps_seg_disk         # not named "disk"
    prompt_segment busy       _ps_seg_load         # not named "load"
    prompt_row r '@gpu_util @branchname @freespace @busy'
    prompt_layout r
    _ps_plan_collectors
    [ "${_PS_ACTIVE_COLLECTORS[*]}" = "git load disk gpu" ]
}

@test "prompt_segment_needs: a custom segment can declare its own data dependency" {
    source "$ROOT/prompt.sh"
    _my_custom_branch() { printf '%s' "$GIT_BRANCH"; }
    prompt_segment_needs _my_custom_branch git
    prompt_segment mine _my_custom_branch
    prompt_row r '@mine'
    prompt_layout r
    _ps_plan_collectors
    [ "${_PS_ACTIVE_COLLECTORS[*]}" = "git" ]
}

@test "prompt_segment_needs: rejects an unknown collector name" {
    source "$ROOT/prompt.sh"
    _x() { :; }
    run prompt_segment_needs _x notathing
    [ "$status" -ne 0 ]
    [[ "$output" == *'unknown collector "notathing"'* ]]
}

@test "a shown segment with no needs arms no collector" {
    source "$ROOT/prompt.sh"
    _plain() { printf 'hi'; }
    prompt_segment plain _plain
    prompt_row r '@plain'
    prompt_layout r
    _ps_plan_collectors
    [ "${#_PS_ACTIVE_COLLECTORS[@]}" -eq 0 ]
}

@test "gpu/disk/load: data collection survives into the parent shell (not lost to the segment's subshell)" {
    fakebin="$(mktemp -d)"
    cat > "$fakebin/nvidia-smi" <<'EOF'
#!/usr/bin/env bash
echo "$$" >> "$NVIDIA_SMI_CALL_LOG"
echo "55"
EOF
    chmod +x "$fakebin/nvidia-smi"
    calllog="$(mktemp)"
    script="$(mktemp)"
    cat > "$script" <<'EOF'
root="$1"; fakebin="$2"; calllog="$3"
export PATH="$fakebin:$PATH" NVIDIA_SMI_CALL_LOG="$calllog"
export TMUX="" COLUMNS=100
source "$root/prompt.sh"
prompt_segment gpu _ps_seg_gpu
prompt_row r '@gpu'
prompt_layout r      # prompt_build returns immediately with no rows configured
for i in 1 2 3 4 5; do prompt_build; done
echo "val=$_PS_GPU_CACHE_VAL age=$(cache_age collector:gpu)"
EOF

    run bash "$script" "$ROOT" "$fakebin" "$calllog"
    [[ "$output" == *"val=55"* ]]
    # age is whole seconds since the touch, 1 when the builds cross a second
    # boundary; -1 would mean the touch was lost to the segment's subshell.
    [[ "$output" == *"age="[01] ]]
    [ "$(wc -l < "$calllog")" -eq 1 ]   # the expensive call ran exactly once across 5 renders
    rm -rf "$fakebin" "$calllog" "$script"
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
