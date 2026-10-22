# 30-aliases.sh: short names for longer commands, and safer or more
# readable defaults for a few common ones. Aliases apply only at the
# prompt, never inside scripts. An alias here is a changed default, a typo
# fix, or a plain abbreviation (one command, arguments at the end). A
# command that must act on this shell is a function in 40-functions.sh,
# and anything else is a script in linuxbin's bin/ (docs/contributing.md
# has the rule). Aliases for tools that may be missing live with the tool
# (75-python, 80-tools, 85-hpc).
#
# Fast mode (05-fast.sh), and under DOTS_FAST_PATHS: ls colors by file type
# only, so ls reads the directory and stats nothing.
#
# Each setting has its description in the comment above it. A setting with
# "#" directly in front of it is off: delete that "#" to turn it on, or add
# one to turn a setting off. `dots options WORD` searches every file.
# For one machine only, put the line in ~/.bashrc.local instead, or undo an
# alias there with `unalias NAME`. `\ls` or `command ls` skips an alias once.

# ── ls ────────────────────────────────────────────────────────────────────

# GNU ls in color by file type (colors from ~/.dircolors), directories
# listed before files. BSD and macOS ls get color from CLICOLOR instead.
if ls --color=auto >/dev/null 2>&1; then
    alias ls='ls --color=auto --group-directories-first'
    if command -v dircolors >/dev/null; then
        if [[ -r ~/.dircolors ]]; then eval "$(dircolors -b ~/.dircolors)"; else eval "$(dircolors -b)"; fi
    fi
else
    export CLICOLOR=1
fi

# In fast mode and under DOTS_FAST_PATHS, the colors that need a stat of
# every file (executable, setuid, setgid, capability, sticky, writable by
# others, orphan and missing links, hard links) are off and links are
# colored as links, not as what they point to: ls --color then reads only
# the directory, which on a slow disk is the difference between instant and
# seconds. Directories, links, sockets and pipes keep their colors, from
# the directory entry. ls -F (ll, l) and --group-directories-first for
# links still stat.
_ls_fast_added=""
_ls_fast() {
    LS_COLORS=${LS_COLORS%"$_ls_fast_added"}
    _ls_fast_added=""
    if (( $1 )); then
        _ls_fast_added=":ex=00:su=00:sg=00:ca=00:tw=00:ow=00:st=00:or=00:mi=00:mh=00"
        [[ $LS_COLORS == *ln=target* ]] && _ls_fast_added=":ln=01;36$_ls_fast_added"
        LS_COLORS+=$_ls_fast_added
    fi
}
if [[ -n ${LS_COLORS-} ]] && declare -F dots_fast_dir_hook >/dev/null; then
    dots_fast_dir_hook _ls_fast
fi

# ll: long listing of everything, with type markers (/ * @) and sizes in K, M, G.
# ls: -a all, -l long, -F type markers, -h human sizes.
alias ll='ls -alFh'

# la: every entry except . and ..; l: compact columns with type markers.
# ls: -A all but . and .., -C columns, -F type markers.
alias la='ls -A'
alias l='ls -CF'

# lt / ltr: long listing newest first / newest last, so the newest end up
# just above the prompt.
# ls: -l long, -t newest first, -r reversed, -h human sizes.
alias lt='ls -lth'
alias ltr='ls -ltrh'

# lS: long listing, largest first.
# ls: -l long, -S largest first, -h human sizes.
alias lS='ls -lSh'



# ── grep, diff, ip ────────────────────────────────────────────────────────

# grep in color. fgrep and egrep become grep -F and grep -E, which newer
# GNU grep wants instead (the old names print a warning).
alias grep='grep --color=auto'
alias fgrep='grep -F --color=auto'
alias egrep='grep -E --color=auto'

# grep also skips version-control and dependency directories when it
# recurses (grep -r).
alias grep='grep --color=auto --exclude-dir={.git,.svn,.hg,node_modules,.venv,__pycache__}'

# diff in color and in unified format, the one patches and git use. Plain
# `diff a b` output then looks different from what tutorials show.
alias diff='diff --color=auto -u'

# ip with colored interface states and addresses.
alias ip='ip -color=auto'

# ── Navigation ────────────────────────────────────────────────────────────

# .. ... .... ..... go up one to four directories.
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias .....='cd ../../../..'

# cd.. without the space works too, a common typo.
alias cd..='cd ..'

# - goes back to the previous directory (cd -).
alias -- -='cd -'

# d: the pushd directory stack, numbered; 1 to 9 go there (45-dirs.sh).
# dirs: -v one per line, numbered.
alias d='dirs -v'



# ── Safety ────────────────────────────────────────────────────────────────

