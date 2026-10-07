# source: empty
mkdir -p "$SRC/dot_vim/rc"
echo "set nu" > "$SRC/dot_vim/rc/10-ui.vim"
echo "# ours" > "$SRC/dot_bashrc"
# an older scheme linked the whole directory
ln -s "$SRC/dot_vim" ~/.vim
dots status; echo "exit $?"
dots apply --force; echo "exit $?"
dots forget ~/.vim/rc/10-ui.vim; echo "exit $?"
cat "$SRC/dot_vim/rc/10-ui.vim"
# the way out: a real directory, then apply
rm ~/.vim
dots apply; echo "exit $?"
dots status; echo "exit $?"
