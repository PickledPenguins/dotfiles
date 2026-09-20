# source: empty
echo "set nu" > "$SRC/dot_vimrc"
dots apply > /dev/null
dots forget ~/.vimrc
[ -L ~/.vimrc ] || echo "regular file"
cat ~/.vimrc
[ -e "$SRC/dot_vimrc" ] || echo "source removed"
dots managed | wc -l
