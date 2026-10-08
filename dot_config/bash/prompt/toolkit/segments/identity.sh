#!/usr/bin/env bash
# Toolkit version: 0.1.12
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

# Working directory — $HOME collapsed to ~ (only at a path boundary, so
# /home/a2 stays as it is for HOME=/home/a), capped at 35 visible chars.
# Directory names may legally contain control bytes and escape sequences;
# strip both before they can reach PS1. Truncation drops whole characters
# from the front: under LC_ALL=C each step removes one byte and then the
# UTF-8 continuation bytes after it. `cut -c` counted bytes, not
# characters, even in a UTF-8 locale, and cut accented names in half.
_ps_seg_pwd() {
    local p="$PWD" i
    if [[ -n "$HOME" && "$PWD" == "$HOME" ]]; then p='~'
    elif [[ -n "$HOME" && "$PWD" == "$HOME"/* ]]; then p="~${PWD#"$HOME"}"
    fi
    p=$(strip_ansi "$p")
    p=$(tr -d '\000-\037\177' <<< "$p")
    local w; w=$(str_width "$p")
    if (( w > 35 )); then
        local LC_ALL=C
        for (( i = w - 32; i > 0; i-- )); do
            p="${p:1}"
            while [[ "$p" == [$'\x80'-$'\xbf']* ]]; do p="${p:1}"; done
        done
        p="…$p"
    fi
    printf '%s' "$p"
}
