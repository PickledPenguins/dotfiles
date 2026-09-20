# source: repo
dots apply > /dev/null
mkdir ~/tools
cat > ~/.bashrc.before <<EOF
DOTFILES_PROMPT_LAYOUT=minimal
DOTFILES_SAFE_RM=0
DOTFILES_PATH_PREPEND=$HOME/tools
EOF
printf 'conda\nhpc\ntitle\n' > ~/.config/bash/disabled
echo "alias ll='ls -la --color=never'" > ~/.bashrc.local
echo "let g:dotfiles_indent = 4" > ~/.vimrc.before
echo "set scrolloff=3" > ~/.vimrc.local
echo "set -g history-limit 7" > ~/.tmux.conf.local
printf '[user]\n\tname = Me\n[push]\n\tdefault = simple\n' > ~/.gitconfig.local

DOTFILES_DEBUG=1 bash --rcfile ~/.bashrc -i -c 'true' 2>&1 | grep -c '^bashrc: [a-z]* *[0-9]* ms'
DOTFILES_DEBUG=1 bash --rcfile ~/.bashrc -i -c 'true' 2>&1 | grep '^bashrc: skip'
bash --rcfile ~/.bashrc -i -c 'alias ll; alias rm 2>&1; echo $PATH | cut -d: -f1' 2>&1 | grep -v "job control\|process group"
vim -es -u ~/.vimrc -c 'set shiftwidth?' -c 'set scrolloff?' -c 'qall!' | sed 's/^ *//'
unset TMUX; tmux -L "ex$$" -f ~/.tmux.conf start-server \; show -g history-limit \; kill-server
git config --includes --global user.name
git config --includes --global push.default
