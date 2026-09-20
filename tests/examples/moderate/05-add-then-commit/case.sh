# source: empty
git -C "$SRC" init -q -b main
echo "set nu" > ~/.vimrc
dots add ~/.vimrc
git -C "$SRC" status --porcelain
git -C "$SRC" add -A && git -C "$SRC" -c user.name=me -c user.email=me@x commit -qm "add vimrc"
git -C "$SRC" log --oneline | sed 's/^[0-9a-f]* //'
dots status
