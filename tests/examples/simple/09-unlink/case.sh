# source: empty
echo "# bashrc" > "$SRC/dot_bashrc"
dots apply > /dev/null
dots unlink
[ -e ~/.bashrc ] || echo "link gone"
cat "$SRC/dot_bashrc"