# rm asks once before removing more than three files or recursing; cp and
# mv ask before overwriting a file. rm -f, \rm or `yes |` skip the
# question. The habit then misleads on machines without these aliases.
# rm: -I ask once. cp, mv: -i ask each time.
alias rm='rm -I'
alias cp='cp -i'
alias mv='mv -i'

# rm asks before every single file: stricter than the -I above.
#alias rm='rm -i'

# chown, chmod and chgrp refuse to work recursively on / (GNU coreutils).
alias chown='chown --preserve-root' chmod='chmod --preserve-root' chgrp='chgrp --preserve-root'

# mkdir makes missing parent directories and says what it made.
alias mkdir='mkdir -pv'

# ln says what it linked.
alias ln='ln -v'

# chmox: chmod +x, a common typo put to use.
alias chmox='chmod +x'

# sudo followed by an alias works: `sudo ll`. The trailing space makes bash
# expand the word after sudo as an alias too.
alias sudo='sudo '

# ── Disk, memory, processes ───────────────────────────────────────────────

# df, du and free in K, M and G instead of blocks.
alias df='df -h'
alias du='du -h'
alias free='free -h'



# top sorted by CPU use (procps top).
# top: -o sort by field.
alias top='top -o %CPU'

# ports: listening TCP and UDP sockets and the programs holding them.
# ss: -t TCP, -u UDP, -l listening, -n port numbers, -p program.
alias ports='ss -tulnp'

# j: jobs with their process IDs.
alias j='jobs -l'



# ── Shortcuts ─────────────────────────────────────────────────────────────

# c and clc clear the screen.
alias c='clear'
alias clc='clear'

# h: history; hg PATTERN: search it. hg hides Mercurial's hg command.
alias h='history'
alias hg='history | grep'

# e: $EDITOR; v: vim.
alias e='$EDITOR'
alias v='vim'

# vi runs vim; the system vi is often vim-tiny or nvi, without syntax colors.
alias vi='vim'

# vim runs neovim.
# Needs: nvim
#alias vim='nvim'

# sb: re-read ~/.bashrc in this shell; vb: edit ~/.bashrc.local.
alias sb='source ~/.bashrc'
alias vb='$EDITOR ~/.bashrc.local'



# ping stops after 5 packets instead of running until Ctrl-C; a -c given
# on the command line wins.
alias ping='ping -c 5'

# tree in color. Where tree is missing, linuxbin's bin/tree stands in and
# ignores -C.
type -P tree >/dev/null && alias tree='tree -C'

# serve: share this directory over HTTP on port 8000 until Ctrl-C. Anyone
# who can reach the port can read every file below it.
alias serve='python3 -m http.server'

# cpv SRC DEST: copy with one overall progress line (rsync).
# rsync: -a archive (recurse, keep modes, times, links), -h human sizes.
alias cpv='rsync -ah --info=progress2'



# :q quits the shell, for fingers that think they are in vim.
alias :q='exit'

# ── Desktop ───────────────────────────────────────────────────────────────

# open FILE: the desktop's default application for FILE, as on macOS.
# Hides Linux's `open` (openvt) at the prompt.
#[[ $OSTYPE == linux* ]] && alias open='xdg-open'

# ── git (the git aliases themselves are in ~/.config/git/aliases.gitconfig) ─

# g: git, with git's Tab completion (50-completion.sh).
alias g='git'

# gs status, gl graph log, gd diff, gp pull. gs hides Ghostscript's gs and
# gp PARI/GP's; `command gs` still reaches them.
# git status: -s short, -b branch line. git lg (aliases.gitconfig): -20 last 20.
alias gs='git status -sb'
alias gl='git lg -20'
alias gd='git diff'
alias gp='git pull'

# The oh-my-zsh style set: ga add, gc commit, gco checkout, gsw switch,
# gb branch, gds staged diff, gpu push, gf fetch, gst stash, glo one-line
# log. gc hides Graphviz's gc.
# git fetch: --all every remote, --prune drop branches gone there.
#alias ga='git add' gc='git commit' gco='git checkout' gsw='git switch' gb='git branch'
#alias gds='git diff --staged' gpu='git push' gf='git fetch --all --prune' gst='git stash' glo='git log --oneline -20'

# ── Notifications ─────────────────────────────────────────────────────────

# alert: a desktop notification when a long command ends: `make; alert`.
# The icon says whether it failed.
# notify-send: -i icon. The sed takes the history number and the trailing alert off.
alias alert='notify-send --urgency=low -i "$([ $? = 0 ] && echo terminal || echo error)" "$(HISTTIMEFORMAT= history 1 | sed -e '\''s/^\s*[0-9]\+\s*//;s/[;&|]\s*alert$//'\'')"'
