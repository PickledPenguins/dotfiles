# 40-functions.sh -- small shell functions.  Each has a one-line usage
# comment; `type NAME` shows the body.

# Functions use `command X` where X is aliased in 30-aliases.sh (mkdir -pv,
# cp -i, mv -i, ln -v): aliases expand inside a function body at definition
# time, and the verbose or interactive flags would leak into these.

# mkcd DIR -- make a directory and enter it
mkcd() { command mkdir -p -- "$1" && cd -- "$1" || return; }

# tmpd -- make a temporary directory and enter it
tmpd() { cd "$(mktemp -d)" || return; pwd; }

# up [N] -- go up N directories (default 1)
up() {
    local n="${1:-1}" path=""
    while (( n-- > 0 )); do path+="../"; done
    cd "${path:-.}" || return
}

# extract ARCHIVE... -- unpack by extension
extract() {
    local f
    for f in "$@"; do
        [[ -f "$f" ]] || { echo "extract: '$f' is not a file" >&2; continue; }
        case "$f" in
            *.tar.bz2|*.tbz2) tar xjf "$f" ;;
            *.tar.gz|*.tgz)   tar xzf "$f" ;;
            *.tar.xz|*.txz)   tar xJf "$f" ;;
            *.tar.zst)        tar --zstd -xf "$f" ;;
            *.tar)            tar xf "$f" ;;
            *.bz2)            bunzip2 -k "$f" ;;
            *.gz)             gunzip -k "$f" ;;
            *.xz)             unxz -k "$f" ;;
            *.zip|*.jar)      unzip -q "$f" ;;
            *.7z)             7z x "$f" ;;
            *.rar)            unrar x "$f" ;;
            *.deb)            ar x "$f" ;;
            *)                echo "extract: don't know how to extract '$f'" >&2; return 1 ;;
        esac
    done
}

# targz DIR -- DIR.tar.gz, excluding VCS and editor droppings
targz() { tar --exclude-vcs --exclude='*.swp' -czf "${1%/}.tar.gz" "${1%/}" && ls -lh "${1%/}.tar.gz"; }

# ff PATTERN [DIR] -- find files by name, case-insensitive
ff() { find "${2:-.}" -iname "*$1*" 2>/dev/null; }

# fd_ PATTERN [DIR] -- find directories by name (fd itself may be installed)
fd_() { find "${2:-.}" -type d -iname "*$1*" 2>/dev/null; }

# bak FILE -- copy FILE to FILE.YYYYmmdd-HHMMSS.bak
bak() { command cp -a -- "$1" "$1.$(date +%Y%m%d-%H%M%S).bak"; }

# swap A B -- exchange two files
swap() {
    local tmp; tmp=$(mktemp -u -- "${1}.XXXXXX")
    command mv -- "$1" "$tmp" && command mv -- "$2" "$1" && command mv -- "$tmp" "$2"
}

# calc EXPR -- quick arithmetic:  calc '2^10'  calc '22/7'
calc() { bc -l <<<"$*"; }

# retry N CMD... -- run CMD until it succeeds, at most N times, 1 s apart
retry() {
    local n="$1" i; shift
    for (( i = 1; i <= n; i++ )); do
        "$@" && return 0
        echo "retry: attempt $i/$n failed" >&2
        sleep 1
    done
    return 1
}

# timer CMD... -- wall time of a command, to the millisecond
timer() {
    local t0=${EPOCHREALTIME/./}
    "$@"
    local rc=$? t1=${EPOCHREALTIME/./}
    printf 'timer: %d.%03d s (exit %d)\n' $(( (t1 - t0) / 1000000 )) $(( (t1 - t0) / 1000 % 1000 )) "$rc" >&2
    return "$rc"
}

# count [DIR] -- number of files under DIR, by extension
count() { find "${1:-.}" -type f | sed -n 's/.*\.\([^./]*\)$/\1/p' | sort | uniq -c | sort -rn; }

# title TEXT -- set the terminal window title
title() { printf '\e]0;%s\a' "$*"; }

# tree fallback when the real one is missing
if ! command -v tree >/dev/null; then
    tree() { find "${1:-.}" -not -path '*/.git/*' | sed -e 's/[^-][^\/]*\//  |/g' -e 's/|\([^ ]\)/|-\1/'; }
fi

# sha FILE -- sha256 of a file, hash only
sha() { sha256sum -- "$1" | cut -d' ' -f1; }

# man PAGE -- fall back to `PAGE --help` when there is no man page
man() {
    command man "$@" && return
    [[ $# == 1 ]] && command -v "$1" >/dev/null && "$1" --help 2>&1 | "${PAGER:-less}"
}

# reload -- re-read every dotfile in this shell
reload() { exec "$BASH" -l; }
