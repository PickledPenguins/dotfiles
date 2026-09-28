# source: repo
dots apply > /dev/null
printf "let g:dotfiles_indent = 4\nlet g:dotfiles_foldmethod = 'marker'\n" > ~/.vimrc.before
echo "set scrolloff=9" > ~/.vimrc.local
vim -es -u ~/.vimrc -c 'set shiftwidth?' -c 'set foldmethod?' -c 'set scrolloff?' -c 'qall!' | sed 's/^ *//'
