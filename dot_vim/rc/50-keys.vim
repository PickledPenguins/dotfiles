" 50-keys.vim -- key mappings.  The leader is Space.  Mapping lines take no
" trailing comment: it would become part of the mapping.
"
" Each setting has its description in the comment above it.  A setting with
" " directly in front of it ("set cursorcolumn) is off: delete that " to turn
" it on, or add one to turn a setting off.  `dots options WORD` searches
" every file.  For one machine only, put the line in ~/.vimrc.local instead.
" :map lists what is mapped; :verbose map KEY says where.
"
" Knobs (set in ~/.vimrc.before):
"   g:dotfiles_leader   leader key   default: ' '

" The leader key starts the <leader> mappings below (from the knob); the
" local leader, for filetype plugins, is a comma.
let mapleader = get(g:, 'dotfiles_leader', ' ')
let maplocalleader = ','

" ── Everyday ────────────────────────────────────────────────────────────

" <leader><space> clears the search highlight.
nnoremap <silent> <leader><space> :nohlsearch<CR>

" <leader>w write, <leader>q quit, <leader>Q quit everything without saving.
nnoremap <leader>w :write<CR>
nnoremap <leader>q :quit<CR>
nnoremap <leader>Q :qall!<CR>

" Y yanks to the end of the line, as D and C work.
nnoremap Y y$

" j and k move by screen line through a wrapped line.
nnoremap j gj
nnoremap k gk

" n and N keep the match in the middle of the screen, folds opened.
nnoremap n nzzzv
nnoremap N Nzzzv

" <leader>ev edits ~/.vimrc.local; <leader>sv reloads the whole configuration.
nnoremap <silent> <leader>ev :edit ~/.vimrc.local<CR>
nnoremap <silent> <leader>sv :source ~/.vimrc<CR>

" <leader>cd changes vim's directory to the current file's.
nnoremap <leader>cd :cd %:p:h<CR>:pwd<CR>

" <leader>x makes the current file executable.
nnoremap <silent> <leader>x :!chmod +x %<CR>

" F5 saves and runs the current file (it needs a #! line and execute permission).
nnoremap <F5> :write <Bar> !%:p<CR>

" jk in insert mode is Esc, without reaching for it.  Typing a real "jk"
" then needs a pause between the letters.
"inoremap jk <Esc>

" ; starts a command, like :, without Shift.  Loses ; as "repeat the last f/t".
"nnoremap ; :

" Q formats text (gq) instead of entering Ex mode.
"nnoremap Q gq

" Ctrl-S saves in normal and insert mode (10-options.sh frees Ctrl-S from
" terminal flow control).
"nnoremap <C-s> :write<CR>
"inoremap <C-s> <C-o>:write<CR>

" Ctrl-D and Ctrl-U keep the cursor in the middle of the screen.
"nnoremap <C-d> <C-d>zz
"nnoremap <C-u> <C-u>zz

" J joins lines without moving the cursor.
"nnoremap J mzJ`z

" Arrow keys do nothing in normal mode: practice for hjkl.
"nnoremap <Up> <Nop>
"nnoremap <Down> <Nop>
"nnoremap <Left> <Nop>
"nnoremap <Right> <Nop>

" ── Windows and buffers ─────────────────────────────────────────────────

" Ctrl-h/j/k/l move between windows.  Ctrl-l no longer redraws the screen;
" :redraw! does.
nnoremap <C-h> <C-w>h
nnoremap <C-j> <C-w>j
nnoremap <C-k> <C-w>k
nnoremap <C-l> <C-w>l

" Ctrl and the arrow keys resize the current window.
nnoremap <C-Up> :resize +2<CR>
nnoremap <C-Down> :resize -2<CR>
nnoremap <C-Left> :vertical resize -2<CR>
nnoremap <C-Right> :vertical resize +2<CR>

" <leader>v and <leader>s split vertically and horizontally.
nnoremap <leader>v :vsplit<CR>
nnoremap <leader>s :split<CR>

" <leader>n next buffer, <leader>p previous, <leader>d delete it.
nnoremap <leader>n :bnext<CR>
nnoremap <leader>p :bprevious<CR>
nnoremap <leader>d :bdelete<CR>

" <leader>b lists buffers, then waits for the number of one to open.
nnoremap <leader>b :ls<CR>:buffer<Space>

" Tab and Shift-Tab switch buffers.  Tab is also Ctrl-I, so Ctrl-I no
" longer jumps forward in the jump list.
nnoremap <Tab> :bnext<CR>
nnoremap <S-Tab> :bprevious<CR>

" ── Editing ─────────────────────────────────────────────────────────────

" J and K in visual mode move the selected lines down and up, re-indented.
xnoremap J :move '>+1<CR>gv=gv
xnoremap K :move '<-2<CR>gv=gv

" Ctrl-U and Ctrl-W in insert mode can be undone on their own.
inoremap <C-u> <C-g>u<C-u>
inoremap <C-w> <C-g>u<C-w>

" <leader>y yanks to the system clipboard, <leader>P puts from it.
nnoremap <leader>y "+y
xnoremap <leader>y "+y
nnoremap <leader>P "+p

" <leader>p over a visual selection replaces it without yanking what was
" there, so the same text can be put again.
xnoremap <leader>p "_dP

" <leader>rw starts replacing the word under the cursor everywhere in the
" file (gdefault in 20-search.vim makes it every match on a line).
nnoremap <leader>rw :%s/\<<C-r><C-w>\>//<Left>

" ,ww (the local leader, then ww) fixes whitespace when asked, never on its
" own: strips trailing whitespace and turns tabs into spaces, tabstop wide
" (:retab; a buffer with noexpandtab, make or go, keeps its tabs).
function! s:FixWhitespace() abort
  let l:view = winsaveview()
  keeppatterns %s/\s\+$//e
  retab
  call winrestview(l:view)
endfunction
nnoremap <silent> <localleader>ww :call <SID>FixWhitespace()<CR>

" gV selects the text just pasted or changed.
nnoremap gV `[v`]

