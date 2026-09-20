# source: empty
mkdir -p "$SRC/dot_config/tmux" "$SRC/dot_config/git"
echo "set -g mouse on" > "$SRC/dot_config/tmux/tmux.conf"
echo "[alias]"         > "$SRC/dot_config/git/config"
echo "# bashrc"        > "$SRC/dot_bashrc"
echo "set nu"          > "$SRC/dot_vimrc"
dots apply ~/.config
dots status ~/.config; echo "exit $?"
dots status; echo "exit $?"
