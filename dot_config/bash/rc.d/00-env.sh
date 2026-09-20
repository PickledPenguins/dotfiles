# 00-env.sh -- environment variables every tool reads.  No PATH here (20-path).
#
# Knobs (set in ~/.bashrc.before):
#   DOTFILES_EDITOR      editor for $EDITOR/$VISUAL      default: vim, else vi
#   DOTFILES_MAN_COLORS  0 = plain man pages             default: 1

# ── Editor and pager ──────────────────────────────────────────────────────
if [[ -n "${DOTFILES_EDITOR-}" ]]; then
    export EDITOR="$DOTFILES_EDITOR"
elif command -v vim >/dev/null; then
    export EDITOR=vim
else
    export EDITOR=vi
fi
export VISUAL="$EDITOR"                 # used by crontab -e, git, sudoedit ...
export SUDO_EDITOR="$EDITOR"

export PAGER=less
export LESS="-FRXi"                     # -F quit if one screen  -R raw colors
                                        # -X no screen clear     -i case-insensitive search
export LESSHISTFILE=-                   # no ~/.lesshst
export SYSTEMD_LESS="$LESS"             # journalctl/systemctl use the same

# ── XDG base directories ──────────────────────────────────────────────────
# Tools that honor them keep $HOME tidy; the defaults are what the spec says.
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
export XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
export XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"

# Point tools that do not follow XDG on their own at ~/.config anyway
export RIPGREP_CONFIG_PATH="$XDG_CONFIG_HOME/ripgrep/config"
export PYTHONSTARTUP="$XDG_CONFIG_HOME/python/pythonrc.py"
export INPUTRC="$HOME/.inputrc"

# ── Locale ────────────────────────────────────────────────────────────────
# Keep whatever the system set; never leave it unset over ssh.
[[ -z "${LANG-}" ]] && export LANG=C.UTF-8

# ── Colors ────────────────────────────────────────────────────────────────
export COLORTERM="${COLORTERM:-truecolor}"
export GREP_COLORS="mt=1;31:fn=35:ln=32:se=36"      # match / filename / line / separator

# man pages through less, with bold and underline mapped to colors
if [[ "${DOTFILES_MAN_COLORS:-1}" == 1 ]]; then
    export LESS_TERMCAP_md=$'\e[1;36m'  # bold      -> bright cyan  (headings, names)
    export LESS_TERMCAP_me=$'\e[0m'
    export LESS_TERMCAP_us=$'\e[4;33m'  # underline -> yellow       (arguments)
    export LESS_TERMCAP_ue=$'\e[0m'
    export LESS_TERMCAP_so=$'\e[7m'     # standout  -> reverse      (search hits)
    export LESS_TERMCAP_se=$'\e[0m'
    export GROFF_NO_SGR=1               # groff would otherwise emit its own escapes
fi

# ── Misc ──────────────────────────────────────────────────────────────────
export TIME_STYLE=long-iso              # ls -l dates as 2026-09-20 15:04
export PYTHONDONTWRITEBYTECODE=1        # no __pycache__ litter from ad-hoc runs
