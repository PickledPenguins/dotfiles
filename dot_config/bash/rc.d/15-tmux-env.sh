# 15-tmux-env.sh: a shell in tmux takes DISPLAY, SSH_AUTH_SOCK and the
# rest of tmux's update-environment from the client typed on last.
#
# tmux copies those names from a client into its session on attach, but a
# shell already running keeps the values of the ssh login that made its
# pane, so an X program started there fails after a reattach from a new
# login. With the setting below and the one in
# ~/.config/tmux/conf.d/45-client-env.conf on, tmux writes the values of
# the client typed on last to a file for the session, and the shell reads
# it before each command and applies it when it changed. Programs already
# running keep their values.
#
# Each setting has its description in the comment above it. A setting with
# "#" directly in front of it is off: delete that "#" to turn it on, or add
# one to turn a setting off. `dots options WORD` searches every file.
# For one machine only, put the line in ~/.bashrc.local instead.

# Outside tmux there is nothing to follow.
[[ -n "${TMUX-}" ]] || return 0

# The file client-env writes for this pane's session and tmux server:
# SOCKET.env.SERVER_PID.SESSION, from TMUX=SOCKET,SERVER_PID,SESSION.
_tmux_env_file="${TMUX%%,*}.env.${TMUX#*,}"
_tmux_env_file="${_tmux_env_file%,*}.${_tmux_env_file##*,}"

# Apply the file when it differs from what this shell applied last. A
# read of a small file, no fork. Hands on the exit status it found.
_tmux_env_check() {
    local status=$? now=''
    { IFS= read -r -d '' now < "$_tmux_env_file"; } 2>/dev/null
    if [[ -n "$now" && "$now" != "${_tmux_env_seen-}" ]]; then
        _tmux_env_seen=$now
        eval "$now"
    fi
    return "$status"
}

# Check before each command: bash 5.3 runs ${ ...; } in PS0 in this shell,
# after the line is read. Older bash checks at each prompt instead.
_tmux_env_start() {
    if (( BASH_VERSINFO[0] * 100 + BASH_VERSINFO[1] >= 503 )); then
        [[ "${PS0-}" == *_tmux_env_check* ]] || PS0="${PS0-}\${ _tmux_env_check; }"
    else
        [[ "${PROMPT_COMMAND-}" == *_tmux_env_check* ]] || PROMPT_COMMAND="_tmux_env_check${PROMPT_COMMAND:+; $PROMPT_COMMAND}"
    fi
}

# Before each command (bash 5.3, or at each prompt with an older bash, so
# the first command after a switch of clients still has the old values),
# apply what the tmux hooks wrote: an X program opens on the screen of the
# client you typed on, ssh uses its agent. Costs a small read per command.
# Needs: the setting in ~/.config/tmux/conf.d/45-client-env.conf.
#_tmux_env_start
