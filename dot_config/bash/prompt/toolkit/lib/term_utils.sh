#!/usr/bin/env bash
# Toolkit version: 0.1.14
# ════════════════════════════════════════════════════════════════════════════
# lib/term_utils.sh — Terminal string utilities
#
# Utilities for measuring and constructing terminal strings that may contain
# ANSI escape sequences or multi-byte Unicode characters. All three
# functions were originally developed for the prompt builder but are fully
# general — useful in any bash script that does terminal layout work.
#
# Usage:
#   source lib/term_utils.sh
#   clean=$(strip_ansi "$colored")        # remove ANSI codes
#   strip_ansi -v clean "$colored"        # the same, without a subshell
#   w=$(str_width "$line")                # visible column count
#   str_width -v w "$line"                # the same, without a subshell
#   sep=$(str_repeat "─" 40)              # draw a separator
#   str_repeat -v sep "─" 40              # the same, without a subshell
#
# Functions:
#   strip_ansi  [-v VAR] <string>  — remove ANSI escapes and readline \001..\002
#   str_width   [-v VAR] <string>  — visible column count (Unicode + locale safe)
#   str_repeat  [-v VAR] <char> <N>  — repeat a character N times (Unicode safe)
#
# Notes:
#   • strip_ansi and str_repeat are pure bash (regex loop / parameter
#     expansion) — no subprocess, as of v0.1.2. A prompt with a full row of
#     colored segments calls these dozens of times per render; each used to
#     be a sed or awk fork, which is real, measurable latency on every
#     keystroke, not just a style concern.
#   • str_width is pure bash too, as of v0.1.7: it counts the bytes that
#     start a UTF-8 character, under LC_ALL=C. The earlier
#     `LC_ALL=C.UTF-8 wc -m` forked once per non-ASCII string and counted
#     bytes wherever C.UTF-8 is missing (RHEL/CentOS 7), so every ─ counted
#     as 3 and every @fill row came out short on exactly the HPC login
#     nodes this design is for.
#   • -v VAR assigns the result to VAR, as printf -v does. $(...) forks a
#     subshell, 1 to 3 ms in an interactive bash, so code that runs on every
#     prompt passes -v.
# ════════════════════════════════════════════════════════════════════════════

[[ -n "${_TERM_UTILS_SH_LOADED-}" ]] && return 0
readonly _TERM_UTILS_SH_LOADED=1

# Remove readline \001..\002 markers and ANSI escape sequences from a string:
# CSI sequences (color, cursor movement, erase — any letter terminator, not
# just SGR/erase-line) and OSC sequences (e.g. terminal title, BEL-terminated).
# Pure bash: repeatedly finds the leftmost match with the builtin regex
# engine and splices it out — same three patterns the old sed script used,
# no subprocess.
strip_ansi() {
    local _sa_var=""
    [[ "$1" == -v ]] && { _sa_var=$2; shift 2; }
    local _sa_s="$1" _sa_out=""
    local _sa_re=$'\001[^\002]*\002|\033\\[[0-9;]*[A-Za-z]|\033\\][^\007]*\007'
    while [[ "$_sa_s" =~ $_sa_re ]]; do
        _sa_out+="${_sa_s%%"${BASH_REMATCH[0]}"*}"
        _sa_s="${_sa_s#*"${BASH_REMATCH[0]}"}"
    done
    # shellcheck disable=SC2059  # the format is '%s', and the expansion is -v VAR or nothing
    printf ${_sa_var:+-v "$_sa_var"} '%s' "${_sa_out}${_sa_s}"
}

# Count the visible Unicode columns (code points) in a string.
#
# Fast path: pure-ASCII strings have ${#} == visible width in any locale.
# Otherwise, under LC_ALL=C (which always exists) bash counts bytes, so
# delete the UTF-8 continuation bytes (0x80-0xBF) and count what is left:
# one lead byte per code point, whatever locales the machine has.
# Precondition: input must already be ANSI-free (run strip_ansi first) —
# escape bytes are not code points and would inflate the count.
str_width() {
    local _sw_var=""
    [[ "$1" == -v ]] && { _sw_var=$2; shift 2; }
    local _sw_s="$1"
    case "$_sw_s" in
        *[![:ascii:]]*)
            local LC_ALL=C
            _sw_s="${_sw_s//[$'\x80'-$'\xbf']/}" ;;
    esac
    # shellcheck disable=SC2059  # as in strip_ansi
    printf ${_sw_var:+-v "$_sw_var"} '%d' "${#_sw_s}"
}

# Repeat character $1 exactly $2 times.
# Pads a string of $2 spaces, then substitutes every space for $1. $1 is
# escaped as a LITERAL replacement first: bash's ${//pat/repl} treats an
# unescaped & in repl as "the matched text" (i.e. a space) — str_repeat '&'
# would silently produce spaces instead of ampersands without this. A
# multi-byte char like ─ (U+2500, 3 bytes in UTF-8) still inserts whole,
# once per space, same as the old awk version's per-character iteration.
str_repeat() {
    local _sr_var=""
    [[ "$1" == -v ]] && { _sr_var=$2; shift 2; printf -v "$_sr_var" '%s' ''; }
    local _sr_n="${2:-0}"
    (( _sr_n < 1 )) && return
    local _sr_pad; printf -v _sr_pad '%*s' "$_sr_n" ''
    local _sr_esc="${1//&/\\&}"
    # shellcheck disable=SC2059  # as in strip_ansi
    printf ${_sr_var:+-v "$_sr_var"} '%s' "${_sr_pad// /$_sr_esc}"
}
