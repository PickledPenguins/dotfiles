# source: repo
dots apply > /dev/null
printf "let g:dotfiles_indent = 4\nlet g:dotfiles_tabs = 1\n" > ~/.vimrc.before
echo "set scrolloff=9" > ~/.vimrc.local
vim -es -u ~/.vimrc -c 'set shiftwidth?' -c 'set expandtab?' -c 'set scrolloff?' -c 'qall!' | sed 's/^ *//'
