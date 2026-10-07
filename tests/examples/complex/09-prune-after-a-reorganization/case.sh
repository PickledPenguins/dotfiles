# source: empty
mkdir -p "$SRC/dot_config/app" "$SRC/notes"
echo "a=1" > "$SRC/dot_config/app/rc"
echo "x" > "$SRC/notes/todo"
echo "# ours" > "$SRC/dot_bashrc"
dots apply >/dev/null; echo "exit $?"
# the source is reorganized: app moves under a new name, notes stop being targets
mv "$SRC/dot_config/app" "$SRC/dot_config/tool"
echo "notes" > "$SRC/.dotsignore"
dots status; echo "exit $?"
dots prune -n
dots prune; echo "exit $?"
dots apply; echo "exit $?"
[ -L ~/notes/todo ] && echo "notes/todo is still a link: it resolves, so prune keeps it"
dots status; echo "exit $?"
