# 80-tools.sh: optional programs.  Every block checks that its program is
# installed first, so this file is the same on every machine and a missing
# program costs one lookup.  A block that is on runs the set-up the
# program's own install instructions ask for; one that is off would change
# what a familiar command or key does.
#
# Each setting has its description in the comment above it.  A setting with
# "#" directly in front of it is off: delete that "#" to turn it on, or add
# one to turn a setting off.  `dots options WORD` searches every file.
# For one machine only, put the line in ~/.bashrc.local instead.
#
# Knobs (set in ~/.bashrc.before):
#   DOTFILES_FZF_OPTS   FZF_DEFAULT_OPTS   default: --height 40% --layout=reverse --border

# ── Package managers and version managers ─────────────────────────────────

# Homebrew (macOS, or Linuxbrew): its PATH, MANPATH and settings.
for _brew in /opt/homebrew/bin/brew /usr/local/bin/brew /home/linuxbrew/.linuxbrew/bin/brew "$HOME/.linuxbrew/bin/brew"; do
    [[ -x "$_brew" ]] && { eval "$("$_brew" shellenv)"; break; }
done
unset _brew

# Nix: the per-user profile's PATH and settings, from ~/.nix-profile, or
# from ~/.local/state/nix/profile with `use-xdg-base-directories = true` in
# nix.conf.
for _nix in "$HOME/.nix-profile" "${XDG_STATE_HOME:-$HOME/.local/state}/nix/profile"; do
    [[ -r "$_nix/etc/profile.d/nix.sh" ]] && { source "$_nix/etc/profile.d/nix.sh"; break; }
done
unset _nix

# mise (formerly rtx): per-directory versions of node, python, go ...
command -v mise >/dev/null && eval "$(mise activate bash)"

# asdf 0.16+: its shims first on PATH.
[[ -d "${ASDF_DATA_DIR:-$HOME/.asdf}/shims" ]] && path_prepend "${ASDF_DATA_DIR:-$HOME/.asdf}/shims"

# pyenv: python versions per directory.
if [[ -d "${PYENV_ROOT:-$HOME/.pyenv}" ]]; then
    export PYENV_ROOT="${PYENV_ROOT:-$HOME/.pyenv}"
    path_prepend "$PYENV_ROOT/bin"
    command -v pyenv >/dev/null && eval "$(pyenv init - bash)"
fi

# nvm, loaded on first use of nvm, node, npm or npx: loading it at every
# shell start costs about 300 ms.
if [[ -s "${NVM_DIR:-$HOME/.nvm}/nvm.sh" ]]; then
    export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
    nvm() { unset -f nvm node npm npx; source "$NVM_DIR/nvm.sh"; nvm "$@"; }
    node() { unset -f nvm node npm npx; source "$NVM_DIR/nvm.sh"; node "$@"; }
    npm()  { unset -f nvm node npm npx; source "$NVM_DIR/nvm.sh"; npm "$@"; }
    npx()  { unset -f nvm node npm npx; source "$NVM_DIR/nvm.sh"; npx "$@"; }
fi

# fnm: a fast nvm replacement, switching node versions on cd.
command -v fnm >/dev/null && eval "$(fnm env --use-on-cd --shell bash)"

# rbenv: ruby versions per directory.
command -v rbenv >/dev/null && eval "$(rbenv init - bash)"

# SDKMAN!: Java, Gradle, Kotlin ... versions.  Its start-up is slow (~100 ms).
[[ -s "${SDKMAN_DIR:-$HOME/.sdkman}/bin/sdkman-init.sh" ]] && source "${SDKMAN_DIR:-$HOME/.sdkman}/bin/sdkman-init.sh"

# ghcup: the Haskell toolchain's environment.
[[ -r "$HOME/.ghcup/env" ]] && source "$HOME/.ghcup/env"

# Rust: cargo's environment file, when rustup wrote one.
[[ -r "${CARGO_HOME:-$HOME/.cargo}/env" ]] && source "${CARGO_HOME:-$HOME/.cargo}/env"

# ── Paging and viewing ────────────────────────────────────────────────────

