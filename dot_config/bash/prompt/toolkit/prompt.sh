#!/usr/bin/env bash
# Toolkit version: 0.1.9
# ════════════════════════════════════════════════════════════════════════════
# prompt.sh — Composable bash prompt builder
# Architecture: Segment → Row → Layout → PS1
#
#   Segment  Named function writing content to stdout. Knows nothing about
#            layout or box style. Use C_* / PS_* vars for color.
#
#   Row      Named template string. Tokens:
#              @segname   expands to segment output (one @fill per row max)
#              @fill      fills remaining line width with the border char
#            Tokens have no end delimiter — avoid a segment name that is a
#            literal prefix of adjacent template text.
#
#   Layout   Ordered row list with optional box decoration.
#            Default (open):  last row is  ╰─content — cursor follows.
#            Closed (--closed): last row gets ╯, cursor drops to new line.
#
#   Collector  Named function that gathers data for segments (git state,
#            load average, command duration) into globals, in the shell's
#            own process. Runs in prompt_build only while a row the
#            layout shows uses a segment that needs it; TTL 0 runs it
#            every prompt, TTL N at most once per N seconds.
#
# This file is the engine. The built-in segments live in segments/, one
# file per topic, each holding its segment functions, its collectors and
# their needs declarations; all of them are sourced at the end of this
# file:
#   segments/identity.sh — user, host, root marker, directory
#   segments/command.sh  — exit status, command duration, clock
#   segments/git.sh      — branch, upstream, ahead/behind, status, stash
#   segments/shell.sh    — tmux, display, ssh, venv, conda, jobs, shlvl
#   segments/system.sh   — load, disk, gpu
#   segments/hpc.sh      — environment modules, PBS and Slurm jobs
#
# Library modules, from lib/ next to this file:
#   lib/term_utils.sh  — strip_ansi  str_width  str_repeat
#   lib/colors.sh      — C_* and PS_* color variables, c_fg/c_bg helpers
#   lib/cache.sh       — generic TTL bookkeeping (collector TTLs, git_info.sh)
#   lib/git_info.sh    — git state + mtime/TTL cache (sourced by segments/git.sh)
#   lib/cmd_timer.sh   — command duration (sourced by segments/command.sh)
#
# Setup — add to .bashrc:
#   source ~/.local/share/bash-prompt-toolkit/prompt.sh
#   source ~/.local/share/bash-prompt-toolkit/prompt_example.sh
# ════════════════════════════════════════════════════════════════════════════

[[ -n "${_PROMPT_SH_LOADED-}" ]] && return 0
readonly _PROMPT_SH_LOADED=1

# SECURITY: promptvars stays on, and every segment's output is escaped
# instead (_ps_escape_into, applied in _ps_expand). With promptvars on, bash
# expands $(...), backticks and ${...} in PS1 on every render; directory
# names, git branches, $VIRTUAL_ENV and tmux session names can all hold
# such text. Bash also decodes backslash escapes (\w, \[, \D{...}) in PS1
# whether or not promptvars is on, so turning it off never closed that
# half. It also broke other users of the option: kitty's shell integration
# puts $(...) in PS0, which printed literally with promptvars off.
shopt -s promptvars

