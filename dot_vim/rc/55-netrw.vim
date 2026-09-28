" 55-netrw.vim -- netrw, vim's built-in file browser, as a tree.
"
"   :Explore or -   open the browser in the current file's directory
"   <leader>e       toggle a tree at the left
"
" Each setting has its description in the comment above it.  A setting with
" " directly in front of it ("set cursorcolumn) is off: delete that " to turn
" it on, or add one to turn a setting off.  `dots options WORD` searches
" every file.  For one machine only, put the line in ~/.vimrc.local instead.

" No help banner at the top; a tree listing (i cycles the styles); the side
" window 25% wide; files open in the window you came from, vertical splits
" to the right.
let g:netrw_banner = 0
let g:netrw_liststyle = 3
let g:netrw_winsize = 25
let g:netrw_browse_split = 4
let g:netrw_altv = 1

" Browsing a directory makes it vim's current directory.
let g:netrw_keepdir = 0

" Copying a directory copies its contents too.
let g:netrw_localcopydircmd = 'cp -r'

" Hide dotfiles (gh in the browser toggles them).
"let g:netrw_list_hide = '\(^\|\s\s\)\zs\.\S\+'

" - opens the browser; <leader>e toggles the side tree.
nnoremap <silent> - :Explore<CR>
nnoremap <silent> <leader>e :Lexplore<CR>

" Switch netrw off completely, for a file-browser plugin such as NERDTree
" or fern.  vim DIR then opens nothing useful.
"let g:loaded_netrw = 1 | let g:loaded_netrwPlugin = 1
