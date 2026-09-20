# 45-dirs.sh -- directory bookmarks and a stack you can see.
#
#   mark NAME        remember the current directory as NAME
#   jump NAME        cd to it (Tab completes names)
#   unmark NAME      forget it
#   marks            list them
#   d                numbered pushd stack (alias in 30-aliases)
#   1 .. 9           cd to that stack entry
#
# Bookmarks are symlinks in ~/.local/share/marks, so they survive shells
# and are visible to `ls`.
#
# Knobs (set in ~/.bashrc.before):
#   DOTFILES_MARKS_DIR   where the bookmarks live   default: ~/.local/share/marks
#   DOTFILES_CDPATH      extra CDPATH entries        default: none

DOTFILES_MARKS_DIR="${DOTFILES_MARKS_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/marks}"

mark()   { command mkdir -p "$DOTFILES_MARKS_DIR" && command ln -sfn "$(pwd)" "$DOTFILES_MARKS_DIR/${1:?mark NAME}"; }
unmark() { command rm -- "$DOTFILES_MARKS_DIR/${1:?unmark NAME}"; }
marks()  {
    local m
    for m in "$DOTFILES_MARKS_DIR"/*; do
        [[ -L "$m" ]] && printf '%-16s -> %s\n' "${m##*/}" "$(readlink "$m")"
    done
}
jump()   { cd -P -- "$DOTFILES_MARKS_DIR/${1:?jump NAME}" || return; }
_jump_complete() { mapfile -t COMPREPLY < <(compgen -W "$(command ls "$DOTFILES_MARKS_DIR" 2>/dev/null)" -- "${COMP_WORDS[1]}"); }
complete -F _jump_complete jump unmark

# cd looks here when a bare name is not under the current directory.  The
# leading empty entry is the current directory: spelled "." bash would echo
# the new path after every relative cd.
CDPATH=":$HOME${DOTFILES_CDPATH:+:$DOTFILES_CDPATH}"

# pushd stack shortcuts: `d` lists, `2` goes to entry 2
for _i in 1 2 3 4 5 6 7 8 9; do alias "$_i"="cd +$_i"; done
unset _i
