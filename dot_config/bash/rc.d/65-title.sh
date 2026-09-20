# 65-title.sh -- keep the terminal window/tab title current.
#
# At each prompt the title becomes "user@host: ~/dir".  Optionally the title
# shows the running command while it runs, so a busy tab says what it is
# doing; that needs a DEBUG trap, which the toolkit prompt's command timer
# also uses, so it is off unless asked for.  Only for terminals that
# understand the xterm title escape, and only when stdout is a terminal.
#
# Knobs (set in ~/.bashrc.before):
#   DOTFILES_TITLE_FORMAT    printf-style: %u user, %h host, %d dir   default: '%u@%h: %d'
#   DOTFILES_TITLE_COMMANDS  1 = show the running command             default: 0

case "$TERM" in
    xterm*|rxvt*|screen*|tmux*|alacritty|foot|kitty) ;;
    *) return 0 ;;
esac
[[ -t 1 ]] || return 0

_title_fmt="${DOTFILES_TITLE_FORMAT:-%u@%h: %d}"
_title_prompt() {
    local d="${PWD/#$HOME/\~}" t="$_title_fmt"
    t="${t//%u/$USER}"; t="${t//%h/${HOSTNAME%%.*}}"; t="${t//%d/$d}"
    printf '\e]0;%s\a' "$t"
}
PROMPT_COMMAND="_title_prompt${PROMPT_COMMAND:+;$PROMPT_COMMAND}"

if [[ "${DOTFILES_TITLE_COMMANDS:-0}" == 1 ]]; then
    _title_command() {
        # DEBUG fires before every simple command, including prompt housekeeping
        case "$BASH_COMMAND" in _title_*|prompt_build*|history*|_venv_auto*) return ;; esac
        printf '\e]0;%s\a' "${BASH_COMMAND:0:60}"
    }
    # Arm the trap from the first prompt, not now, so loading the rest of
    # rc.d does not spray titles; then remove the installer from PROMPT_COMMAND.
    _title_arm() {
        [[ -z "$(trap -p DEBUG)" ]] && trap '_title_command' DEBUG
        PROMPT_COMMAND="${PROMPT_COMMAND/_title_arm;/}"
        unset -f _title_arm
    }
    PROMPT_COMMAND="_title_arm;$PROMPT_COMMAND"
fi
