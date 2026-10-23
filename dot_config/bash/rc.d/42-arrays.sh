# 42-arrays.sh: array, associative array and string helpers that work on this
# shell's own variables, by name, with no subshell: `arr_slice part all 1::10`
# fills the array `part`. A function is the only form that can set a caller's
# variable. The line-stream versions of the same operations are linuxbin's
# lst* and str* programs. Needs bash 4.4 (namerefs, mapfile -d). A script
# can source this file alone.
#
# shellcheck disable=SC2178  # it takes each nameref for the array of the last
# function that used its name
#
# OUT and IN are variable names, never values. OUT may be IN: the input is
# copied first. The functions' own locals start with `_a_`, so a caller's
# variable of that name cannot be passed. Positions in a slice count from 1,
# as lstslice counts lines. arr_index prints the bash index, from 0.
#
# Each setting has its description in the comment above it. A setting with
# "#" directly in front of it is off: delete that "#" to turn it on, or add
# one to turn a setting off. `dots options WORD` searches every file.

# ----------------------------------------------------------------------
# Arrays in and out
# ----------------------------------------------------------------------

# arr_from_lines OUT [FILE]: one element per line of FILE (default stdin).
arr_from_lines() { mapfile -t "$1" < "${2:-/dev/stdin}"; }

# arr_to_lines IN: print each element on its own line (nothing when empty).
arr_to_lines() {
    local -n _a_in=$1
    (( ${#_a_in[@]} )) && printf '%s\n' "${_a_in[@]}"
    return 0
}

# arr_split OUT SEP TEXT: split TEXT on the literal SEP (any length), empty
# pieces kept. An empty TEXT gives an empty array.
arr_split() {
    local -n _a_out=$1
    local _a_sep=$2 _a_rest=$3 _a_parts=()
    [[ -n $_a_sep ]] || { echo "arr_split: empty separator" >&2; return 2; }
    if [[ -n $_a_rest ]]; then
        while [[ $_a_rest == *"$_a_sep"* ]]; do
            _a_parts+=("${_a_rest%%"$_a_sep"*}")
            _a_rest=${_a_rest#*"$_a_sep"}
        done
        _a_parts+=("$_a_rest")
    fi
    _a_out=("${_a_parts[@]}")
}

# arr_join IN SEP: print the elements joined by SEP (any length), then a newline.
arr_join() {
    local -n _a_in=$1
    local _a_text="" _a_v _a_first=1
    for _a_v in "${_a_in[@]}"; do
        (( _a_first )) && _a_text=$_a_v || _a_text+="$2$_a_v"
        _a_first=0
    done
    printf '%s\n' "$_a_text"
}

# arr_show IN: print NAME, the count, then each index and value quoted, one a
# line: what `declare -p` says, readable.
arr_show() {
    local -n _a_in=$1
    local _a_k
    printf '%s (%d)\n' "$1" "${#_a_in[@]}"
    for _a_k in "${!_a_in[@]}"; do printf '  [%s] %q\n' "$_a_k" "${_a_in[$_a_k]}"; done
}

# ----------------------------------------------------------------------
# Selecting
# ----------------------------------------------------------------------

# arr_slice [-e] OUT IN START:END:STEP: the elements at positions START to
# END inclusive, every STEP-th, as lstslice takes them: positions from 1, a
# negative one from the end (-1 the last), any part empty for its default
# (1, the last, 1). -e also takes END when the step skips over it, so
# `arr_slice -e out in 1::10` keeps both end points.
arr_slice() {
    local _a_end_too=0
    [[ $1 == -e ]] && { _a_end_too=1; shift; }
    local -n _a_out=$1 _a_in=$2
    local _a_spec=$3 _a_vals=("${_a_in[@]}") _a_res=() _a_i
    if [[ ! $_a_spec =~ ^(-?[0-9]+)?:(-?[0-9]+)?(:([0-9]*))?$ ]]; then
        echo "arr_slice: bad slice '$_a_spec' (START:END:STEP)" >&2
        return 2
    fi
    # Read in base 10 (10#), so a leading zero is not octal
    local _a_n=${#_a_vals[@]} _a_from=${BASH_REMATCH[1]:-1} _a_to=${BASH_REMATCH[2]:--1}
    local _a_step=$(( 10#${BASH_REMATCH[4]:-1} ))
    _a_from=$(( ${_a_from%%[0-9]*}10#${_a_from#-} ))
    _a_to=$(( ${_a_to%%[0-9]*}10#${_a_to#-} ))
    (( _a_step > 0 )) || { echo "arr_slice: STEP must be over 0" >&2; return 2; }
    (( _a_from < 0 )) && (( _a_from += _a_n + 1 ))
    (( _a_to < 0 )) && (( _a_to += _a_n + 1 ))
    (( _a_from < 1 )) && _a_from=1
    (( _a_to > _a_n )) && _a_to=$_a_n
    for (( _a_i = _a_from; _a_i <= _a_to; _a_i += _a_step )); do
        _a_res+=("${_a_vals[_a_i - 1]}")
    done
    if (( _a_end_too && _a_to >= _a_from && (_a_to - _a_from) % _a_step )); then
        _a_res+=("${_a_vals[_a_to - 1]}")
    fi
    _a_out=("${_a_res[@]}")
}

# arr_has IN VALUE: exit 0 when an element equals VALUE, else 1.
arr_has() {
    local -n _a_in=$1
    local _a_v
    for _a_v in "${_a_in[@]}"; do [[ $_a_v == "$2" ]] && return 0; done
    return 1
}

# arr_index IN VALUE: print the bash index of the first element equal to
# VALUE; exit 1, printing nothing, when there is none.
arr_index() {
    local -n _a_in=$1
    local _a_k
    for _a_k in "${!_a_in[@]}"; do
        [[ ${_a_in[$_a_k]} == "$2" ]] && { printf '%s\n' "$_a_k"; return 0; }
    done
    return 1
}

# arr_filter OUT IN CMD [ARG...]: the elements for which `CMD ARG... ELEMENT`
# succeeds, in order. CMD may be a function: arr_filter big all test 5 -lt.
arr_filter() {
    local -n _a_out=$1 _a_in=$2
    shift 2
    local _a_vals=("${_a_in[@]}") _a_res=() _a_v
    for _a_v in "${_a_vals[@]}"; do "$@" "$_a_v" && _a_res+=("$_a_v"); done
    _a_out=("${_a_res[@]}")
}

# ----------------------------------------------------------------------
# Reshaping
# ----------------------------------------------------------------------

# arr_map OUT IN CMD [ARG...]: each element replaced by what `CMD ARG...
# ELEMENT` prints, its trailing newlines dropped. Stops at the first CMD that
# fails, with its status, OUT left as it was.
arr_map() {
    local -n _a_out=$1 _a_in=$2
    shift 2
    local _a_vals=("${_a_in[@]}") _a_res=() _a_v _a_new
    for _a_v in "${_a_vals[@]}"; do
        _a_new=$("$@" "$_a_v") || return
        _a_res+=("$_a_new")
    done
    _a_out=("${_a_res[@]}")
}

# arr_uniq OUT IN: the elements with repeats dropped, first-seen order kept.
arr_uniq() {
    local -n _a_out=$1 _a_in=$2
    local _a_vals=("${_a_in[@]}") _a_res=() _a_v
    local -A _a_seen=()
    for _a_v in "${_a_vals[@]}"; do
        [[ -n ${_a_seen["x$_a_v"]} ]] && continue
        _a_seen["x$_a_v"]=1
        _a_res+=("$_a_v")
    done
    _a_out=("${_a_res[@]}")
}

# arr_rev OUT IN: the elements in reverse order.
arr_rev() {
    local -n _a_out=$1 _a_in=$2
    local _a_vals=("${_a_in[@]}") _a_res=() _a_i
    for (( _a_i = ${#_a_vals[@]} - 1; _a_i >= 0; _a_i-- )); do _a_res+=("${_a_vals[_a_i]}"); done
    _a_out=("${_a_res[@]}")
}

# arr_sort OUT IN [SORT-OPTION...]: the elements sorted by sort(1) in the C
# locale, any option passed on (-n, -V, -r, -u ...). Elements may hold newlines.
arr_sort() {
    local -n _a_out=$1 _a_in=$2
    shift 2
    local _a_vals=("${_a_in[@]}")
    (( ${#_a_vals[@]} )) || { _a_out=(); return 0; }
    mapfile -d '' -t _a_out < <(printf '%s\0' "${_a_vals[@]}" | LC_ALL=C sort -z "$@")
}

# ----------------------------------------------------------------------
# Associative arrays
# ----------------------------------------------------------------------

# map_keys OUT MAP: the keys of the associative array MAP, sorted (C locale).
map_keys() {
    local -n _a_map=$2
    local _a_keys=("${!_a_map[@]}")
    arr_sort "$1" _a_keys
}

# map_show MAP: print each KEY=VALUE, by sorted key, the value quoted.
map_show() {
    local -n _a_m=$1
    local _a_ks _a_k
    map_keys _a_ks "$1"
    for _a_k in "${_a_ks[@]}"; do printf '%s=%q\n' "$_a_k" "${_a_m[$_a_k]}"; done
}

# ----------------------------------------------------------------------
# Strings
# ----------------------------------------------------------------------

# str_trim OUT TEXT: TEXT without leading and trailing white space.
str_trim() {
    local -n _a_out=$1
    local _a_t=$2
    _a_t=${_a_t#"${_a_t%%[![:space:]]*}"}
    _a_out=${_a_t%"${_a_t##*[![:space:]]}"}
}

# str_starts TEXT PREFIX / str_ends TEXT SUFFIX: exit 0 when TEXT starts
# (ends) with the literal PREFIX (SUFFIX), else 1.
str_starts() { [[ $1 == "$2"* ]]; }
str_ends() { [[ $1 == *"$2" ]]; }

# Repeating a string is the prompt toolkit's `str_repeat -v OUT TEXT N`
# (lib/term_utils.sh, loaded by 60-prompt.sh), not defined here.
