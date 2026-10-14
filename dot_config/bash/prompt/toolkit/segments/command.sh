#!/usr/bin/env bash
# Toolkit version: 0.1.14
# ════════════════════════════════════════════════════════════════════════════
# segments/command.sh — the last command's result, and the clock
#
# Sourced by prompt.sh; not usable on its own.
#
# Segments:  _ps_seg_exit  _ps_seg_time
# ════════════════════════════════════════════════════════════════════════════

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
