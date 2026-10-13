# 45-dirs.sh: moving between directories: bookmarks, CDPATH, the pushd
# stack, and what cd does.
#
#   mark NAME     remember the current directory as NAME; asks before
#                 moving a NAME that points elsewhere
#   jump NAME     go there (Tab completes names)
#   unmark NAME   forget it
#   marks         list them
#   d             the numbered pushd stack (alias in 30-aliases.sh)
#   1 .. 9        go to that stack entry
#
# Each setting has its description in the comment above it. A setting with
# "#" directly in front of it is off: delete that "#" to turn it on, or add
# one to turn a setting off. `dots options WORD` searches every file.
# For one machine only, put the line in ~/.bashrc.local instead.
#
# Knobs (set in ~/.bashrc.before):
#   DOTFILES_MARKS_DIR   where the bookmarks live   default: ~/.local/share/marks
#   DOTFILES_CDPATH      extra CDPATH entries        default: none

# ── Bookmarks ─────────────────────────────────────────────────────────────

# Bookmarks are symlinks in one directory, so they outlast the shell and
# `ls -l` shows them.
DOTFILES_MARKS_DIR="${DOTFILES_MARKS_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/marks}"

# mark, unmark, marks and jump, as in the header. mark asks on stderr and
# reads the answer from stdin; anything but y keeps the old bookmark.
mark() {
    local link="$DOTFILES_MARKS_DIR/${1:?mark NAME}" old answer=
    if [[ -L $link ]]; then
        old=$(readlink -- "$link")
        [[ $old == "$PWD" ]] && return 0
        printf 'mark: %s -> %s; replace? [y/N] ' "$1" "$old" >&2
        read -r answer
        [[ $answer == [yY]* ]] || return 1
    fi
    command mkdir -p -- "$DOTFILES_MARKS_DIR" && command ln -sfn -- "$PWD" "$link"
}
unmark() { command rm -- "$DOTFILES_MARKS_DIR/${1:?unmark NAME}"; }
marks()  {
    local m
    for m in "$DOTFILES_MARKS_DIR"/*; do
        [[ -L "$m" ]] && printf '%-16s -> %s\n' "${m##*/}" "$(readlink "$m")"
    done
}
jump()   { cd -P -- "$DOTFILES_MARKS_DIR/${1:?jump NAME}" || return; }

# Tab after jump or unmark completes bookmark names.
_jump_complete() { mapfile -t COMPREPLY < <(compgen -W "$(command ls "$DOTFILES_MARKS_DIR" 2>/dev/null)" -- "${COMP_WORDS[1]}"); }
complete -F _jump_complete jump unmark

# ── CDPATH ────────────────────────────────────────────────────────────────

# cd NAME also looks in $HOME (and the DOTFILES_CDPATH knob's directories)
# when NAME is not below the current directory. The empty first entry is
# the current directory: written as "." bash would echo the new path after
# every relative cd.
#CDPATH=":$HOME${DOTFILES_CDPATH:+:$DOTFILES_CDPATH}"

# ── The directory stack ───────────────────────────────────────────────────

# 1 to 9 go to that entry of the pushd stack (`d` numbers them). ~N is the
# stack entry as a path, so this works with the plain cd and with the
# pushd-on-every-cd function below; cd has no +N of its own.
#for _i in 1 2 3 4 5 6 7 8 9; do alias "$_i"="cd ~$_i"; done
#unset _i

# ── What cd does ──────────────────────────────────────────────────────────
# The two below replace cd with a function; use one or the other. zoxide's
# `--cmd cd` (80-tools.sh) loads later and replaces either.

# cd lists the new directory after changing to it.
#cd() { builtin cd "$@" && ls; }

# Every cd also pushes where you were onto the stack (zsh's auto_pushd), so
# `d` shows the trail and 1 to 9 go back along it. cd - and a bare cd
# behave as usual; cd's options such as -P are not supported.
#cd() {
    #if (( $# == 0 )); then builtin pushd "$HOME"
    #elif [[ $1 == - ]]; then builtin cd -
    #else builtin pushd "$@"
    #fi >/dev/null
#}
