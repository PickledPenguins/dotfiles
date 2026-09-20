# source: empty
git -C "$SRC" init -q -b main
mkdir -p "$SRC/dot_config/app"
echo "a" > "$SRC/dot_config/app/settings"
echo "b" > "$SRC/dot_config/app/keys"
echo "c" > "$SRC/dot_bashrc"
echo "d" > "$SRC/dot_obsolete"
git -C "$SRC" add -A && git -C "$SRC" -c user.name=me -c user.email=me@x commit -qm init
dots apply > /dev/null

git -C "$SRC" mv dot_bashrc private_dot_bashrc      # same target, new source path
git -C "$SRC" mv dot_config/app dot_config/app2     # moved directory: new targets
git -C "$SRC" rm -q dot_obsolete                     # deleted: no longer a target
dots status; echo "exit $?"
dots apply; echo "exit $?"
stat -c '%a' "$SRC/private_dot_bashrc"
echo "--- dangling links dots no longer knows about:"
find ~ -xtype l | sed "s|$HOME|HOME|" | sort
