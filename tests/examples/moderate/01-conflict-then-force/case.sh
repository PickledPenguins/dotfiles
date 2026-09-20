# source: empty
echo "# theirs" > "$SRC/dot_bashrc"
echo "# mine"   > ~/.bashrc
dots apply; echo "exit $?"
dots apply --force; echo "exit $?"
cat ~/.dotfiles-backup/*/.bashrc
cat ~/.bashrc
