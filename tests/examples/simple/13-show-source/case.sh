# source: empty
mkdir -p "$SRC/dot_config/app"
echo "x" > "$SRC/dot_config/app/rc"
echo "y" > "$SRC/dot_bashrc"
dots managed --show-source
