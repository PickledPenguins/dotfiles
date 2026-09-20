" 50-keys.vim -- key mappings.  Leader is space.
"
" Knobs (set in ~/.vimrc.before):
"   g:dotfiles_leader   leader key   default: ' '

let mapleader = get(g:, 'dotfiles_leader', ' ')
let maplocalleader = ','

" ── everyday ──────────────────────────────────────────────────────────────
" clear search highlight
nnoremap <silent> <leader><space> :nohlsearch<CR>
nnoremap <leader>w :write<CR>
nnoremap <leader>q :quit<CR>
nnoremap <leader>Q :qall!<CR>
" Y like D and C
nnoremap Y y$
" move by screen line when wrapped
nnoremap j gj
nnoremap k gk
" keep the match centered
nnoremap n nzzzv
nnoremap N Nzzzv
" edit local overrides
nnoremap <silent> <leader>ev :edit ~/.vimrc.local<CR>
" reload everything
nnoremap <silent> <leader>sv :source ~/.vimrc<CR>

" ── windows and buffers ───────────────────────────────────────────────────
nnoremap <C-h> <C-w>h
nnoremap <C-j> <C-w>j
nnoremap <C-k> <C-w>k
nnoremap <C-l> <C-w>l
nnoremap <leader>v :vsplit<CR>
nnoremap <leader>s :split<CR>
nnoremap <leader>n :bnext<CR>
nnoremap <leader>p :bprevious<CR>
nnoremap <leader>d :bdelete<CR>
" list, then pick by number
nnoremap <leader>b :ls<CR>:buffer<Space>
nnoremap <Tab> :bnext<CR>
nnoremap <S-Tab> :bprevious<CR>

" ── editing ───────────────────────────────────────────────────────────────
" keep selection after shifting
xnoremap < <gv
xnoremap > >gv
" move selected lines down / up
xnoremap J :move '>+1<CR>gv=gv
xnoremap K :move '<-2<CR>gv=gv
" undoable Ctrl-U / Ctrl-W
inoremap <C-u> <C-g>u<C-u>
inoremap <C-w> <C-g>u<C-w>
" system clipboard explicitly
nnoremap <leader>y "+y
xnoremap <leader>y "+y
nnoremap <leader>P "+p
" write a file opened read-only
cnoremap w!! w !sudo tee % > /dev/null
" toggle spelling
nnoremap <leader>ss :setlocal spell!<CR>
" toggle wrap
nnoremap <leader>tw :setlocal wrap!<CR>
" toggle relative numbers
nnoremap <leader>tn :setlocal relativenumber!<CR>
" toggle invisible characters
nnoremap <leader>tl :setlocal list!<CR>

" ── quickfix / location list ──────────────────────────────────────────────
nnoremap ]q :cnext<CR>
nnoremap [q :cprevious<CR>
nnoremap ]l :lnext<CR>
nnoremap [l :lprevious<CR>
nnoremap <leader>co :copen<CR>
nnoremap <leader>cc :cclose<CR>

" ── paste mode (no auto-indent while pasting into the terminal) ───────────
if exists('&pastetoggle') | set pastetoggle=<F2> | endif
