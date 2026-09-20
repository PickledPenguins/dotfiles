# source: empty
echo "# bashrc" > "$SRC/dot_bashrc"
echo "set nu"   > "$SRC/dot_vimrc"
dots apply ~/.bashrc > /dev/null
dots status --all; echo "exit $?"
