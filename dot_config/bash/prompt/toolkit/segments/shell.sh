#!/usr/bin/env bash
# Toolkit version: 0.1.16
# ════════════════════════════════════════════════════════════════════════════
# segments/shell.sh — this shell's surroundings: tmux, X display, ssh,
# python and conda environments, background jobs, nesting depth
#
# Sourced by prompt.sh; not usable on its own. No collected data: each
# segment reads the environment directly.
#
# Segments: _ps_seg_tmux  _ps_seg_display  _ps_seg_ssh  _ps_seg_venv
#           _ps_seg_conda  _ps_seg_jobs  _ps_seg_shlvl
# Helper:   _ps_tmux_into VAR, the tmux segment's text without a subshell
# ════════════════════════════════════════════════════════════════════════════

# _ps_tmux_into VAR: ⧉ and this pane's session:window.pane into VAR,
# sanitized (session names are user-settable). Fails, VAR untouched,
# outside tmux or when the server does not answer, so a layout can tell an
# empty segment from a shown one without a subshell of its own.
_ps_tmux_into() {
    [[ -n "${TMUX-}" ]] || return 1
    local info; info=$(tmux display-message -p '#S:#I.#P' 2>/dev/null) || return 1
    _ps_sanitize_into info
    printf -v "$1" '⧉ %s' "$info"
}

# tmux session:window.pane, sanitized.
_ps_seg_tmux() { local s; _ps_tmux_into s && printf '%s' "$s"; return 0; }

# $DISPLAY value, indicating X11 forwarding is active.
_ps_seg_display() { [[ -n "${DISPLAY-}" ]] && printf '%s' "$DISPLAY"; }

# Marker shown when this shell arrived over SSH.
_ps_seg_ssh()     { [[ -n "${SSH_CLIENT-}" || -n "${SSH_TTY-}" ]] && printf '⇄ ssh'; }

# Active Python virtualenv name in parentheses.
_ps_seg_venv() {
    [[ -n "${VIRTUAL_ENV-}" ]] || return 0
    local v=${VIRTUAL_ENV%/}
    printf '(%s)' "${v##*/}"
}

# Count of background jobs in this shell, silent when there are none.
_ps_seg_jobs() {
    local -a j; mapfile -t j < <(jobs 2>/dev/null)
    (( ${#j[@]} > 0 )) && printf '⚙%d' "${#j[@]}"
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
