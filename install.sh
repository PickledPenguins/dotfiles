#!/bin/sh
# Link the dots command into a directory on PATH, so it runs from anywhere.
#
#   ./install.sh          link ~/.local/bin/dots to this repository's dots
#   ./install.sh DIR      link DIR/dots instead
#
# A link, not a copy: dots finds its source tree at ~/.dotfiles, else where
# its own link resolves, so the command always runs this checkout.  A DIR/dots
# that is anything but this link already is left alone.
#
# Exit status: 0 linked or already linked; 1 DIR/dots exists; 2 usage.
set -eu

case "${1:-}" in
    -h|--help) sed -n '2,11p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
esac
if [ $# -gt 1 ]; then
    echo "usage: ./install.sh [DIR]" >&2
    exit 2
fi

repo=$(CDPATH= cd -- "$(dirname -- "$(readlink -f -- "$0")")" && pwd)
bin=${1:-$HOME/.local/bin}
link=$bin/dots

if [ -L "$link" ] && [ "$(readlink -f -- "$link")" = "$repo/dots" ]; then
    echo "already linked: $link -> $repo/dots"
    exit 0
fi
if [ -e "$link" ] || [ -L "$link" ]; then
    echo "install.sh: $link exists; remove it first" >&2
    exit 1
fi
mkdir -p -- "$bin"
ln -s -- "$repo/dots" "$link"
echo "linked: $link -> $repo/dots"
case ":$PATH:" in
    *":$bin:"*) ;;
    *) echo "note: $bin is not on PATH" >&2 ;;
esac
