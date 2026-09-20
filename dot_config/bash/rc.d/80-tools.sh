# 80-tools.sh -- optional tools.  Each block is skipped when the tool is
# absent, so this file is the same on every machine.
#
# Knobs (set in ~/.bashrc.before):
#   DOTFILES_BAT_AS_CAT   0 = leave `cat` alone           default: 1
#   DOTFILES_FZF_OPTS     override FZF_DEFAULT_OPTS       default: height 40%, reverse, border

# lesspipe: less opens archives, PDFs, images ...
command -v lesspipe >/dev/null && eval "$(SHELL=/bin/sh lesspipe)"

# fzf: Ctrl-R fuzzy history, Ctrl-T files, Alt-C directories
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
    if command -v fd >/dev/null; then
        export FZF_DEFAULT_COMMAND='fd --type f --hidden --exclude .git'
        export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
        export FZF_ALT_C_COMMAND='fd --type d --hidden --exclude .git'
    elif command -v rg >/dev/null; then
        export FZF_DEFAULT_COMMAND='rg --files --hidden --glob "!.git"'
        export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
    fi
fi

# direnv: per-directory .envrc
command -v direnv >/dev/null && eval "$(direnv hook bash)"

# zoxide: `z DIR` jumps to a frecent directory
command -v zoxide >/dev/null && eval "$(zoxide init bash)"

# bat: cat with syntax highlighting (Debian installs it as batcat)
if command -v batcat >/dev/null && ! command -v bat >/dev/null; then alias bat='batcat'; fi
if command -v bat >/dev/null || command -v batcat >/dev/null; then
    export BAT_STYLE=plain
    [[ "${DOTFILES_BAT_AS_CAT:-1}" == 1 ]] && alias cat='bat --paging=never'
fi

# eza / exa: modern ls, only for the long aliases
if command -v eza >/dev/null; then
    alias ll='eza -la --group-directories-first --git'
    alias lt='eza -la --sort=modified --reverse'
fi

# nvm: lazy -- loading it eagerly costs ~300 ms per shell
if [[ -s "${NVM_DIR:-$HOME/.nvm}/nvm.sh" ]]; then
    export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
    nvm() { unset -f nvm node npm npx; source "$NVM_DIR/nvm.sh"; nvm "$@"; }
    node() { unset -f nvm node npm npx; source "$NVM_DIR/nvm.sh"; node "$@"; }
    npm()  { unset -f nvm node npm npx; source "$NVM_DIR/nvm.sh"; npm "$@"; }
    npx()  { unset -f nvm node npm npx; source "$NVM_DIR/nvm.sh"; npx "$@"; }
fi

# pyenv
if [[ -d "$HOME/.pyenv" ]]; then
    export PYENV_ROOT="$HOME/.pyenv"
    path_prepend "$PYENV_ROOT/bin"
    command -v pyenv >/dev/null && eval "$(pyenv init - bash)"
fi

# rust
[[ -r "$HOME/.cargo/env" ]] && source "$HOME/.cargo/env"

# GitHub CLI completion
command -v gh >/dev/null && eval "$(gh completion -s bash)"
