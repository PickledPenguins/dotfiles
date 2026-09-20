# Small shell functions.

# mkcd DIR -- make a directory and enter it
mkcd() { mkdir -p -- "$1" && cd -- "$1" || return; }

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
            *.bz2)            bunzip2 "$f" ;;
            *.gz)             gunzip "$f" ;;
            *.xz)             unxz "$f" ;;
            *.zip)            unzip "$f" ;;
            *.7z)             7z x "$f" ;;
            *.rar)            unrar x "$f" ;;
            *)                echo "extract: don't know how to extract '$f'" >&2 ;;
        esac
    done
}

# ff PATTERN [DIR] -- find files by name, case-insensitive
ff() { find "${2:-.}" -iname "*$1*" 2>/dev/null; }

# bak FILE -- copy FILE to FILE.YYYYmmdd-HHMMSS.bak
bak() { cp -a -- "$1" "$1.$(date +%Y%m%d-%H%M%S).bak"; }

# path -- print PATH one entry per line
path() { tr ':' '\n' <<<"$PATH"; }

# calc EXPR -- quick arithmetic:  calc '2^10'  calc '22/7'
calc() { bc -l <<<"$*"; }

# retry N CMD... -- run CMD until it succeeds, at most N times
retry() {
    local n="$1"; shift
    local i
    for (( i = 1; i <= n; i++ )); do
        "$@" && return 0
        echo "retry: attempt $i/$n failed" >&2
        sleep 1
    done
    return 1
}
