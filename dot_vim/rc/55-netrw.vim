" 55-netrw.vim -- the built-in file browser as a tree.
"
"   :Explore  or  -   open the browser in the current file's directory
"   <leader>e         toggle a 25-column tree on the left
"
" Knobs (set in ~/.vimrc.before):
"   g:dotfiles_netrw_hidden   1 = show dotfiles   default: 1

let g:netrw_banner = 0            " no header
let g:netrw_liststyle = 3         " tree
let g:netrw_winsize = 25          " width of the side window, percent
let g:netrw_browse_split = 4      " open files in the previous window
let g:netrw_altv = 1              " vertical splits to the right
let g:netrw_keepdir = 0           " browsing changes the cwd
let g:netrw_localcopydircmd = 'cp -r'
if !get(g:, 'dotfiles_netrw_hidden', 1)
  let g:netrw_list_hide = '\(^\|\s\s\)\zs\.\S\+'
endif

nnoremap <silent> - :Explore<CR>
nnoremap <silent> <leader>e :Lexplore<CR>
