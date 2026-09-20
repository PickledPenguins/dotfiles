# Programmable completion.  Skipped under `set -o posix`; harmless if the
# system already loaded it from /etc/bash.bashrc.

if ! shopt -oq posix; then
    if [[ -r /usr/share/bash-completion/bash_completion ]]; then
        source /usr/share/bash-completion/bash_completion
    elif [[ -r /etc/bash_completion ]]; then
        source /etc/bash_completion
    fi
fi
