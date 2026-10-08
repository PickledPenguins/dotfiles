#!/usr/bin/env bash
# Toolkit version: 0.1.7
# ════════════════════════════════════════════════════════════════════════════
# segments/shell.sh — this shell's surroundings: tmux, X display, ssh,
# python and conda environments, background jobs, nesting depth
#
# Sourced by prompt.sh; not usable on its own. No collected data: each
# segment reads the environment directly.
#
# Segments: _ps_seg_tmux  _ps_seg_display  _ps_seg_ssh  _ps_seg_venv
#           _ps_seg_conda  _ps_seg_jobs  _ps_seg_shlvl
# ════════════════════════════════════════════════════════════════════════════

# tmux session:window.pane, sanitized (session names are user-settable).
_ps_seg_tmux() {
    [[ -z "${TMUX-}" ]] && return
    local info; info=$(tmux display-message -p '#S:#I.#P' 2>/dev/null) || return
    info=$(strip_ansi "$info")               # session names are user-settable
    info=$(tr -d '\000-\037\177' <<< "$info")
    printf '⧉ %s' "$info"
}

# $DISPLAY value, indicating X11 forwarding is active.
_ps_seg_display() { [[ -n "${DISPLAY-}" ]] && printf '%s' "$DISPLAY"; }

# Marker shown when this shell arrived over SSH.
_ps_seg_ssh()     { [[ -n "${SSH_CLIENT-}" || -n "${SSH_TTY-}" ]] && printf '⇄ ssh'; }

# Active Python virtualenv name in parentheses.
_ps_seg_venv()    { [[ -n "${VIRTUAL_ENV-}" ]] && printf '(%s)' "$(basename "$VIRTUAL_ENV")"; }

# Count of background jobs in this shell, silent when there are none.
_ps_seg_jobs() {
    local -a j; mapfile -t j < <(jobs 2>/dev/null)
    (( ${#j[@]} > 0 )) && printf '⚙ %d' "${#j[@]}"
}

# Active conda environment in parentheses, silent for base.
_ps_seg_conda() {
    [[ -z "${CONDA_DEFAULT_ENV-}" || "$CONDA_DEFAULT_ENV" == "base" ]] && return
    printf '(%s)' "$CONDA_DEFAULT_ENV"
}

# ⬇N nesting depth, silent in a top-level shell.
_ps_seg_shlvl() {
    (( ${SHLVL:-1} > 1 )) && printf '%s⬇%d%s' "$C_YELLOW" "$SHLVL" "$C_R"
}