# lesspipe: less opens archives, PDFs, images and packages as text.
command -v lesspipe >/dev/null && eval "$(SHELL=/bin/sh lesspipe)"

# bat: cat with syntax colors.  Debian installs it as batcat; `bat` works
# either way.  BAT_STYLE=plain leaves out line numbers and the header.
if command -v batcat >/dev/null && ! command -v bat >/dev/null; then alias bat='batcat'; fi
if command -v bat >/dev/null || command -v batcat >/dev/null; then export BAT_STYLE=plain; fi

# cat runs bat when bat is installed: colors on a terminal, the plain text
# into a pipe or file.  \cat reaches the real cat.
if command -v bat >/dev/null || command -v batcat >/dev/null; then alias cat='bat --paging=never'; fi

# fd: Debian installs it as fdfind; `fd` works either way.
command -v fdfind >/dev/null && ! command -v fd >/dev/null && alias fd='fdfind'

# eza (a modern ls) for the long listings ll and lt: git status per file,
# directories first.
if command -v eza >/dev/null; then
    alias ll='eza -la --group-directories-first --git'
    alias lt='eza -la --sort=modified --reverse'
fi

# eza for plain ls too.  Its options differ from ls's (ls -t is not eza -t),
# so habits and copied commands break.
# Needs: eza
#alias ls='eza --group-directories-first'

# tree drawn by eza, which also marks files git ignores.
# Needs: eza
#alias tree='eza --tree --git-ignore'

# LS_COLORS from vivid, a theme generator (see `vivid themes`), instead of
# ~/.dircolors.
# Needs: vivid
#export LS_COLORS="$(vivid generate molokai)"

# ── Finding things ────────────────────────────────────────────────────────

