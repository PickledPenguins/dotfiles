# Environment variables every tool reads.  No PATH here (see 20-path.sh).

export EDITOR=vim
export VISUAL="$EDITOR"
export PAGER=less
export LESS="-FRX"                      # quit if one screen, raw colors, no init/deinit
export LESSHISTFILE=-                   # no ~/.lesshst

# XDG base directories -- tools that honor them keep $HOME tidy.
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
export XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
export XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"

# Locale: keep whatever the system set, but never leave it unset over ssh.
[[ -z "${LANG-}" ]] && export LANG=C.UTF-8

# Colored man pages through less.
export LESS_TERMCAP_md=$'\e[1;36m'      # bold  -> bright cyan
export LESS_TERMCAP_me=$'\e[0m'
export LESS_TERMCAP_us=$'\e[4;33m'      # underline -> yellow
export LESS_TERMCAP_ue=$'\e[0m'
export LESS_TERMCAP_so=$'\e[7m'         # standout (search hits) -> reverse
export LESS_TERMCAP_se=$'\e[0m'
