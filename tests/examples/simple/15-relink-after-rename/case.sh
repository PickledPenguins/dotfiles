# source: empty
echo "# old" > "$SRC/dot_bashrc.old"
ln -s "$SRC/dot_bashrc.old" ~/.bashrc
echo "# new" > "$SRC/dot_bashrc"
rm "$SRC/dot_bashrc.old"
dots apply
readlink ~/.bashrc