" :w!! writes a file that was opened without permission, through sudo.
cnoremap w!! w !sudo tee % > /dev/null

" Ctrl-A and Ctrl-E move to the start and end of the command line, as in
" bash.  Loses Ctrl-A's "insert every match".
"cnoremap <C-a> <Home>
"cnoremap <C-e> <End>

" ── Toggles ─────────────────────────────────────────────────────────────

" <leader>ss spelling, <leader>tw wrap, <leader>tn relative numbers,
" <leader>tl invisible characters, <leader>tc the cursor column.
nnoremap <leader>ss :setlocal spell!<CR>
nnoremap <leader>tw :setlocal wrap!<CR>
nnoremap <leader>tn :setlocal relativenumber!<CR>
nnoremap <leader>tl :setlocal list!<CR>
nnoremap <leader>tc :setlocal cursorcolumn!<CR>

" F2 toggles paste mode (no auto-indent while pasting into a terminal
" without bracketed paste).
if exists('&pastetoggle') | set pastetoggle=<F2> | endif

" ── Quickfix and location lists ─────────────────────────────────────────

" ]q [q next and previous error, ]l [l the same in the location list,
" <leader>co opens the list, <leader>cc closes it.
nnoremap ]q :cnext<CR>
nnoremap [q :cprevious<CR>
nnoremap ]l :lnext<CR>
nnoremap [l :lprevious<CR>
nnoremap <leader>co :copen<CR>
nnoremap <leader>cc :cclose<CR>

" ── Terminal ────────────────────────────────────────────────────────────

" Esc twice in a :terminal window returns to normal mode (the default is
" Ctrl-W N).  A program in it that uses Esc sees the first one late.
"tnoremap <Esc><Esc> <C-\><C-n>
