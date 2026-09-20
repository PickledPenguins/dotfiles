# source: empty
git -C "$SRC" init -q -b main
echo "set nu" > "$SRC/dot_vimrc"
git -C "$SRC" add -A && git -C "$SRC" -c user.name=me -c user.email=me@x commit -qm init
dots apply > /dev/null
dots forget ~/.vimrc
git -C "$SRC" status --porcelain
[ -L ~/.vimrc ] || echo "~/.vimrc is a regular file"
