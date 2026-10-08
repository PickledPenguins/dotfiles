#!/usr/bin/env bash
# Toolkit version: 0.1.10
# ════════════════════════════════════════════════════════════════════════════
# lib/cmd_timer.sh — Command-duration tracking via the DEBUG trap
#
# Tracks how long the last foreground command took. Nothing about this is
# prompt-specific — it's a general "how long did that take" utility for any
# bash tool that wants it without wrapping every command invocation.
#
# Usage:
#   source lib/cmd_timer.sh
#   cmd_timer_install         # claim the DEBUG trap (once; later calls no-op)
#   cmd_timer_arm             # call once, right after you display a prompt
#   …user's command runs…
#   cmd_timer_elapsed         # updates $_CMD_TIMER_ELAPSED; read the global
#                              # directly rather than $(...) to stay fork-free
#
# Sourcing installs nothing: the trap is claimed by cmd_timer_install, so a
# caller that never needs timing never pays for a DEBUG trap.
#
# Replaces any DEBUG trap already installed; it does not chain onto one
# (chaining broke bats-core's own trap and was removed in v0.1.1 — see the
# toolkit README's version history). When another tool owns the DEBUG trap
# (bats, bash-preexec), set CMD_TIMER_SKIP_TRAP=1 before cmd_timer_install
# runs, and lose only the timing.
#
# [v0.1.3] Clock source: EPOCHSECONDS (bash 5.0+) when available, since it
# can't be clobbered by an unrelated `SECONDS=0` elsewhere in the shell —
# a very ordinary idiom for timing something else. Falls back to $SECONDS
# on older bash; elapsed is clamped to >=0 there so a clock reset shows as
# 0s rather than a nonsensical negative duration.
# ════════════════════════════════════════════════════════════════════════════

[[ -n "${_CMD_TIMER_SH_LOADED-}" ]] && return 0
readonly _CMD_TIMER_SH_LOADED=1

declare -gi _CMD_TIMER_START=-1     # clock reading when the current command started (-1 = unset)
declare -gi _CMD_TIMER_ELAPSED=0    # seconds the last command ran
declare -gi _CMD_TIMER_ARMED=0      # 1 = next DEBUG fire records the start time

# Same clock-selection rationale as lib/cache.sh: EPOCHSECONDS (bash 5.0+)
# when available, since ordinary scripts don't reassign it the way they
# commonly reassign $SECONDS to time something unrelated.
declare -gi _CMD_TIMER_USE_EPOCH=0
(( BASH_VERSINFO[0] >= 5 )) && _CMD_TIMER_USE_EPOCH=1

# Fires before every shell command. When armed (a prompt was just shown),
# records the start time and disarms. Otherwise: one integer test, returns.
# Overhead when not armed: effectively free (~1 microsecond).
_cmd_timer_preexec() {
    (( _CMD_TIMER_ARMED )) || return
    _CMD_TIMER_ARMED=0
    (( _CMD_TIMER_USE_EPOCH )) && _CMD_TIMER_START=$EPOCHSECONDS || _CMD_TIMER_START=$SECONDS
}

declare -gi _CMD_TIMER_INSTALLED=0  # 1 = cmd_timer_install has run

# Claim the DEBUG trap for _cmd_timer_preexec, unless CMD_TIMER_SKIP_TRAP
# is set. Runs once per shell; later calls return at the first test, so a
# caller may run it before every prompt.
cmd_timer_install() {
    (( _CMD_TIMER_INSTALLED )) && return
    _CMD_TIMER_INSTALLED=1
    [[ -n "${CMD_TIMER_SKIP_TRAP-}" ]] && return
    trap '_cmd_timer_preexec' DEBUG
}

# Arm the timer: call once right after displaying a prompt, so the *next*
# command's start time gets recorded.
cmd_timer_arm() { _CMD_TIMER_ARMED=1; }

# Compute how long the last command took, into $_CMD_TIMER_ELAPSED.
# Pure arithmetic — zero subprocess cost. Call plainly, not via $(...),
# or you reintroduce the subshell fork this whole library exists to avoid.
cmd_timer_elapsed() {
    if (( _CMD_TIMER_START < 0 )); then
        _CMD_TIMER_ELAPSED=0
    else
        local now
        (( _CMD_TIMER_USE_EPOCH )) && now=$EPOCHSECONDS || now=$SECONDS
        _CMD_TIMER_ELAPSED=$(( now - _CMD_TIMER_START ))
        # $SECONDS fallback only: a mid-command SECONDS=0 elsewhere would
        # otherwise show as a negative duration.
        (( _CMD_TIMER_ELAPSED < 0 )) && _CMD_TIMER_ELAPSED=0
    fi
    _CMD_TIMER_START=-1
}
