# 95-override.sh: set or unset the variables listed in DOTFILES_OVERRIDE,
# after everything else, even ones a system file made read-only.
#
# A cluster's /etc/profile or /etc/bash.bashrc may make TMOUT read-only, so
# an idle shell logs out, or fix HISTSIZE for everyone.  Bash cannot change
# or unset a read-only variable in the shell that has it.  When a listed
# name is read-only, this replaces the shell (exec: same process ID,
# directory, limits and terminal) with a new bash that reads none of the
# startup files and takes over this one's variables, functions, aliases,
# shell options, completions, key bindings and traps, less the listed
# names.  When none is read-only, it sets and unsets them in this shell.
# The swap costs one more bash start and a dump of the shell, tens of ms,
# on the machines that need it only, and the history list is read again
# from HISTFILE.  In a login shell the swap waits for the end of
# ~/.bash_profile, so the lines after ~/.bashrc there still run.  `bash -c`
# and scripts keep the read-only values: the new shell would not run them.
#
# Each setting has its description in the comment above it.  A setting with
# "#" directly in front of it is off: delete that "#" to turn it on, or add
# one to turn a setting off.  `dots options WORD` searches every file.
#
# Knobs (set in ~/.bashrc.before):
#   DOTFILES_OVERRIDE  an array: NAME to unset, NAME=VALUE to set   default: none
#                      DOTFILES_OVERRIDE=(TMOUT 'HISTSIZE=5000')

# Nothing listed, nothing to do.
(( ${#DOTFILES_OVERRIDE[@]} )) || return 0

# Bash's own variables, which a new bash sets for itself, and the loader's
# loop variables: the swap leaves them out of the copy.
_override_bash_own=" BASH BASHOPTS BASHPID BASH_ALIASES BASH_ARGC BASH_ARGV BASH_ARGV0 BASH_CMDS
    BASH_COMMAND BASH_EXECUTION_STRING BASH_LINENO BASH_MONOSECONDS BASH_REMATCH BASH_SOURCE
    BASH_SUBSHELL BASH_TRAPSIG BASH_VERSINFO BASH_VERSION COMP_CWORD COMP_KEY COMP_LINE COMP_POINT
    COMP_TYPE COMP_WORDS DIRSTACK EPOCHREALTIME EPOCHSECONDS EUID FUNCNAME GROUPS HISTCMD LINENO
    PIPESTATUS PPID RANDOM SECONDS SHELLOPTS SRANDOM UID _ _rc _name _t0 "

# Replace this shell with bash in POSIX mode, which reads only the file in
# $ENV (no /etc/bash.bashrc, no ~/.bashrc; --noprofile: no /etc/profile).
# The file turns POSIX mode off, restores this shell's state, sets the
# listed values and deletes itself.  Shell options first (a function body
# may need extglob to parse), functions before aliases (an alias would
# expand again inside the bodies).  No local variables, which
# declare -p would copy.  The _override_ globals are left out instead.
_override_swap() {
    _override_dir=$(mktemp -d "${TMPDIR:-/tmp}/bash-override.XXXXXX") || return
    _override_file=$_override_dir/env
    _override_vars=()
    for _override_v in $(compgen -v); do
        [[ "$_override_names $_override_bash_own" == *" $_override_v "* || $_override_v == _override_* ]] ||
            _override_vars+=("$_override_v")
    done
    {
        echo 'set +o posix; unset ENV'
        shopt -p | grep -Ev ' (login_shell|restricted_shell)$'
        declare -p "${_override_vars[@]}"
        declare -f
        alias -p
        set +o | grep -v ' posix$'
        complete -p
        for _override_v in emacs vi-insert vi-command; do
            bind -m "$_override_v" -X | while IFS= read -r _override_e; do
                printf 'bind -m %s -x %q 2>/dev/null\n' "$_override_v" "$_override_e"
            done
        done
        printf 'bind -f %q 2>/dev/null\n' "$_override_dir/inputrc"
        for _override_e in "${DOTFILES_OVERRIDE[@]}"; do
            [[ $_override_e == *=* && "$_override_names" == *" ${_override_e%%=*} "* ]] || continue
            _override_v=$(declare -p "${_override_e%%=*}" 2>/dev/null)
            _override_v=${_override_v#declare -}
            [[ ${_override_v%% *} == *x* ]] && printf 'export '
            printf '%s=%q\n' "${_override_e%%=*}" "${_override_e#*=}"
        done
        printf 'BASH_ARGV0=%q\n' "$0"
        echo 'unset -f _override_swap _dotfiles_disabled'
        printf 'command rm -rf -- %q\n' "$_override_dir"
        trap -p
    } > "$_override_file" 2>/dev/null
    # Key bindings and readline variables, read by bind -f (from a file:
    # readline reads nothing from a pipe).
    for _override_v in emacs vi-insert vi-command; do
        echo "set keymap $_override_v"
        bind -m "$_override_v" -p | grep -v '^#'
        bind -m "$_override_v" -s
    done > "$_override_dir/inputrc" 2>/dev/null
    bind -v >> "$_override_dir/inputrc" 2>/dev/null
    _override_env=()
    for _override_v in $_override_names; do _override_env+=(-u "$_override_v"); done
    _override_args=(--noprofile --posix)
    shopt -q login_shell && _override_args+=(-l)
    exec env "${_override_env[@]}" ENV="$_override_file" "$BASH" "${_override_args[@]}" -i
}

# Set or unset each listed name this shell lets change, and collect the
# rest, the read-only ones, for the swap.
_override_names=' '
_override_readonly=''
for _override_e in "${DOTFILES_OVERRIDE[@]}"; do
    _override_v=${_override_e%%=*}
    if [[ ! $_override_v =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]; then
        echo "bashrc: DOTFILES_OVERRIDE: not a variable name: $_override_v" >&2
        continue
    fi
    _override_names+="$_override_v "
    if ! (unset "$_override_v") 2>/dev/null; then
        _override_readonly+=" $_override_v"
    elif [[ $_override_e == *=* ]]; then
        printf -v "$_override_v" '%s' "${_override_e#*=}"
    else
        unset "$_override_v"
    fi
done

# Swap when a name is read-only, in an interactive shell on a terminal
# that runs no command or script.  A login shell swaps at the end of
# ~/.bash_profile instead, which calls _override_swap when
# _override_readonly is still set.
if [[ -n $_override_readonly && -t 0 && $- != *c* && ( ${0##*/} == bash* || ${0##*/} == -bash* ) ]]; then
    [[ " ${BASH_SOURCE[*]} " == *"/.bash_profile "* ]] || _override_swap
else
    unset _override_bash_own _override_names _override_readonly _override_e _override_v
    unset -f _override_swap
fi
