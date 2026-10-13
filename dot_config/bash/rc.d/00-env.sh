# 00-env.sh: environment variables other programs read: editor, pager,
# colors, XDG directories, locale. PATH is 20-path.sh.
#
# Each setting has its description in the comment above it. A setting with
# "#" directly in front of it is off: delete that "#" to turn it on, or add
# one to turn a setting off. `dots options WORD` searches every file.
# For one machine only, put the line in ~/.bashrc.local instead.
#
# Knobs (set in ~/.bashrc.before):
#   DOTFILES_EDITOR   editor for $EDITOR/$VISUAL   default: vim, else vi

# ── Editor ────────────────────────────────────────────────────────────────

# $EDITOR: what git, crontab -e, sudoedit, fc and less's v key open.
# DOTFILES_EDITOR picks another: nvim, nano, "emacs -nw", micro, "code --wait".
if [[ -n "${DOTFILES_EDITOR-}" ]]; then
    export EDITOR="$DOTFILES_EDITOR"
elif command -v vim >/dev/null; then
    export EDITOR=vim
else
    export EDITOR=vi
fi

# $VISUAL and $SUDO_EDITOR follow $EDITOR. Programs prefer VISUAL when
# both are set, so set it on its own line for a separate full-screen editor.
export VISUAL="$EDITOR"
export SUDO_EDITOR="$EDITOR"

# ── Pager ─────────────────────────────────────────────────────────────────

# less pages for man, git, systemctl and anything else that asks $PAGER.
export PAGER=less

# less options: -F quit at once when the text fits on one screen, -R show
# colors, -X leave the text on screen after quitting, -i search ignoring
# case unless the pattern has a capital.
export LESS="-FRXi"

# The mouse wheel scrolls inside less. Selecting text with the mouse then
# needs Shift held down while less runs.
export LESS="$LESS --mouse --wheel-lines=3"

# less chops long lines instead of wrapping them; Left and Right scroll
# sideways. Good for logs and wide tables, poor for prose.
#export LESS="$LESS -S"

# less shows a search match in the middle of the screen instead of on the
# top line, so the lines before the match stay in view.
#export LESS="$LESS -j.5"

# less keeps no history file (~/.lesshst) of searches and commands.
export LESSHISTFILE=-

# journalctl and systemctl page with the same less options, plus systemd's
# own: -S chops long lines, -M shows the long prompt, -K quits on Ctrl-C.
# systemd's default is FRSXMK, and setting SYSTEMD_LESS replaces it rather
# than adding to it, so S, M and K are put back here. Without K journalctl
# ignores Ctrl-C and less only uses it to interrupt a search.
export SYSTEMD_LESS="$LESS -SMK"

# man pages through bat: syntax-colored sections and options.
# Needs: bat
#export MANPAGER="sh -c 'col -bx | bat -l man -p'"

# man pages in vim: :help-style navigation, K or Ctrl-] follow a reference.
#export MANPAGER='vim +MANPAGER --not-a-term -'

# man pages wrap at 100 columns even in a wider window; long lines are
# hard to read.
#export MANWIDTH=100

# ── Colors ────────────────────────────────────────────────────────────────

# Tell programs this terminal shows 24-bit color (vim's termguicolors in
# 10-ui.vim, bat, delta read it), unless the terminal already said. Wrong
# on the Linux console and old terminals, where colors come out garbled:
# `unset COLORTERM` in ~/.bashrc.local there.
export COLORTERM="${COLORTERM:-truecolor}"

# grep --color: matches bold red, file names magenta, line numbers green,
# separators cyan.
export GREP_COLORS="mt=1;31:fn=35:ln=32:se=36"

# man pages in color: bold text (headings, option names) bright cyan,
# underlined text (arguments) yellow, search hits reversed. Turn off every
# line of it for plain man pages.
export LESS_TERMCAP_md=$'\e[1;36m'
export LESS_TERMCAP_me=$'\e[0m'
export LESS_TERMCAP_us=$'\e[4;33m'
export LESS_TERMCAP_ue=$'\e[0m'
export LESS_TERMCAP_so=$'\e[7m'
export LESS_TERMCAP_se=$'\e[0m'
export GROFF_NO_SGR=1

