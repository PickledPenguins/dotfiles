# source: empty
echo "# bashrc" > "$SRC/dot_bashrc"
echo "set nu"   > "$SRC/dot_vimrc"
dots status; echo "exit $?"
dots apply > /dev/null
dots status; echo "exit $?"
