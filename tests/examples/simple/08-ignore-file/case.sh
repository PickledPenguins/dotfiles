# source: empty
echo "# bashrc" > "$SRC/dot_bashrc"
echo "docs"     > "$SRC/README.md"
printf '# not a dotfile\nREADME.md\n' > "$SRC/.dotsignore"
dots managed
