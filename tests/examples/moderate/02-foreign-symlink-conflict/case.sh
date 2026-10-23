# source: empty
mkdir ~/env; echo "# old scheme" > ~/env/.bashrc
ln -s ~/env/.bashrc ~/.bashrc
echo "# new" > "$SRC/dot_bashrc"
dots apply; echo "exit $?"
dots apply --force > /dev/null
for b in ~/.dotfiles-backup/*/.bashrc; do [ -L "$b" ] && echo "backup is the old link"; done
cat ~/env/.bashrc
readlink ~/.bashrc
