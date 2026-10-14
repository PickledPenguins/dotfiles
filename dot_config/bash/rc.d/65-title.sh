# 65-title.sh: keep the terminal window or tab title current.
#
# Only for terminals that understand the xterm title escape, and only when
# the shell's output is a terminal. Inside tmux the title is discarded:
# allow-rename is off and set-titles-string has no #T (00-options.conf).
#
# Each setting has its description in the comment above it. A setting with
# "#" directly in front of it is off: delete that "#" to turn it on, or add
# one to turn a setting off. `dots options WORD` searches every file.
# For one machine only, put the line in ~/.bashrc.local instead.
#
# Knobs (set in ~/.bashrc.before):
#   DOTFILES_TITLE_FORMAT   %u user, %h host, %d directory   default: '%u@%h: %d'

# Leave terminals without title support alone.
case "$TERM" in
    xterm*|rxvt*|screen*|tmux*|alacritty|foot|kitty|wezterm) ;;
    *) return 0 ;;
esac
[[ -t 1 ]] || return 0

# At each prompt the title becomes "user@host: ~/dir" (the knob changes the
# format); ~ replaces $HOME only at a path boundary, so /home/a2 is not ~2.
# The exit status is handed on untouched for the prompt to show.
_title_fmt="${DOTFILES_TITLE_FORMAT:-%u@%h: %d}"
_title_prompt() {
    local status=$? d=$PWD t="$_title_fmt"
    [[ -n "$HOME" && ( "$PWD" == "$HOME" || "$PWD" == "$HOME"/* ) ]] && d="~${PWD#"$HOME"}"
    t="${t//%u/$USER}"; t="${t//%h/${HOSTNAME%%.*}}"; t="${t//%d/$d}"
    printf '\e]0;%s\a' "$t"
    return "$status"
}
[[ "${PROMPT_COMMAND-}" == *_title_prompt* ]] || PROMPT_COMMAND="_title_prompt${PROMPT_COMMAND:+; $PROMPT_COMMAND}"

# The functions for the setting below: the title shows a running command,
# through a DEBUG trap added after any trap already there.
_title_command() {
    case "$BASH_COMMAND" in _title_*|prompt_build*|_prompt_gap*|history*|_hist_*|_venv_auto*) return ;; esac
    printf '\e]0;%s\a' "${BASH_COMMAND:0:60}"
}
_title_arm() {
    local old=${_title_old#trap -- \'}; old=${old%\' DEBUG}
    [[ "$old" == *_title_command* ]] || trap "${old:+$old; }_title_command" DEBUG
    PROMPT_COMMAND="${PROMPT_COMMAND%;_title_old=*}"
    unset -f _title_arm; unset _title_old
}

# While a command runs, the title shows it, so a busy tab says what it is
# doing. Armed at the end of the first prompt, after the prompt has
# claimed its own trap, so loading the rest of the configuration does not
# flash titles; that trap is read outside a function, where bash shows it.
# Costs a function call before every command.
#PROMPT_COMMAND="$PROMPT_COMMAND;_title_old=\$(trap -p DEBUG); _title_arm"
