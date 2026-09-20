# source: repo
# the machine as found
cat > ~/.bashrc  <<'EOF'
# distribution bashrc
HISTSIZE=1000
EOF
echo "# distribution profile" > ~/.profile
echo "set nu" > ~/.vimrc
printf '[user]\n\tname = Old Name\n\temail = old@example.com\n' > ~/.gitconfig
mkdir ~/old-dotfiles; echo "set -g mouse on" > ~/old-dotfiles/tmux.conf
ln -s ~/old-dotfiles/tmux.conf ~/.tmux.conf

dots status | grep -v '^missing'
dots apply | grep -v '^link '; echo "exit ${PIPESTATUS[0]}"
# keep the identity before the file is replaced
grep -A2 '^\[user\]' ~/.gitconfig > ~/.gitconfig.local
dots apply --force | grep -v '^replace '; echo "exit ${PIPESTATUS[0]}"
dots status; echo "exit $?"

bash --rcfile ~/.bashrc -i -c 'true' 2>&1 | grep -v "job control\|process group"
DOTFILES_DEBUG=1 bash --rcfile ~/.bashrc -i -c 'true' 2>&1 | grep -c '^bashrc: [a-z]* *[0-9]* ms'
git config --includes --global user.name
git config --includes --global alias.st
find ~/.dotfiles-backup -type f -o -type l | sed "s|$HOME/.dotfiles-backup/[^/]*/||" | sort
