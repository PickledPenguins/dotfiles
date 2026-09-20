# 20-path.sh -- PATH assembly and the helpers other modules use to extend it.
#
# path_prepend / path_append are idempotent: a directory already on PATH is
# moved, not duplicated; one that does not exist is skipped.  path_remove
# takes one off.  Use them in ~/.bashrc.local for machine-specific tools.
#
# Knobs (set in ~/.bashrc.before):
#   DOTFILES_PATH_PREPEND  colon-separated dirs to put first  default: none
#   DOTFILES_PATH_APPEND   colon-separated dirs to put last   default: none

path_remove()  { PATH=":$PATH:"; PATH="${PATH//:$1:/:}"; PATH="${PATH#:}"; PATH="${PATH%:}"; }
path_prepend() { [[ -d "$1" ]] || return 0; path_remove "$1"; PATH="$1${PATH:+:$PATH}"; }
path_append()  { [[ -d "$1" ]] || return 0; path_remove "$1"; PATH="${PATH:+$PATH:}$1"; }

# Private directories win over system ones
path_prepend "$HOME/bin"
path_prepend "$HOME/.local/bin"

# The dots command lives in the dotfiles repo
path_append "$DOTFILES_DIR"

# Common per-language install locations, only when present
path_append "$HOME/.cargo/bin"          # rustup
path_append "$HOME/go/bin"              # go install
path_append "$HOME/.npm-global/bin"     # npm config set prefix ~/.npm-global

# Knob-driven extras
IFS=: read -ra _dirs <<<"${DOTFILES_PATH_PREPEND-}"
for _d in "${_dirs[@]}"; do path_prepend "$_d"; done
IFS=: read -ra _dirs <<<"${DOTFILES_PATH_APPEND-}"
for _d in "${_dirs[@]}"; do path_append "$_d"; done
unset _dirs _d

export PATH

# Same idea for man pages and shared libraries, when the directories exist
[[ -d "$HOME/.local/share/man" ]] && export MANPATH="$HOME/.local/share/man:${MANPATH:-}"
