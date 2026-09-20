# source: empty
echo "# bashrc" > "$SRC/dot_bashrc"
dots apply
readlink ~/.bashrc
cat ~/.bashrc
