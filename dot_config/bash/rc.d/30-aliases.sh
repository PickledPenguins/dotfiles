# 30-aliases.sh -- aliases.  Anything longer than one line is a function
# (40-functions.sh).  Tool-specific aliases that need a guard live with the
# tool (75-python, 80-tools, 85-hpc).
#
# Knobs (set in ~/.bashrc.before):
#   DOTFILES_SAFE_RM   0 = plain rm/cp/mv, no -i/-I prompts   default: 1

# ── ls ────────────────────────────────────────────────────────────────────
if ls --color=auto >/dev/null 2>&1; then                 # GNU
    alias ls='ls --color=auto --group-directories-first'
    if command -v dircolors >/dev/null; then
        if [[ -r ~/.dircolors ]]; then eval "$(dircolors -b ~/.dircolors)"; else eval "$(dircolors -b)"; fi
    fi
else                                                     # BSD / macOS
    export CLICOLOR=1
fi
alias ll='ls -alFh'                     # long, all, type markers, human sizes
alias la='ls -A'                        # all but . and ..
alias l='ls -CF'
alias lt='ls -lth'                      # newest first
alias ltr='ls -ltrh'                    # newest last (scrolls into view)
alias lS='ls -lSh'                      # largest first
alias lsd='ls -d */'                    # directories only

# ── grep and friends ──────────────────────────────────────────────────────
alias grep='grep --color=auto'
alias fgrep='grep -F --color=auto'
alias egrep='grep -E --color=auto'
alias diff='diff --color=auto -u'       # unified, colored
alias less='less -FRXi'                 # same as $LESS, for `less` on the command line

# ── navigation ────────────────────────────────────────────────────────────
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias .....='cd ../../../..'
alias -- -='cd -'                       # previous directory
alias d='dirs -v'                       # the pushd stack, numbered (see 45-dirs.sh)

# ── safety ────────────────────────────────────────────────────────────────
if [[ "${DOTFILES_SAFE_RM:-1}" == 1 ]]; then
    alias rm='rm -I'                    # one prompt when deleting >3 files or recursing
    alias cp='cp -i'                    # prompt before overwrite
    alias mv='mv -i'
fi
alias mkdir='mkdir -pv'                 # parents, and say what was made
alias chmox='chmod +x'
alias ln='ln -v'

# ── disk, memory, processes ───────────────────────────────────────────────
alias df='df -h'
alias du='du -h'
alias dus='du -sh * 2>/dev/null | sort -h'      # sizes of everything here, sorted
alias free='free -h'
alias psg='ps aux | grep -v grep | grep -i'     # psg NAME
alias top='top -o %CPU'
alias ports='ss -tulnp'                         # listening sockets
alias j='jobs -l'

# ── shortcuts ─────────────────────────────────────────────────────────────
alias c='clear'
alias clc='clear'
alias h='history'
alias hg='history | grep'                       # hg PATTERN
alias e='$EDITOR'
alias v='vim'
alias sb='source ~/.bashrc'
alias vb='vim ~/.bashrc.local'
alias path='tr ":" "\n" <<<"$PATH"'
alias now='date +"%Y-%m-%d %H:%M:%S"'
alias week='date +%V'
alias wget='wget -c'                            # resume partial downloads
alias ping='ping -c 5'
alias ip='ip -color=auto'
command -v tree >/dev/null && alias tree='tree -C'   # colored; 40-functions has a fallback
alias serve='python3 -m http.server'            # serve the cwd on :8000

# ── git (the rest are git aliases in ~/.config/git/aliases.gitconfig) ─────
alias g='git'
alias gs='git status -sb'
alias gl='git lg -20'
alias gd='git diff'
alias gp='git pull'

# ── notifications ─────────────────────────────────────────────────────────
# Notify when a long command finishes:  make; alert
alias alert='notify-send --urgency=low -i "$([ $? = 0 ] && echo terminal || echo error)" "$(history | tail -n1 | sed -e '\''s/^\s*[0-9]\+\s*//;s/[;&|]\s*alert$//'\'')"'
