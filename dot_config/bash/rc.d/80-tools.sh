# Optional tools -- each block is skipped when the tool is not installed.

# lesspipe: less opens archives, PDFs, images...
command -v lesspipe >/dev/null && eval "$(SHELL=/bin/sh lesspipe)"

# fzf: fuzzy Ctrl-R history, Ctrl-T files, Alt-C directories
if command -v fzf >/dev/null; then
    if fzf --bash >/dev/null 2>&1; then
        eval "$(fzf --bash)"                            # fzf >= 0.48
    else
        for _f in /usr/share/doc/fzf/examples/key-bindings.bash \
                  /usr/share/fzf/key-bindings.bash \
                  /usr/share/doc/fzf/examples/completion.bash \
                  /usr/share/fzf/completion.bash; do
            [[ -r "$_f" ]] && source "$_f"
        done
        unset _f
    fi
    export FZF_DEFAULT_OPTS="--height 40% --layout=reverse --border"
    command -v fd >/dev/null && export FZF_DEFAULT_COMMAND='fd --type f --hidden --exclude .git'
fi

# direnv: per-directory .envrc
command -v direnv >/dev/null && eval "$(direnv hook bash)"

# zoxide: smarter cd (z DIR)
command -v zoxide >/dev/null && eval "$(zoxide init bash)"

# bat as a colored cat, when present
command -v bat >/dev/null && alias cat='bat --paging=never --style=plain'
