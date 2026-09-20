# Shell options and history.  Bash 4+.

shopt -s histappend        # append, never overwrite, the history file
shopt -s checkwinsize      # update LINES/COLUMNS after each command
shopt -s cmdhist           # multi-line commands saved as one history line
shopt -s globstar          # ** matches recursively
shopt -s extglob           # !(pattern), +(pattern), ...
shopt -s cdspell           # fix minor typos in cd arguments
shopt -s dirspell          # ... and when completing directory names
shopt -s autocd            # a bare directory name cd's into it
shopt -s no_empty_cmd_completion   # Tab on an empty line does not list every command

HISTSIZE=50000
HISTFILESIZE=100000
HISTCONTROL=ignoreboth:erasedups         # no dupes, no lines starting with a space
HISTIGNORE="ls:ll:la:cd:cd -:pwd:exit:clear:history:bg:fg"
HISTTIMEFORMAT="%F %T  "

# Write each command to the history file as it runs, so parallel shells share it.
PROMPT_COMMAND="history -a${PROMPT_COMMAND:+;$PROMPT_COMMAND}"

# Ctrl-S/Ctrl-Q are worthless as flow control; free Ctrl-S for forward search.
[[ -t 0 ]] && stty -ixon 2>/dev/null