# No color at all from programs that follow no-color.org (a long list:
# ls and grep excepted). For monochrome terminals, logs, screen readers.
#export NO_COLOR=1

# ── XDG base directories ──────────────────────────────────────────────────

# Where programs that follow the XDG spec keep config, data, state and
# cache. These are the spec's own defaults, made explicit for the lines
# below.
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
export XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
export XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"

# ripgrep reads defaults only from the file this names (~/.config/ripgrep/config).
export RIPGREP_CONFIG_PATH="$XDG_CONFIG_HOME/ripgrep/config"

# python runs ~/.config/python/pythonrc.py when an interactive session
# starts: history, completion, a few imports.
export PYTHONSTARTUP="$XDG_CONFIG_HOME/python/pythonrc.py"

# readline programs (bash, python, gdb, psql) read ~/.inputrc; this is also
# the built-in default, spelled out for `sudo -E` and su sessions.
export INPUTRC="$HOME/.inputrc"

# ── Keep $HOME tidy ───────────────────────────────────────────────────────
# Each line moves one program's file or directory out of $HOME into the
# XDG directories. The program stops looking in the old place, so move the
# old file to the new one first (both are named), or start afresh.

# python 3.13+ REPL history: ~/.python_history -> ~/.local/state/python/history,
# the file pythonrc.py already uses for older pythons.
#export PYTHON_HISTORY="$XDG_STATE_HOME/python/history"

# sqlite3 history: ~/.sqlite_history -> ~/.local/state/sqlite_history.
#export SQLITE_HISTORY="$XDG_STATE_HOME/sqlite_history"

# node REPL history: ~/.node_repl_history -> ~/.local/state/node_repl_history.
#export NODE_REPL_HISTORY="$XDG_STATE_HOME/node_repl_history"

# psql history: ~/.psql_history -> ~/.local/state/psql_history.
#export PSQL_HISTORY="$XDG_STATE_HOME/psql_history"

# mysql history: ~/.mysql_history -> ~/.local/state/mysql_history.
#export MYSQL_HISTFILE="$XDG_STATE_HOME/mysql_history"

# npm: ~/.npmrc -> ~/.config/npm/npmrc and the ~/.npm cache -> ~/.cache/npm.
#export NPM_CONFIG_USERCONFIG="$XDG_CONFIG_HOME/npm/npmrc" NPM_CONFIG_CACHE="$XDG_CACHE_HOME/npm"

# npm global installs (npm install -g): into ~/.local/share/npm instead of
# the system prefix, which needs root. 20-path.sh follows
# NPM_CONFIG_PREFIX for the bin directory.
#export NPM_CONFIG_PREFIX="$XDG_DATA_HOME/npm"

# Rust: ~/.cargo and ~/.rustup -> ~/.local/share/cargo and rustup.
# 20-path.sh follows CARGO_HOME for the bin directory.
#export CARGO_HOME="$XDG_DATA_HOME/cargo" RUSTUP_HOME="$XDG_DATA_HOME/rustup"

# Go: ~/go -> ~/.local/share/go. 20-path.sh follows GOPATH for the bin
# directory.
#export GOPATH="$XDG_DATA_HOME/go"

# Docker client config: ~/.docker -> ~/.config/docker.
#export DOCKER_CONFIG="$XDG_CONFIG_HOME/docker"

# Jupyter config: ~/.jupyter -> ~/.config/jupyter.
#export JUPYTER_CONFIG_DIR="$XDG_CONFIG_HOME/jupyter"

# GNU parallel: ~/.parallel -> ~/.config/parallel.
#export PARALLEL_HOME="$XDG_CONFIG_HOME/parallel"

# CUDA's compiled-kernel cache: ~/.nv -> ~/.cache/nv.
#export CUDA_CACHE_PATH="$XDG_CACHE_HOME/nv"

