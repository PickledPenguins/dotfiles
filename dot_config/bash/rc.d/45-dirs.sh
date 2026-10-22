# 45-dirs.sh: moving between directories: bookmarks, CDPATH, the pushd
# stack, and what cd does.
#
# Fast mode (05-fast.sh), and under DOTS_FAST_PATHS: after a cd, the new
# directory is read in the background, so the ls or Tab that follows finds
# it in the kernel's cache.
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
#   DOTS_FAST_PREFETCH   after a cd in fast mode:    default: readdir
#                        readdir, stat (each entry
#                        too) or off

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
_jump_complete() { mapfile -t COMPREPLY < <(compgen -W "$(command ls "$DOTFILES_MARKS_DIR" 2>/dev/null)" -- "${COMP_WORDS[COMP_CWORD]}"); }
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

# ── Prefetch in fast mode ─────────────────────────────────────────────────

# In fast mode and under DOTS_FAST_PATHS, the first prompt in a new
# directory starts `ls -f` on it in the background (the names only: no
# stat, no sort), so the ls or Tab that follows finds them in the kernel's
# cache instead of waiting on the disk or NFS. One at a time: while the
# last one still runs (a hung mount), no other starts. No job line and no
# job in `jobs`. DOTS_FAST_PREFETCH=stat stats each entry too (ls -l), for
# ls colors and Tab marks, at the cost of more I/O; off starts nothing.
_dirs_prefetch_pid=""
_dirs_prefetch() {
    (( $1 )) && [[ ${DOTS_FAST_PREFETCH-} != off ]] || return 0
    [[ -n $_dirs_prefetch_pid ]] && kill -0 "$_dirs_prefetch_pid" 2>/dev/null && return 0
    if [[ ${DOTS_FAST_PREFETCH-} == stat ]]; then
        { command ls -AUl -- "$PWD" >/dev/null 2>&1 & } 2>/dev/null
    else
        { command ls -f -- "$PWD" >/dev/null 2>&1 & } 2>/dev/null
    fi
    _dirs_prefetch_pid=$!
    disown 2>/dev/null
}
if declare -F dots_fast_cd_hook >/dev/null; then
    dots_fast_cd_hook _dirs_prefetch
fi
