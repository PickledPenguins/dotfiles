# source: empty
echo "# bashrc" > "$SRC/dot_bashrc"
ln -s nowhere "$SRC/dot_vimrc"
dots apply 2>&1 | grep -E '^FileNotFoundError'; echo "exit ${PIPESTATUS[0]}"
ls -A ~ | wc -l