# .NET: ~/.dotnet -> ~/.local/share/dotnet and ~/.nuget/packages ->
# ~/.cache/NuGetPackages. 20-path.sh follows DOTNET_CLI_HOME for the
# global tools.
#export DOTNET_CLI_HOME="$XDG_DATA_HOME/dotnet" NUGET_PACKAGES="$XDG_CACHE_HOME/NuGetPackages"

# deno: ~/.deno -> ~/.local/share/deno. 20-path.sh follows
# DENO_INSTALL_ROOT for the bin directory.
#export DENO_INSTALL_ROOT="$XDG_DATA_HOME/deno"

# bun: ~/.bun -> ~/.local/share/bun. 20-path.sh follows BUN_INSTALL for
# the bin directory.
#export BUN_INSTALL="$XDG_DATA_HOME/bun"

# ghcup: ~/.ghcup -> ~/.local/share/ghcup, its programs in ~/.local/bin.
#export GHCUP_USE_XDG_DIRS=1

# pixi: ~/.pixi -> ~/.local/share/pixi. 20-path.sh follows PIXI_HOME for
# the bin directory.
#export PIXI_HOME="$XDG_DATA_HOME/pixi"

# pyenv: ~/.pyenv -> ~/.local/share/pyenv. 80-tools.sh follows
# PYENV_ROOT. After the move `pyenv rehash` rewrites the shims, which hold
# the old path. pyenv-virtualenv environments hold it too and need making
# again.
#export PYENV_ROOT="$XDG_DATA_HOME/pyenv"

# nvm: ~/.nvm -> ~/.local/share/nvm. 80-tools.sh follows NVM_DIR.
# Without it nvm's installer picks ~/.config/nvm, since XDG_CONFIG_HOME is
# set above, and 80-tools.sh does not look there.
#export NVM_DIR="$XDG_DATA_HOME/nvm"

# asdf 0.16+: ~/.asdf -> ~/.local/share/asdf. 80-tools.sh follows
# ASDF_DATA_DIR. After the move `asdf reshim` rewrites the shims.
#export ASDF_DATA_DIR="$XDG_DATA_HOME/asdf"

# rbenv: ~/.rbenv -> ~/.local/share/rbenv. `rbenv init` in 80-tools.sh
# follows RBENV_ROOT. After the move `rbenv rehash` rewrites the shims,
# which hold the old path.
#export RBENV_ROOT="$XDG_DATA_HOME/rbenv"

# SDKMAN!: ~/.sdkman -> ~/.local/share/sdkman. 80-tools.sh follows
# SDKMAN_DIR. Its `current` links hold the old path, so install it afresh
# with this set (the installer follows it) rather than move it.
#export SDKMAN_DIR="$XDG_DATA_HOME/sdkman"

# ── Locale ────────────────────────────────────────────────────────────────

# A UTF-8 locale for sessions that arrive without one: ssh from a machine
# that sends no LANG, cron, bare containers.
[[ -z "${LANG-}" ]] && export LANG=C.UTF-8

# Sort by byte value: ls lists dotfiles and capitals first, and sort, comm
# and join agree on every machine. Changes the order of ls, sort and globs.
#export LC_COLLATE=C

# 24-hour clock and English day and month names from date and ls, whatever
# the language of messages.
#export LC_TIME=C.UTF-8

# ── Other programs ────────────────────────────────────────────────────────

# ls -l dates as 2026-09-20 15:04 instead of "Sep 20 15:04" (GNU ls).
export TIME_STYLE=long-iso

# python writes no __pycache__ directories beside the code it runs. Imports
# are compiled again each run: milliseconds for scripts, more for big packages.
#export PYTHONDONTWRITEBYTECODE=1

# python keeps every __pycache__ under ~/.cache/python instead of beside the
# code: source trees stay clean and imports stay fast. Instead of the line
# above; turn that one off.
#export PYTHONPYCACHEPREFIX="$XDG_CACHE_HOME/python"

# gpg asks for passphrases in the terminal it was run from (commit signing,
# pinentry-curses). Costs one `tty` process per shell.
#export GPG_TTY="$(tty)"

# The web browser for xdg-open, python -m webbrowser and git web--browse.
export BROWSER=firefox
