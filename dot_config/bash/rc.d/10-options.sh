# 10-options.sh -- shell options and history.  Bash 4+.
#
# Knobs (set in ~/.bashrc.before):
#   DOTFILES_HISTSIZE       lines kept in memory            default: 50000
#   DOTFILES_HISTFILESIZE   lines kept on disk              default: 100000
#   DOTFILES_HISTIGNORE     extra colon-separated patterns  default: none
#   DOTFILES_SHARED_HISTORY 0 = do not write history after every command  default: 1
#   DOTFILES_AUTOCD         0 = a bare directory name is not a cd         default: 1
#   DOTFILES_NOCLOBBER      1 = `>` refuses to overwrite (use >|)          default: 0
#   DOTFILES_PIPEFAIL       1 = a pipeline fails when any stage fails       default: 0
#   DOTFILES_DOTGLOB        1 = * matches dotfiles                          default: 0
#   DOTFILES_NOCASEGLOB     1 = case-insensitive globbing                   default: 0

# ── Behavior ──────────────────────────────────────────────────────────────
shopt -s histappend        # append to the history file, never overwrite it
shopt -s checkwinsize      # update LINES/COLUMNS after each command
shopt -s cmdhist           # a multi-line command is saved as one history line
shopt -s lithist           # ... keeping its newlines rather than semicolons
shopt -s globstar          # ** matches recursively (bash 4)
shopt -s extglob           # !(pattern), +(pattern), @(a|b) ...
shopt -s cdspell           # fix minor typos in cd arguments
shopt -s dirspell          # ... and when completing directory names
shopt -s no_empty_cmd_completion   # Tab on an empty line does not list every command
shopt -s checkjobs         # warn about running jobs before exiting
shopt -s huponexit         # ... and send them SIGHUP when the shell really exits
[[ "${DOTFILES_AUTOCD:-1}" == 1 ]] && shopt -s autocd

# Opinionated, off by default -- each changes what a familiar command does
[[ "${DOTFILES_NOCLOBBER:-0}" == 1 ]]  && set -o noclobber     # > refuses to overwrite; >| forces
[[ "${DOTFILES_PIPEFAIL:-0}" == 1 ]]   && set -o pipefail      # `a | b` fails if a fails
[[ "${DOTFILES_DOTGLOB:-0}" == 1 ]]    && shopt -s dotglob     # * matches dotfiles (not . and ..)
[[ "${DOTFILES_NOCASEGLOB:-0}" == 1 ]] && shopt -s nocaseglob  # *.JPG matches .jpg

# ── History ───────────────────────────────────────────────────────────────
HISTSIZE="${DOTFILES_HISTSIZE:-50000}"
HISTFILESIZE="${DOTFILES_HISTFILESIZE:-100000}"
HISTCONTROL=ignoreboth:erasedups         # no dupes, no lines starting with a space
HISTIGNORE="ls:ll:la:l:cd:cd -:pwd:exit:clear:clc:history:bg:fg:jobs${DOTFILES_HISTIGNORE:+:$DOTFILES_HISTIGNORE}"
HISTTIMEFORMAT="%F %T  "                 # `history` shows when each command ran

# Write each command out as it runs so parallel shells share one history.
if [[ "${DOTFILES_SHARED_HISTORY:-1}" == 1 ]]; then
    PROMPT_COMMAND="history -a${PROMPT_COMMAND:+;$PROMPT_COMMAND}"
fi

# ── Terminal ──────────────────────────────────────────────────────────────
# Ctrl-S/Ctrl-Q flow control is worthless; free Ctrl-S for forward history search.
[[ -t 0 ]] && stty -ixon 2>/dev/null

# Default permissions for new files: rw-r--r-- / rwxr-xr-x
umask 022
