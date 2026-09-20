# source: empty
echo "# bashrc" > "$SRC/dot_bashrc"
dots apply -n
ls -A ~ | wc -l
