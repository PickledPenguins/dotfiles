#!/usr/bin/env bash
# Toolkit version: 0.1.6
# ════════════════════════════════════════════════════════════════════════════
# segments/identity.sh — who and where: user, host, root marker, directory
#
# Sourced by prompt.sh; not usable on its own. Register a segment with
#   prompt_segment <name> <function>
# No collected data: each segment reads the environment directly.
#
# Segments: _ps_seg_user  _ps_seg_host  _ps_seg_user_host  _ps_seg_root
#           _ps_seg_pwd
# ════════════════════════════════════════════════════════════════════════════

_ps_seg_user()      { printf '%s'    "${USER:-$(id -un)}"; }
# Short hostname, domain stripped.
_ps_seg_host()      { printf '%s'    "${HOSTNAME%%.*}"; }
# Plain user@host, domain stripped. See prompt_example.sh for a colored variant.
_ps_seg_user_host() { printf '%s@%s' "${USER:-$(id -un)}" "${HOSTNAME%%.*}"; }

# Root/privileged-shell indicator — silent for normal users. $EUID is a
# bash-managed, read-only builtin; nothing in the environment can spoof it.
_ps_seg_root() {
    (( EUID == 0 )) || return
    printf '%s⚡%s' "$C_BRED" "$C_R"
}

# Working directory — $HOME collapsed to ~, capped at 35 visible chars.
# Directory names may legally contain control bytes and escape sequences;
# strip both before they can reach PS1. Truncation then uses str_width/cut
# (code-point aware) instead of ${#p}/${p: -N}, which count/slice by byte
# and can cut a multi-byte character in half outside a UTF-8 locale.
_ps_seg_pwd() {
    local p="${PWD/#$HOME/\~}"
    p=$(strip_ansi "$p")
    p=$(tr -d '\000-\037\177' <<< "$p")
    local w; w=$(str_width "$p")
    (( w > 35 )) && p="…$(LC_ALL=C.UTF-8 cut -c "$(( w - 31 ))-" <<< "$p")"
    printf '%s' "$p"
}
