# source: empty
mkdir -p "$SRC/dot_config/tmux" "$SRC/dot_config/git"
echo "set -g mouse on" > "$SRC/dot_config/tmux/tmux.conf"
echo "[alias]"         > "$SRC/dot_config/git/config"
echo "# bashrc"        > "$SRC/dot_bashrc"
dots apply > /dev/null
dots unlink ~/.config
dots status; echo "exit $?"
dots apply | tail -1
