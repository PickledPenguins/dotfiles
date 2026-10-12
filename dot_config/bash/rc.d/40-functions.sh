# 40-functions.sh -- small shell functions.  Each has its usage in the
# comment above it; `type NAME` prints the body.  A function only adds a
# command, so they are all on: an unused one costs nothing.
#
# Each setting has its description in the comment above it.  A setting with
# "#" directly in front of it is off: delete that "#" to turn it on, or add
# one to turn a setting off.  `dots options WORD` searches every file.
#
# Functions say `command mkdir`, `command cp` ... where 30-aliases.sh has an
# alias of that name: an alias expands inside a function body when the
# function is defined, and its -v or -i would leak in.

# ── Directories ───────────────────────────────────────────────────────────

# mkcd DIR -- make a directory (and its parents) and go into it.
mkcd() { command mkdir -p -- "$1" && cd -- "$1" || return; }

# tmpd -- make a fresh temporary directory, go into it, print its path.
tmpd() { cd "$(mktemp -d)" || return; pwd; }

# up [N] -- go up N directories (default 1).
up() {
    local n="${1:-1}" path=""
    while (( n-- > 0 )); do path+="../"; done
    cd "${path:-.}" || return
}

# bd NAME -- go back up to the nearest parent directory whose name starts
# with NAME: in ~/work/proj/src/lib, `bd pr` goes to ~/work/proj.
bd() {
    local dir="$PWD"
    while [[ "$dir" != / ]]; do
        dir="${dir%/*}"; dir="${dir:-/}"
        [[ "${dir##*/}" == "${1:?bd NAME}"* ]] && { cd -- "$dir" || return; return 0; }
    done
    echo "bd: no parent directory starts with '$1'" >&2; return 1
}

# cdf FILE -- go to the directory that holds FILE.
cdf() { cd -- "$(dirname -- "${1:?cdf FILE}")" || return; }

# ── Files ─────────────────────────────────────────────────────────────────

# extract ARCHIVE... -- unpack each archive, choosing the tool by extension.
# One that is missing or of an unknown kind is skipped; the status is then 1.
extract() {
    local f rc=0
    for f in "$@"; do
        [[ -f "$f" ]] || { echo "extract: '$f' is not a file" >&2; rc=1; continue; }
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
            *)                echo "extract: don't know how to extract '$f'" >&2; rc=1 ;;
        esac
    done
    return "$rc"
}

# targz DIR -- pack DIR into DIR.tar.gz, leaving out version control and
# editor swap files.
targz() { tar --exclude-vcs --exclude='*.swp' -czf "${1%/}.tar.gz" "${1%/}" && ls -lh "${1%/}.tar.gz"; }

# ff PATTERN [DIR] -- find files whose name contains PATTERN, any case.
ff() { find "${2:-.}" -iname "*$1*" 2>/dev/null; }

# fd_ PATTERN [DIR] -- the same for directories (the name fd is left for
# the fd program).
fd_() { find "${2:-.}" -type d -iname "*$1*" 2>/dev/null; }

# rgv PATTERN [PATH...] -- ripgrep, then open every match in vim's quickfix
# list (:cn, :cp to step through).
rgv() { vim -q <(rg --vimgrep "$@"); }

# bak FILE -- copy FILE to FILE.YYYYmmdd-HHMMSS.bak, keeping its mode and times.
bak() { command cp -a -- "$1" "$1.$(date +%Y%m%d-%H%M%S).bak"; }

# swapname A B -- exchange the names of two files.  When B cannot be moved, A
# gets its name back rather than staying under the temporary one.
swapname() {
    local tmp; tmp=$(mktemp -d -- "${1%/}.XXXXXX") || return
    command mv -- "$1" "$tmp/x" || { command rmdir -- "$tmp"; return 1; }
    command mv -- "$2" "$1" || { command mv -- "$tmp/x" "$1"; command rmdir -- "$tmp"; return 1; }
    command mv -- "$tmp/x" "$2" && command rmdir -- "$tmp"
}

# bigfiles [DIR] [N] -- the N largest files under DIR, not crossing into
# other file systems (default: here, 20).
bigfiles() { find "${1:-.}" -xdev -type f -printf '%s\t%p\n' 2>/dev/null | sort -rn | head -n "${2:-20}" | numfmt --field=1 --to=iec; }

# count [DIR] -- how many files under DIR have each extension.
count() { find "${1:-.}" -type f | sed -n 's/.*\.\([^./]*\)$/\1/p' | sort | uniq -c | sort -rn; }

# sha FILE -- the sha256 of a file, hash only.
sha() { sha256sum -- "$1" | cut -d' ' -f1; }

