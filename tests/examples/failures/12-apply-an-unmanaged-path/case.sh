# source: empty
echo "set nu" > "$SRC/dot_vimrc"
dots apply ~/.vimrc ~/.vimrcx; echo "exit $?"
dots status ~/.vimrcx; echo "exit $?"