# _ps_escape_into VAR — escape VAR's text in place so PS1 shows it as typed.
# Each \ becomes \\\\ and each $ or backtick gets \\ before it: bash's
# backslash decoding turns \\\\ into \\, \\$ into \$ (so root's # prompt
# sign cannot appear) and \\` into \`, then promptvars expansion, which
# runs in double-quote context, turns those into \, $ and `.
_ps_escape_into() {
    local v=${!1} bs='\\\\' dollar='\\$' tick='\\`'
    v=${v//\\/"$bs"}
    v=${v//\$/"$dollar"}
    v=${v//\`/"$tick"}
    printf -v "$1" '%s' "$v"
}

# _ps_unescape_into VAR — undo _ps_escape_into, to measure escaped text.
_ps_unescape_into() {
    local v=${!1} bs='\\\\' dollar='\\$' tick='\\`' one='\'
    v=${v//"$bs"/"$one"}
    v=${v//"$dollar"/\$}
    v=${v//"$tick"/\`}
    printf -v "$1" '%s' "$v"
}

# Source library modules relative to this file's location. _PS_ROOT stays
# set until the segment files at the bottom have been sourced.
_PS_ROOT="$(CDPATH='' cd -- "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${_PS_ROOT}/lib/cache.sh"
source "${_PS_ROOT}/lib/term_utils.sh"
source "${_PS_ROOT}/lib/colors.sh"
colors_init prompt   # switch C_* / PS_* to readline-safe \001..\002 format

# ps_fg/ps_bg — thin wrappers kept for any existing code using the old names
ps_fg() { c_fg "$@"; }
# Background-color escape — wrapper kept for code using the old name.
ps_bg() { c_bg "$@"; }

# ── Prompt engine state ────────────────────────────────────────────────────
declare -gA _PS_SEGS=()          # segment name → function name
declare -gA _PS_ROWS=()          # row name → template string
declare -ga _PS_ORDER=()         # row names in display order
declare -ga _PS_SEGS_SORTED=()   # segment names, longest-first (expansion order)
declare -g    _PS_BOX=0            # 1 = wrap rows in a unicode box
declare -g    _PS_CLOSED=0         # 1 = close box (╯) on last row; 0 = open
declare -g    _PS_STYLE="rounded"
declare -g    _PS_EXPANDED=""      # _ps_expand_into's result
declare -gi   _PS_EXPANDED_EMPTY=0 # 1 = that row names segments and none printed anything

# ── Collector registry ─────────────────────────────────────────────────────
# Needs are keyed on the segment FUNCTION, not on the name it is registered
# under, so an alias (`prompt_segment branch _ps_seg_git_branch`) still
# arms the git collector. [v0.1.4 moved this off name matching, which left
# every alias permanently blank.]
declare -gA _PS_COLLECTOR_FUNC=()     # collector name → function that gathers its data
declare -gA _PS_COLLECTOR_TTL=()      # collector name → seconds between runs (0 = every prompt)
declare -ga _PS_COLLECTOR_ORDER=()    # collector names in registration order = run order
declare -gA _PS_SEG_NEEDS=()          # segment function → space-separated collector names
declare -ga _PS_ACTIVE_COLLECTORS=()  # collectors the layout's rows need, in run order
declare -gi _PS_PLAN_DIRTY=1          # 1 = _PS_ACTIVE_COLLECTORS needs rebuilding
declare -ga _PS_ROW_SEGMENTS=()       # _ps_row_segments' result

# ── Box character sets ────────────────────────────────────────────────────
declare -gA _PS_CHARS=(
    [rounded_tl]="╭"  [rounded_tr]="╮"  [rounded_bl]="╰"  [rounded_br]="╯"
    [rounded_h]="─"   [rounded_v]="│"
    [sharp_tl]="┌"    [sharp_tr]="┐"    [sharp_bl]="└"    [sharp_br]="┘"
    [sharp_h]="─"     [sharp_v]="│"
    [double_tl]="╔"   [double_tr]="╗"   [double_bl]="╚"   [double_br]="╝"
    [double_h]="═"    [double_v]="║"
    [ascii_tl]="+"    [ascii_tr]="+"    [ascii_bl]="+"    [ascii_br]="+"
    [ascii_h]="-"     [ascii_v]="|"
)

# ── Row template expansion ─────────────────────────────────────────────────

# Expand a row template into its final display string: a single
# left-to-right scan over the ORIGINAL template text, consuming one @token
# or one literal character at a time.
#   1. @segname expands to segment output, longest names first so
#      @git_branch is matched before a shorter @git prefix could shadow it.
#   2. @fill is left as a placeholder, resolved in a second pass below once
#      the full line's width is known. The placeholder is a \x1f byte,
#      deleted from segment output first, so text a segment prints
#      (a directory or branch named @fill) can never be taken for it.
#
# [v0.1.2] Rewritten from repeated whole-string substitution, which had a
# real bug: replacing @name globally across the *entire accumulated result*
# meant a later pass could match "@othername"-shaped text that came from an
# EARLIER segment's actual output (a branch like feature/@venv-fix, a path,
# a hostname) — not from the template — and wrongly re-expand it. Scanning
# the template once, left to right, and never revisiting already-emitted
# output makes that class of bug structurally impossible rather than
# patching around specific cases.
#
# [v0.1.8] The work is done by _ps_expand_into, which leaves the row in
# _PS_EXPANDED and sets _PS_EXPANDED_EMPTY when the template names at least
# one segment and every one printed nothing: prompt_build drops that row
# instead of drawing a blank line, and reads both without a subshell.
#
# $1  template string
# $2  effective terminal width (caller reduces by box border char count)
_ps_expand() {
    _ps_expand_into "$@"
    printf '%s' "$_PS_EXPANDED"
}

_ps_expand_into() {
    local tmpl="$1" tw="${2:-${COLUMNS:-80}}"
    local result="" plain="" rest="$tmpl" fill=$'\x1f'
    local name val matched chunk named=0 visible=0

    # [v0.1.3 fix] _ps_resort_segments is a no-op unless something
    # registered since the last call, so this is cheap in the normal
    # (prompt_build already called it) case — but without it here,
    # _ps_expand silently produced nothing for every token whenever
    # called before prompt_build had run once, e.g. directly from a
    # test or from prompt_debug-style tooling. Found by my own
    # regression test for the OTHER bug this file fixes, which calls
    # _ps_expand directly and stopped working.
    _ps_resort_segments

    while [[ -n "$rest" ]]; do
        if [[ "${rest:0:1}" != "@" ]]; then
            # Fast path: most characters are literal (spaces, borders,
            # icons) — one comparison, no token-list scan.
            result+="${rest:0:1}"; plain+="${rest:0:1}"
            rest="${rest:1}"
            continue
        fi

        if [[ "$rest" == '@fill'* ]]; then
            result+="$fill"; plain+="$fill"
            rest="${rest#@fill}"
            continue
        fi

        matched=0
        for name in "${_PS_SEGS_SORTED[@]}"; do
            [[ "$rest" == "@${name}"* ]] || continue
            if [[ -n "${PS_DEBUG_SEGMENTS-}" ]]; then
                val=$("${_PS_SEGS[$name]}")
                local seg_rc=$?
                if (( seg_rc != 0 )); then
                    printf 'prompt: segment "%s" (%s) exited %d\n' \
                        "$name" "${_PS_SEGS[$name]}" "$seg_rc" >&2
                    val=""   # a diagnostic must not change what renders
                fi
            else
                val=$("${_PS_SEGS[$name]}" 2>/dev/null) || val=""
            fi
            val=${val//"$fill"/}
            # plain keeps the raw text: it measures what the row shows.
            local shown=$val
            _ps_escape_into shown
            result+="$shown"
            # Skip the strip_ansi call when the segment returned plain text.
            # Readline markers start with \001; their absence means no ANSI.
            [[ "$val" == *$'\001'* ]] && chunk=$(strip_ansi "$val") || chunk=$val
            plain+="$chunk"
            named=1; [[ -n "$chunk" ]] && visible=1
            rest="${rest#"@${name}"}"
            matched=1
            break
        done
        if (( ! matched )); then
            # Bare '@' matching no known token — pass it through literally,
            # same as the old code did for unmatched text.
            result+="@"; plain+="@"
            rest="${rest:1}"
        fi
    done

    if [[ "$result" == *"$fill"* ]]; then
        # Measure text flanking @fill in the stripped copy.
        # str_width gives code-point count so ─ counts as 1, not 3 bytes.
        local pre="${plain%%"$fill"*}" post="${plain##*"$fill"}"
        local fill_len=$(( tw - $(str_width "$pre") - $(str_width "$post") ))
        result="${result//"$fill"/$(str_repeat "${_PS_CHARS[${_PS_STYLE}_h]:-─}" "$fill_len")}"
    fi

    _PS_EXPANDED=$result
    _PS_EXPANDED_EMPTY=$(( named && ! visible ))
}

# ── Public API ─────────────────────────────────────────────────────────────

declare -g _PS_SEGS_DIRTY=0   # 1 = _PS_SEGS_SORTED needs rebuilding before next use

# Register a named segment.
# $1  name       Token used in row templates as @name.
# $2  function   Bash function that writes display text to stdout.
#                May use C_* / PS_* color variables.
prompt_segment() {
    local name="$1" func="$2"
    [[ -z "$name" || -z "$func" ]] && {
        printf 'prompt_segment: usage: <name> <function>\n' >&2
        return 1
    }
    _PS_SEGS["$name"]="$func"
    _PS_SEGS_DIRTY=1
    _PS_PLAN_DIRTY=1
}

# Register a data collector: a function that fills globals for segments to
# format. It runs in prompt_build, in the shell's own process (segments run
# in a subshell, so anything they assign is lost), and only while a row the
# layout shows uses a segment that needs it. Registering an existing name
# replaces its TTL and function and keeps its place in the run order.
#   _my_collect() { _MY_VAL=$(expensive_command); }
#   prompt_collector mine 30 _my_collect
# $1  name          Letters, digits and _; referenced by prompt_segment_needs.
# $2  ttl_seconds   0 = every prompt; N = at most once per N seconds.
# $3  function      Must already be defined.
prompt_collector() {
    (( $# == 3 )) || {
        printf 'prompt_collector: usage: <name> <ttl_seconds> <function>\n' >&2
        return 1
    }
    local name="$1" ttl="$2" func="$3"
    [[ "$name" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]] || {
        printf 'prompt_collector: bad name "%s" (letters, digits and _ only)\n' "$name" >&2
        return 1
    }
    [[ "$ttl" =~ ^[0-9]+$ ]] || {
        printf 'prompt_collector: ttl "%s" is not a whole number of seconds\n' "$ttl" >&2
        return 1
    }
    declare -F "$func" >/dev/null || {
        printf 'prompt_collector: "%s" is not a defined function\n' "$func" >&2
        return 1
    }
    [[ -n "${_PS_COLLECTOR_FUNC[$name]-}" ]] || _PS_COLLECTOR_ORDER+=("$name")
    _PS_COLLECTOR_FUNC["$name"]="$func"
    _PS_COLLECTOR_TTL["$name"]=$(( 10#$ttl ))   # 10#: "08" is not octal
    _PS_PLAN_DIRTY=1
}

# Declare the collectors a segment function reads data from, so they run
# whenever a shown row uses that function. Replaces any earlier
# declaration for the function. Order relative to prompt_segment does not
# matter. For custom segments wrapping built-in data:
#   _my_branch() { printf '⎇ %s' "$GIT_BRANCH"; }
#   prompt_segment_needs _my_branch git
#   prompt_segment mybranch _my_branch
# $1  function name   $2…  registered collector names (git, cmd_time,
#                          load, disk, gpu, or your own)
prompt_segment_needs() {
    (( $# >= 2 )) || {
        printf 'prompt_segment_needs: usage: <function> <collector>...\n' >&2
        return 1
    }
    local func="$1" c; shift
    for c in "$@"; do
        [[ -n "${_PS_COLLECTOR_FUNC[$c]-}" ]] && continue
        printf 'prompt_segment_needs: unknown collector "%s" (registered: %s)\n' \
            "$c" "${_PS_COLLECTOR_ORDER[*]}" >&2
        return 1
    done
    _PS_SEG_NEEDS["$func"]="$*"
    _PS_PLAN_DIRTY=1
}

# Rebuild _PS_SEGS_SORTED (longest-name-first, so @git_branch matches
# before a shorter @git could shadow it) — but only when something has
# actually changed since the last rebuild.
#
# [v0.1.3] Previously this ran inline in prompt_segment, forking
# awk|sort|cut on every single registration call. A typical config
# registering ~30 segments paid for ~30 re-sorts at shell-startup time
# (measured ~175-215ms) to produce one final list — every intermediate
# sort was thrown away by the next registration. Deferred here instead:
# called once per render from prompt_build, a no-op unless something
# registered since the last call.
_ps_resort_segments() {
    (( _PS_SEGS_DIRTY )) || return 0
    _PS_SEGS_SORTED=()
    while IFS= read -r n; do _PS_SEGS_SORTED+=("$n"); done < <(
        printf '%s\n' "${!_PS_SEGS[@]}" |
            awk '{ print length" "$0 }' | sort -rn | cut -d' ' -f2-
    )
    _PS_SEGS_DIRTY=0
}

# Fill _PS_ROW_SEGMENTS with the segment names a row template uses, in
# order. Matches tokens exactly as _ps_expand does (@fill first, then
# longest name first, an unmatched @ is literal), so the collectors planned
# are those of the segments that actually render.
# $1  template string
_ps_row_segments() {
    local rest="$1" name
    _PS_ROW_SEGMENTS=()
    _ps_resort_segments
    while [[ "$rest" == *@* ]]; do
        rest="${rest#*@}"
        [[ "$rest" == fill* ]] && { rest="${rest#fill}"; continue; }
        for name in "${_PS_SEGS_SORTED[@]}"; do
            [[ "$rest" == "${name}"* ]] || continue
            _PS_ROW_SEGMENTS+=("$name")
            rest="${rest#"$name"}"
            break
        done
    done
}

# Rebuild _PS_ACTIVE_COLLECTORS: the collectors needed by the segments that
# the layout's rows show, in registration order. A no-op unless a segment,
# row, layout, collector or needs declaration changed since the last call,
# so the per-prompt cost is one integer test.
_ps_plan_collectors() {
    (( _PS_PLAN_DIRTY )) || return 0
    local -A wanted=()
    local r s c
    for r in "${_PS_ORDER[@]}"; do
        _ps_row_segments "${_PS_ROWS[$r]-}"
        for s in "${_PS_ROW_SEGMENTS[@]}"; do
            # Collector names are validated identifiers: splitting is safe.
            # shellcheck disable=SC2086
            for c in ${_PS_SEG_NEEDS[${_PS_SEGS[$s]}]-}; do wanted["$c"]=1; done
        done
    done
    _PS_ACTIVE_COLLECTORS=()
    for c in "${_PS_COLLECTOR_ORDER[@]}"; do
        [[ -n "${wanted[$c]-}" ]] && _PS_ACTIVE_COLLECTORS+=("$c")
    done
    _PS_PLAN_DIRTY=0
}

# Define a named row template.
# $1  name      Referenced by prompt_layout.
# $2  template  Literal text + @segname tokens + one optional @fill spacer.
prompt_row() {
    local name="$1" tmpl="$2"
    [[ -z "$name" ]] && {
        printf 'prompt_row: usage: <name> <template>\n' >&2
        return 1
    }
    _PS_ROWS["$name"]="$tmpl"
    _PS_PLAN_DIRTY=1
}

# Set the prompt layout: ordered rows + optional box decoration.
#
# Usage: prompt_layout [--box [style]] [--closed] <row1> [row2…]
#
#   --box [style]   Draw a unicode box.  Styles: rounded (default) | sharp |
#                   double | ascii.  The next word is the style only when
#                   it names one; otherwise it is the first row.
#   --closed        Close box with ╯ on last row; cursor on new line below.
#   --no-box        No box decoration (default).
#
# Prepends prompt_build to PROMPT_COMMAND so it always runs first and
# captures $? before any other handler can clobber it.
prompt_layout() {
    _PS_ORDER=(); _PS_BOX=0; _PS_CLOSED=0; _PS_STYLE="rounded"

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --box)
                _PS_BOX=1
                [[ -n "${2-}" && -n "${_PS_CHARS[${2}_h]-}" ]] && { _PS_STYLE="$2"; shift; }
                ;;
            --closed) _PS_CLOSED=1 ;;
            --no-box) _PS_BOX=0    ;;
            *)        _PS_ORDER+=("$1") ;;
        esac
        shift
    done
    _PS_PLAN_DIRTY=1

    # Prepend once — checks the exact call token (start of string, or right
    # after a "; "), not a bare substring, so a differently-named function
    # that merely contains "prompt_build" can't cause a false-positive skip.
    if [[ "${PROMPT_COMMAND-}" != 'prompt_build'* && "${PROMPT_COMMAND-}" != *'; prompt_build'* ]]; then
        PROMPT_COMMAND="prompt_build${PROMPT_COMMAND:+; $PROMPT_COMMAND}"
    fi
}

# Print current configuration to stderr — useful during layout development.
prompt_debug() {
    _ps_plan_collectors
    printf '=== prompt.sh  box=%d  closed=%d  style=%s ===\n' \
        "$_PS_BOX" "$_PS_CLOSED" "$_PS_STYLE" >&2
    printf 'rows:\n' >&2
    local r; for r in "${_PS_ORDER[@]}"; do
        printf '  %-16s %s\n' "$r" "${_PS_ROWS[$r]:-<undefined>}" >&2
    done
    printf 'segments:\n' >&2
    local s needs; for s in "${!_PS_SEGS[@]}"; do
        needs="${_PS_SEG_NEEDS[${_PS_SEGS[$s]}]-}"
        printf '  @%-20s → %s%s\n' "$s" "${_PS_SEGS[$s]}" "${needs:+  (needs $needs)}" >&2
    done
    printf 'collectors (active = a shown row needs it):\n' >&2
    local c active; for c in "${_PS_COLLECTOR_ORDER[@]}"; do
        active=no; [[ " ${_PS_ACTIVE_COLLECTORS[*]} " == *" $c "* ]] && active=yes
        printf '  %-12s ttl=%-4s active=%-3s age=%ss  → %s\n' "$c" \
            "${_PS_COLLECTOR_TTL[$c]}" "$active" "$(cache_age "collector:$c")" \
            "${_PS_COLLECTOR_FUNC[$c]}" >&2
    done
    printf 'raw PS1: ' >&2; printf '%s' "$PS1" | cat -v >&2; printf '\n' >&2
}

# ── Builder ────────────────────────────────────────────────────────────────

# Rebuilds PS1 before each prompt display. Wired in by prompt_layout via
# PROMPT_COMMAND. The $? capture MUST remain the very first statement.
prompt_build() {
    local last_exit=$?
    # shellcheck disable=SC2034  # read by _ps_seg_exit in segments/command.sh
    PROMPT_LAST_EXIT=$last_exit   # global — readable by all segment functions

    _ps_resort_segments   # also called inside _ps_expand itself; cheap either way, kept here for a predictable point in the render sequence

    # Data collection happens HERE, in the parent shell — not inside the
    # segment functions. Segments run via val=$(segfunc), a subshell; any
    # cache_touch or value assignment made there is lost the instant the
    # subshell exits. [v0.1.3: the @gpu TTL cache never once took effect
    # for exactly that reason.] Only collectors a shown row needs run; a
    # TTL collector runs when its cache key has gone stale.
    _ps_plan_collectors
    local c ttl
    for c in "${_PS_ACTIVE_COLLECTORS[@]}"; do
        ttl=${_PS_COLLECTOR_TTL[$c]}
        if (( ttl > 0 )); then
            cache_stale "collector:$c" "$ttl" || continue
        fi
        # A collector's exit status means nothing here (load's is 1 when
        # the node is idle); `|| true` keeps an errexit shell rendering.
        "${_PS_COLLECTOR_FUNC[$c]}" || true
        (( ttl > 0 )) && cache_touch "collector:$c"
    done

    local tw=${COLUMNS:-0}
    (( tw > 0 )) || tw=$(tput cols 2>/dev/null || echo 80)

    local nrows=${#_PS_ORDER[@]}
    (( nrows == 0 )) && { PS1='\$ '; return; }

    local c_h="${_PS_CHARS[${_PS_STYLE}_h]:-─}"  c_v="${_PS_CHARS[${_PS_STYLE}_v]:-│}"
    local c_tl="${_PS_CHARS[${_PS_STYLE}_tl]:-┌}" c_tr="${_PS_CHARS[${_PS_STYLE}_tr]:-┐}"
    local c_bl="${_PS_CHARS[${_PS_STYLE}_bl]:-└}"  c_br="${_PS_CHARS[${_PS_STYLE}_br]:-┘}"

    # Expand every row first. A row whose segments all printed nothing is
    # left out, rather than drawn as a blank line, so the corners below go
    # on the first and last rows that remain. The last row is always kept:
    # it holds the prompt character the cursor follows.
    local budget=$tw; (( _PS_BOX )) && budget=$(( tw - 2 ))
    local -a contents=() fills=()
    local i tmpl
    for (( i=0; i<nrows; i++ )); do
        tmpl="${_PS_ROWS[${_PS_ORDER[$i]}]:-}"
        _ps_expand_into "$tmpl" "$budget"
        (( _PS_EXPANDED_EMPTY && i < nrows-1 )) && continue
        contents+=("$_PS_EXPANDED")
        [[ "$tmpl" == *@fill* ]] && fills+=(1) || fills+=(0)
    done
    nrows=${#contents[@]}

    local ps1=""
    for (( i=0; i<nrows; i++ )); do
        local content="${contents[$i]}" has_fill="${fills[$i]}"
        local is_last=0;  (( i == nrows-1 )) && is_last=1

        if (( ! _PS_BOX )); then
            (( is_last )) && ps1+="$content" || ps1+="${content}\n"
            continue
        fi

        # Checks lead with is_last (not i==0) so a single-row box — where
        # i==0 and is_last are both true — gets last-row treatment instead
        # of always falling into the top-border/top-corner branch. That was
        # the bug: a single-row box previously always rendered as a bare top
        # border with no prompt escape at all, in either --closed or open
        # mode, since i==0 was checked first and unconditionally won.
        #
        # Auto-fill rows without @fill.
        # Closed last row (incl. single-row closed): pad with bar char.
        # Open last row (incl. single-row open): no padding — cursor follows.
        # Top border of a real multi-row box: pad with bar char.
        # Inner rows: pad with spaces.
        if (( ! has_fill )); then
            local plain=$content
            _ps_unescape_into plain
            plain=$(strip_ansi "$plain")
            local pad=$(( budget - $(str_width "$plain") ))
            if (( pad > 0 )); then
                if (( is_last && _PS_CLOSED )); then
                    content+=$(str_repeat "$c_h" "$pad")
                elif (( is_last )); then
                    :   # open last row: intentionally no pad, cursor follows
                elif (( i == 0 )); then
                    content+=$(str_repeat "$c_h" "$pad")
                else
                    content+=$(printf '%*s' "$pad" '')
                fi
            fi
        fi

        if (( is_last && _PS_CLOSED )); then
            # Closed: seal the box, cursor on new line with \$ prompt char.
            # A single row (i==0 too) opens with the top-left corner, since
            # nothing is drawn above it.
            local left=$c_bl; (( i == 0 )) && left=$c_tl
            ps1+="${left}${content}${c_br}"$'\n''\$ '
        elif (( is_last )); then
            # Open: no right corner — cursor follows content directly
            local left=$c_bl; (( i == 0 )) && left=$c_tl
            ps1+="${left}${content}"
        elif (( i == 0 )); then
            ps1+="${c_tl}${content}${c_tr}\n"
        else
            ps1+="${c_v}${content}${c_v}\n"
        fi
    done

    PS1="$ps1"
}

# ── Built-in segments ──────────────────────────────────────────────────────
# Each file registers its collectors and needs through the API above, so
# they are sourced after it. Order is collector run order: command first,
# so @cmd_time's reading is taken before git or anything else spends time.
for _ps_topic in identity command git shell system hpc; do
    # Each topic file is checked on its own: shellcheck segments/*.sh
    # shellcheck source=/dev/null
    source "${_PS_ROOT}/segments/${_ps_topic}.sh"
done
unset _ps_topic _PS_ROOT
