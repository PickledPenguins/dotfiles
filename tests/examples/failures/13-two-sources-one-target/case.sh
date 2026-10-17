# source: empty
echo "# one" > "$SRC/dot_bashrc"
echo "# two" > "$SRC/private_dot_bashrc"
dots apply 2>&1; echo "exit $?"
dots status 2>&1; echo "exit $?"
ls -A ~ | wc -l
