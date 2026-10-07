# source: empty
echo "# ours" > "$SRC/dot_bashrc"
echo "theirs one" > ~/.bashrc
dots apply --force | sed 's/^backup .*/backup/'; echo "exit ${PIPESTATUS[0]}"
# something replaces the link with a real file again, a second later
rm ~/.bashrc; echo "theirs two" > ~/.bashrc
sleep 1
dots apply --force | sed 's/^backup .*/backup/'; echo "exit ${PIPESTATUS[0]}"
ls ~/.dotfiles-backup | wc -l
cat ~/.dotfiles-backup/*/.bashrc
dots status; echo "exit $?"
