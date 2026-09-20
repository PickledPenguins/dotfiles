# source: empty
mkdir -p "$SRC/dot_config/git"
echo "[user]" > "$SRC/dot_config/git/config"
dots apply
[ -d ~/.config/git ] && [ ! -L ~/.config/git ] && echo "directory: real"
[ -L ~/.config/git/config ] && echo "file: symlink"
