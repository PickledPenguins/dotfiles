# source: empty
echo "set nu" > ~/.vimrc
dots add ~/.vimrc
cat "$SRC/dot_vimrc"
[ -L ~/.vimrc ] && echo "~/.vimrc is a link"
