# source: empty
mkdir -p "$SRC/dot_config/docs" "$SRC/dot_cache/a"
echo 1 > "$SRC/dot_config/x.local"
echo 2 > "$SRC/dot_config/docs/README.md"
echo 3 > "$SRC/dot_cache/a/b"
echo 4 > "$SRC/dot_bashrc"
echo 5 > "$SRC/README.md"
printf '*.local\n.cache\nREADME.md\n' > "$SRC/.dotsignore"
dots managed
