# source: empty
git -C "$SRC" init -q -b main
mkdir -p ~/.config/git ~/.config/tmux ~/.local/bin ~/.ssh
chmod 700 ~/.ssh
echo "# bashrc"             > ~/.bashrc
echo "set nu"               > ~/.vimrc
echo "[alias]"              > ~/.config/git/config
echo "set -g mouse on"      > ~/.config/tmux/tmux.conf
echo "Host *"               > ~/.ssh/config;   chmod 600 ~/.ssh/config
echo "machine x login y"    > ~/.netrc;        chmod 600 ~/.netrc
printf '#!/bin/sh\necho hi\n' > ~/.local/bin/hi; chmod 755 ~/.local/bin/hi
echo "*.swp"                > ~/.config/git/ignore

dots add ~/.bashrc ~/.vimrc ~/.config/git/config ~/.config/git/ignore \
         ~/.config/tmux/tmux.conf ~/.ssh/config ~/.netrc ~/.local/bin/hi
git -C "$SRC" add -A && git -C "$SRC" -c user.name=me -c user.email=me@x commit -qm "import home"
git -C "$SRC" ls-files
dots forget ~/.netrc
git -C "$SRC" status --porcelain
[ -L ~/.netrc ] || echo ".netrc is a regular file again"
stat -c '%a %n' "$SRC/dot_ssh/private_config" "$SRC/dot_local/bin/executable_hi" | sed "s|$SRC|SRC|"
~/.local/bin/hi
dots status; echo "exit $?"