# mkscript NAME -- a new executable bash script with a strict-mode header,
# opened in $EDITOR.  Refuses to overwrite.
mkscript() {
    [[ -e "${1:?mkscript NAME}" ]] && { echo "mkscript: $1 exists" >&2; return 1; }
    printf '#!/usr/bin/env bash\nset -euo pipefail\n\n' > "$1" && chmod +x "$1" && ${EDITOR:-vi} "$1"
}

# note [TEXT] -- append TEXT, with the date, to ~/notes.md; alone, show the notes.
note() {
    if (( $# )); then printf -- '- %s  %s\n' "$(date '+%F %R')" "$*" >> ~/notes.md
    else cat ~/notes.md; fi
}

# tree fallback, only where the real tree is missing: an indented listing
# that skips .git.  type -P, so a second `source ~/.bashrc` does not take
# this function for the program; `function tree`, because bash expands the
# alias 30-aliases.sh sets in `tree()` while it reads this block, taken or not.
if ! type -P tree >/dev/null; then
    function tree { find "${1:-.}" -not -path '*/.git/*' | sed -e 's/[^-][^\/]*\//  |/g' -e 's/|\([^ ]\)/|-\1/'; }
fi

# ── Running commands ──────────────────────────────────────────────────────

# retry N CMD... -- run CMD until it succeeds, at most N times, 1 s apart.
retry() {
    local n="$1" i; shift
    for (( i = 1; i <= n; i++ )); do
        "$@" && return 0
        echo "retry: attempt $i/$n failed" >&2
        (( i < n )) && sleep 1
    done
    return 1
}

# timit CMD... -- run CMD and print its wall time to the millisecond.
# Bash 4 has no EPOCHREALTIME and prints 0.000 s.
# Needs: bash 5+
timit() {
    local t0=${EPOCHREALTIME/./}
    "$@"
    local rc=$? t1=${EPOCHREALTIME/./}
    printf 'timit: %d.%03d s (exit %d)\n' $(( (t1 - t0) / 1000000 )) $(( (t1 - t0) / 1000 % 1000 )) "$rc" >&2
    return "$rc"
}

# histstat [N] -- the N commands you run most often (default 20).
histstat() { fc -ln 1 | awk '{print $1}' | sort | uniq -c | sort -rn | head -n "${1:-20}"; }

# man PAGE -- man, falling back to `PAGE --help` when there is no page:
# that runs the program, so one whose --help does something else does it.
man() {
    command man "$@" && return
    [[ $# == 1 ]] && command -v "$1" >/dev/null && "$1" --help 2>&1 | "${PAGER:-less}"
}

# reload -- replace this shell with a fresh login shell that reads every
# dotfile again (aliases and functions removed from the files disappear).
reload() { exec "$BASH" -l; }

# ── Text and numbers ──────────────────────────────────────────────────────

# calc EXPR -- arithmetic with decimals: calc '2^10', calc '22/7'.
calc() { bc -l <<<"$*"; }

# genpass [LENGTH] -- a random password of letters and digits (default 20).
genpass() { LC_ALL=C tr -dc 'A-Za-z0-9' </dev/urandom | head -c "${1:-20}"; echo; }

# urlencode TEXT / urldecode TEXT -- percent-encoding, as in URLs.
urlencode() { python3 -c 'import sys, urllib.parse as u; print(u.quote(sys.argv[1], safe=""))' "$*"; }
urldecode() { python3 -c 'import sys, urllib.parse as u; print(u.unquote(sys.argv[1]))' "$*"; }

# fromepoch SECONDS -- a Unix timestamp as a date (GNU date).
fromepoch() { date -d "@${1:?fromepoch SECONDS}"; }

# ── Terminal ──────────────────────────────────────────────────────────────

# title TEXT -- set the terminal window title (65-title.sh resets it at the
# next prompt unless that module is off).
title() { printf '\e]0;%s\a' "$*"; }

# hr [CHAR] -- a line across the terminal, to find a spot in scrollback.
hr() { local line; printf -v line '%*s' "${COLUMNS:-80}" ''; echo "${line// /${1:-─}}"; }

# envg PATTERN -- environment variables matching PATTERN, any case, sorted.
envg() { env | grep -i -- "${1:?envg PATTERN}" | sort; }

# port N -- what is listening on port N (ss).
port() { ss -tulnp | awk -v p=":${1:?port N}\$" 'NR == 1 || $5 ~ p'; }

# ── Online (each contacts the named service) ──────────────────────────────

# cheat TOPIC -- a cheat sheet from cht.sh: cheat tar, cheat python/lambda.
cheat() { curl -s "https://cht.sh/${1:?cheat TOPIC}"; }

# weather [PLACE] -- a three-day forecast from wttr.in (default: where your
# IP address says you are).
weather() { curl -s "https://wttr.in/${1:-}"; }
