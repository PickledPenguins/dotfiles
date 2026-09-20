# Aliases.  Anything more than one line is a function in 40-functions.sh.

# ls family -- color when the terminal supports it
if ls --color=auto >/dev/null 2>&1; then
    alias ls='ls --color=auto'
    if command -v dircolors >/dev/null; then
        if [[ -r ~/.dircolors ]]; then eval "$(dircolors -b ~/.dircolors)"; else eval "$(dircolors -b)"; fi
    fi
fi
alias ll='ls -alFh'
alias la='ls -A'
alias l='ls -CF'
alias lt='ls -lth'                      # newest last-modified first
alias lS='ls -lSh'                      # largest first

alias grep='grep --color=auto'
alias fgrep='grep -F --color=auto'
alias egrep='grep -E --color=auto'
alias diff='diff --color=auto'

# navigation
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias -- -='cd -'

# safety
alias rm='rm -I'                        # prompt once when deleting more than three files
alias cp='cp -i'
alias mv='mv -i'
alias mkdir='mkdir -pv'

# disk / processes
alias df='df -h'
alias du='du -h'
alias dus='du -sh * 2>/dev/null | sort -h'
alias free='free -h'
alias psg='ps aux | grep -v grep | grep -i'
alias ports='ss -tulnp'

# dotfiles
alias sb='source ~/.bashrc'
alias vb='vim ~/.bashrc'
alias clc='clear'

# Notify when a long command finishes:  sleep 10; alert
alias alert='notify-send --urgency=low -i "$([ $? = 0 ] && echo terminal || echo error)" "$(history | tail -n1 | sed -e '\''s/^\s*[0-9]\+\s*//;s/[;&|]\s*alert$//'\'')"'
