# PATH assembly.  path_prepend/path_append are idempotent: a directory that
# is already on PATH is moved rather than duplicated, one that does not
# exist is skipped.

path_remove()  { PATH=":$PATH:"; PATH="${PATH//:$1:/:}"; PATH="${PATH#:}"; PATH="${PATH%:}"; }
path_prepend() { [[ -d "$1" ]] || return 0; path_remove "$1"; PATH="$1${PATH:+:$PATH}"; }
path_append()  { [[ -d "$1" ]] || return 0; path_remove "$1"; PATH="${PATH:+$PATH:}$1"; }

path_prepend "$HOME/.local/bin"
path_prepend "$HOME/bin"
path_append  "$DOTFILES_DIR"            # the dots command

export PATH
