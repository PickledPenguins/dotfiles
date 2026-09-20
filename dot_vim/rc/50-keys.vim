" Key mappings.  Leader is space.

let mapleader = ' '

" clear search highlight
nnoremap <silent> <leader><space> :nohlsearch<CR>

" move between splits without <C-w>
nnoremap <C-h> <C-w>h
nnoremap <C-j> <C-w>j
nnoremap <C-k> <C-w>k
nnoremap <C-l> <C-w>l

" buffers
nnoremap <leader>n :bnext<CR>
nnoremap <leader>p :bprevious<CR>
nnoremap <leader>d :bdelete<CR>

" keep the selection after indenting in visual mode
vnoremap < <gv
vnoremap > >gv

" j/k move by screen line when a line wraps
nnoremap j gj
nnoremap k gk

" Y behaves like D and C
nnoremap Y y$

" write with sudo when the file was opened read-only
cnoremap w!! w !sudo tee % > /dev/null

" toggle paste mode (no auto-indent while pasting)
set pastetoggle=<F2>
