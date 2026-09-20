# source: empty
mkdir ~/env; echo "# old scheme" > ~/env/.bashrc
ln -s ~/env/.bashrc ~/.bashrc
echo "# new" > "$SRC/dot_bashrc"
dots apply; echo "exit $?"
dots apply --force > /dev/null
[ -L ~/.dotfiles-backup/*/.bashrc ] && echo "backup is the old link"
cat ~/env/.bashrc
readlink ~/.bashrc
