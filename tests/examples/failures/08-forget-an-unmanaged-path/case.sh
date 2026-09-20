# source: empty
echo "set nu" > "$SRC/dot_vimrc"
dots apply > /dev/null
dots forget ~/.vimrc ~/.nothing; echo "exit $?"
