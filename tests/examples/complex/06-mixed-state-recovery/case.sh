# source: empty
for n in ok missing stale real foreign dir; do echo "$n" > "$SRC/dot_$n"; done
ln -s "$SRC/dot_ok" ~/.ok
ln -s "$SRC/dot_stale.old" ~/.stale
echo "mine" > ~/.real
echo "elsewhere" > ~/other; ln -s ~/other ~/.foreign
mkdir ~/.dir; echo "inside" > ~/.dir/file

dots status; echo "exit $?"
dots apply; echo "exit $?"
dots apply --force | grep -v '^backup'; echo "exit $?"
dots status; echo "exit $?"
echo "--- backup:"
find ~/.dotfiles-backup -mindepth 2 \( -type f -o -type l \) | sed "s|$HOME/.dotfiles-backup/[^/]*/||" | sort
cat ~/other
