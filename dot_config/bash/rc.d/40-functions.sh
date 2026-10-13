# 40-functions.sh: small shell functions, each one a command that must act
# on this shell itself: change its directory, read its history, run one of
# its functions or aliases, or replace it. Every other helper is a script
# in linuxbin's bin/, a directory to put on PATH (DOTFILES_PATH_APPEND);
# docs/contributing.md has the rule. Each function has its usage in the
# comment above it; `type NAME` prints the body. A function only adds a
# command, so they are all on: an unused one costs nothing.
#
# Each setting has its description in the comment above it. A setting with
# "#" directly in front of it is off: delete that "#" to turn it on, or add
# one to turn a setting off. `dots options WORD` searches every file.
#
# Functions say `command mkdir`, `command cp` ... where 30-aliases.sh has an
# alias of that name: an alias expands inside a function body when the
# function is defined, and its -v or -i would leak in.

# ── Directories ───────────────────────────────────────────────────────────

# mkcd DIR: make a directory (and its parents) and go into it.
mkcd() { command mkdir -p -- "$1" && cd -- "$1" || return; }

# tmpd: make a fresh temporary directory, go into it, print its path.
tmpd() { cd "$(mktemp -d)" || return; pwd; }

# up [N]: go up N directories (default 1).
up() {
    local n="${1:-1}" path=""
    while (( n-- > 0 )); do path+="../"; done
    cd "${path:-.}" || return
}

# bd NAME: go back up to the nearest parent directory whose name starts
# with NAME: in ~/work/proj/src/lib, `bd pr` goes to ~/work/proj.
bd() {
    local dir="$PWD"
    while [[ "$dir" != / ]]; do
        dir="${dir%/*}"; dir="${dir:-/}"
        [[ "${dir##*/}" == "${1:?bd NAME}"* ]] && { cd -- "$dir" || return; return 0; }
    done
    echo "bd: no parent directory starts with '$1'" >&2; return 1
}

# cdf FILE: go to the directory that holds FILE.
cdf() { cd -- "$(dirname -- "${1:?cdf FILE}")" || return; }

# cdg [SUBDIR]: go to the top directory of the current git repository, or
# to SUBDIR below it.
cdg() { local top; top=$(git rev-parse --show-toplevel) && cd -- "$top${1:+/$1}" || return; }

# ── Running commands ──────────────────────────────────────────────────────

# retry N CMD...: run CMD until it succeeds, at most N times, 1 s apart.
retry() {
    local n="$1" i; shift
    for (( i = 1; i <= n; i++ )); do
        "$@" && return 0
        echo "retry: attempt $i/$n failed" >&2
        (( i < n )) && sleep 1
    done
    return 1
}

# timit CMD...: run CMD and print its wall time to the millisecond.
# Bash 4 has no EPOCHREALTIME and prints 0.000 s.
# Needs: bash 5+
timit() {
    local t0=${EPOCHREALTIME/./}
    "$@"
    local rc=$? t1=${EPOCHREALTIME/./}
    printf 'timit: %d.%03d s (exit %d)\n' $(( (t1 - t0) / 1000000 )) $(( (t1 - t0) / 1000 % 1000 )) "$rc" >&2
    return "$rc"
}

# histstat [N]: the N commands you run most often (default 20).
# fc: -l list, -n without numbers, 1 from the first. uniq: -c count each.
# sort: -rn most first.
histstat() { fc -ln 1 | awk '{print $1}' | sort | uniq -c | sort -rn | head -n "${1:-20}"; }

# man PAGE: man, falling back to `PAGE --help` when there is no page:
# that runs the program, so one whose --help does something else does it.
man() {
    command man "$@" && return
    [[ $# == 1 ]] && command -v "$1" >/dev/null && "$1" --help 2>&1 | "${PAGER:-less}"
}

# reload: replace this shell with a fresh login shell that reads every
# dotfile again (aliases and functions removed from the files disappear).
reload() { exec "$BASH" -l; }

# ── Terminal ──────────────────────────────────────────────────────────────

# hr [CHAR]: a line across the terminal, to find a spot in scrollback.
# printf: %*s pads to $COLUMNS spaces, each then replaced by CHAR.
hr() { local line; printf -v line '%*s' "${COLUMNS:-80}" ''; echo "${line// /${1:-─}}"; }