# fzf: Ctrl-R fuzzy history search, Ctrl-T pastes a file path, Alt-C cds
# into a directory.  Files come from fd or ripgrep when installed, which
# respect .gitignore.  fzf runs these lists with `$SHELL -c`, where the fd
# alias does not exist, so they name the program Debian installs.
if command -v fzf >/dev/null; then
    if fzf --bash >/dev/null 2>&1; then
        eval "$(fzf --bash)"                            # fzf >= 0.48
    else
        for _f in /usr/share/doc/fzf/examples/key-bindings.bash /usr/share/fzf/key-bindings.bash \
                  /usr/share/doc/fzf/examples/completion.bash   /usr/share/fzf/completion.bash; do
            [[ -r "$_f" ]] && source "$_f"
        done
        unset _f
    fi
    export FZF_DEFAULT_OPTS="${DOTFILES_FZF_OPTS:---height 40% --layout=reverse --border}"
    _fd=$(type -P fd fdfind | head -n 1); _fd=${_fd##*/}
    if [[ -n "$_fd" ]]; then
        export FZF_DEFAULT_COMMAND="$_fd --type f --hidden --exclude .git"
        export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
        export FZF_ALT_C_COMMAND="$_fd --type d --hidden --exclude .git"
    elif command -v rg >/dev/null; then
        export FZF_DEFAULT_COMMAND='rg --files --hidden --glob "!.git"'
        export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
    fi
    unset _fd
fi

# Ctrl-T shows the highlighted file's first lines beside the list, through
# bat, or batcat where Debian installs it under that name.
# Needs: fzf, bat
#export FZF_CTRL_T_OPTS="--preview '$(type -P bat >/dev/null && echo bat || echo batcat) --color=always --style=numbers --line-range=:200 {}'"

# Alt-C shows the highlighted directory's tree beside the list.
# Needs: fzf, tree
#export FZF_ALT_C_OPTS="--preview 'tree -C {} | head -100'"

# fe [QUERY]: pick a file with fzf and open it in $EDITOR.
# fkill: pick processes with fzf (Tab marks several) and kill them.
# fbr: pick a git branch with fzf, newest first, and switch to it.
if command -v fzf >/dev/null; then
    fe() { local f; f=$(fzf --query="${1-}" --select-1 --exit-0) && ${EDITOR:-vi} "$f"; }
    fkill() { ps -eo pid,user,etime,args | sed 1d | fzf -m --header='Tab marks; Enter kills' | awk '{print $1}' | xargs -r kill "${@:--TERM}"; }
    fbr() { local b; b=$(git branch --all --sort=-committerdate --format='%(refname:short)' | fzf) && git switch "${b#origin/}"; }
fi

# zoxide: `z NAME` jumps to the most-used directory matching NAME; `zi`
# picks one with fzf.
command -v zoxide >/dev/null && eval "$(zoxide init bash)"

# zoxide takes over cd itself: `cd proj` jumps to ~/work/proj from anywhere.
# Instead of the line above; cd without a match behaves as usual.  Loads
# after 45-dirs.sh, so it replaces either cd function there.
# Needs: zoxide
#eval "$(zoxide init bash --cmd cd)"

# ── Per-directory environments ────────────────────────────────────────────

# direnv: a directory's .envrc sets its environment on entry and undoes it
# on leaving (after `direnv allow`).
command -v direnv >/dev/null && eval "$(direnv hook bash)"

# ── Prompt and history replacements ───────────────────────────────────────

# starship: a fast, configurable cross-shell prompt (~/.config/starship.toml).
# Turn 60-prompt off first: echo prompt >> ~/.config/bash/disabled.
# Needs: starship
#eval "$(starship init bash)"

# atuin: history in SQLite with context (directory, exit status, duration),
# searched full-screen on Ctrl-R and Up; sync between machines is opt-in.
# Takes Ctrl-R from fzf.  Its bash hooks need bash-preexec or ble.sh
# sourced first, which add a DEBUG trap beside the prompt's own.
# Needs: atuin
#eval "$(atuin init bash)"

# thefuck: type `fuck` after a mistyped command to run the corrected one.
# Costs about 200 ms per shell.
# Needs: thefuck
#eval "$(thefuck --alias)"

# ── Containers, clusters, clouds ──────────────────────────────────────────

# docker: dps running containers as a table, dcu/dcd compose up -d / down,
# dclean removes stopped containers and dangling images.
if command -v docker >/dev/null; then
    alias dps='docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}"'
    alias dcu='docker compose up -d' dcd='docker compose down'
    alias dclean='docker container prune -f && docker image prune -f'
fi

# kubectl: k as a short name, completing like kubectl.
if command -v kubectl >/dev/null; then
    alias k='kubectl'
    source <(kubectl completion bash) && complete -o default -F __start_kubectl k
fi

# aws and terraform: Tab completion.
command -v aws_completer >/dev/null && complete -C aws_completer aws
command -v terraform >/dev/null && complete -C terraform terraform

# gh (GitHub CLI): Tab completion.
command -v gh >/dev/null && eval "$(gh completion -s bash)"

# lg: lazygit, a terminal UI for git.
command -v lazygit >/dev/null && alias lg='lazygit'

# ── tmux ──────────────────────────────────────────────────────────────────

# ta NAME attach, tn NAME new, tl list, tat attach to the session named
# after this directory, creating it.
if command -v tmux >/dev/null; then
    alias ta='tmux attach -t' tn='tmux new -s' tl='tmux ls'
    tat() { local s="${PWD##*/}"; s="${s//./_}"; tmux new-session -A -s "${1:-$s}"; }
fi

# ── File managers: leave in the directory you browsed to ──────────────────

# y: yazi, and cd to where it was when it quits.
command -v yazi >/dev/null && y() {
    local tmp cwd; tmp="$(mktemp -t yazi-cwd.XXXXXX)"
    yazi "$@" --cwd-file="$tmp"
    cwd="$(<"$tmp")"; [[ -n "$cwd" && "$cwd" != "$PWD" ]] && cd -- "$cwd"
    command rm -f -- "$tmp"
}

# lfcd: lf, and cd to where it was when it quits.
command -v lf >/dev/null && lfcd() { cd "$(command lf -print-last-dir "$@")" || return; }

# ── Greetings ─────────────────────────────────────────────────────────────

# A fortune (a quote or a joke) when a shell starts.
# Needs: fortune
#fortune -s

# System information (OS, kernel, uptime, memory) when a shell starts.
# Needs: fastfetch
#fastfetch
