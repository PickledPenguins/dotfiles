# source: repo
dots apply > /dev/null
echo "functions   # no shell functions on this box" > ~/.config/bash/disabled
DOTFILES_DEBUG=1 bash --rcfile ~/.bashrc -i -c 'type -t mkcd || echo "mkcd: not defined"' 2>&1 \
  | grep -v "job control\|process group" | sed 's/ *[0-9]* ms$//'
