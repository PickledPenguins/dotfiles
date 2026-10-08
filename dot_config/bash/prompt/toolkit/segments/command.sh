#!/usr/bin/env bash
# Toolkit version: 0.1.11
# ════════════════════════════════════════════════════════════════════════════
# segments/command.sh — the last command's result and duration, and the
# clock
#
# Sourced by prompt.sh; not usable on its own.
#
# Segments:  _ps_seg_exit  _ps_seg_cmd_time  _ps_seg_time
# Collector: cmd_time (every prompt). It installs lib/cmd_timer.sh's DEBUG
#            trap the first time it runs, so a layout that never shows
#            @cmd_time never claims the trap.
# Settings:  prompt_cmd_time_threshold <seconds>
# ════════════════════════════════════════════════════════════════════════════

# cmd_timer.sh is standalone and doesn't know it's being used by a prompt,
# so its own DEBUG-trap opt-out is CMD_TIMER_SKIP_TRAP. PS_SKIP_DEBUG_TRAP
# is kept working as an alias so existing configs don't silently break.
[[ -n "${PS_SKIP_DEBUG_TRAP-}" && -z "${CMD_TIMER_SKIP_TRAP-}" ]] && CMD_TIMER_SKIP_TRAP=1
source "${_PS_ROOT:?segments/command.sh is sourced by prompt.sh}/lib/cmd_timer.sh"

# Collect: claim the DEBUG trap (once), compute how long the last command
# ran, and arm the timer for the next one. Arming here rather than at the
# end of prompt_build changes nothing: the DEBUG trap does not fire inside
# a function, so the next fire is still the next top-level command.
_ps_collect_cmd_time() {
    cmd_timer_install
    cmd_timer_elapsed
    cmd_timer_arm
}
prompt_collector cmd_time 0 _ps_collect_cmd_time

# Last command's exit status: a checkmark, or a cross plus the code.
_ps_seg_exit() {
    if (( ${PROMPT_LAST_EXIT:-0} == 0 )); then
        printf '%s✓%s'    "$C_GREEN" "$C_R"
    else
        printf '%s✗ %d%s' "$C_RED" "${PROMPT_LAST_EXIT:-0}" "$C_R"
    fi
}

# Current wall-clock time, HH:MM.
_ps_seg_time() { date '+%H:%M'; }

# ── Command duration ──────────────────────────────────────────────────────
declare -gi _PS_CMD_TIME_MIN=2

# Duration of the last command, shown only past _PS_CMD_TIME_MIN seconds.
_ps_seg_cmd_time() {
    (( _CMD_TIMER_ELAPSED >= _PS_CMD_TIME_MIN )) || return
    local s=$_CMD_TIMER_ELAPSED
    (( s >= 3600 )) && { printf '%dh%dm%ds' $(( s/3600 )) $(( (s%3600)/60 )) $(( s%60 )); return; }
    (( s >=   60 )) && { printf '%dm%ds'    $(( s/60 ))   $(( s%60 ));         return; }
    printf '%ds' "$s"
}

# Set the minimum seconds a command must run before @cmd_time displays it.
prompt_cmd_time_threshold() { _PS_CMD_TIME_MIN="${1:-2}"; }

prompt_segment_needs _ps_seg_cmd_time cmd_time
