# source: empty
echo "# bashrc" > "$SRC/dot_bashrc"
mkdir "$SRC/.git"; echo "ref: refs/heads/main" > "$SRC/.git/HEAD"
echo "*.pyc" > "$SRC/.gitignore"
dots managed
