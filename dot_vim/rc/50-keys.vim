" 50-keys.vim -- key mappings.  The leader is a comma.  Mapping lines take no
" trailing comment: it would become part of the mapping.
"
" Each setting has its description in the comment above it.  A setting with
" " directly in front of it ("set cursorcolumn) is off: delete that " to turn
" it on, or add one to turn a setting off.  `dots options WORD` searches
" every file.  For one machine only, put the line in ~/.vimrc.local instead.
" :map lists what is mapped; :verbose map KEY says where.
"
" Knobs (set in ~/.vimrc.before):
"   g:dotfiles_leader   leader key   default: ','

" The leader key starts the <leader> mappings below (from the knob).  A
" comma loses its own meaning, "repeat the last f/t backward": it now waits
" for the rest of a mapping first.
let mapleader = get(g:, 'dotfiles_leader', ',')

" The local leader, for filetype plugins' own mappings, is a backslash
" (vim's default), so those never take the leader's keys.
let maplocalleader = '\'

" Runs an Ex command and puts the cursor and scroll position back after it.
function! s:KeepView(command) abort
  let l:view = winsaveview()
  execute a:command
  call winrestview(l:view)
endfunction

" ── Everyday ────────────────────────────────────────────────────────────

" <leader><space> clears the search highlight.
nnoremap <silent> <leader><space> :nohlsearch<CR>

" <leader>qq closes the window and deletes its buffer, as :bdelete does: the
" file leaves the buffer list and memory.  A buffer another window still
" shows stays.  Refuses unsaved changes; <leader>QQ throws them away (:quit!).
" In the last window both quit vim.  <leader>qa quits vim (:qall), refusing
" while anything is unsaved.
function! s:Close(bang) abort
  let l:buffer = bufnr('%')
  if a:bang ==# '' && &modified && len(win_findbuf(l:buffer)) == 1
    echoerr 'E37: No write since last change (add ! to override)'
    return
  endif
  execute 'quit' . a:bang
  if bufexists(l:buffer) && empty(win_findbuf(l:buffer))
    execute 'bdelete' . a:bang l:buffer
  endif
endfunction
nnoremap <silent> <leader>qq :call <SID>Close('')<CR>
nnoremap <silent> <leader>QQ :call <SID>Close('!')<CR>
nnoremap <leader>qa :qall<CR>

" Y yanks to the end of the line, as D and C work.
nnoremap Y y$

" j and k move by screen line through a wrapped line.
nnoremap j gj
nnoremap k gk

" n and N keep the match in the middle of the screen, folds opened.
nnoremap n nzzzv
nnoremap N Nzzzv

" <leader>ev edits ~/.vimrc.local.
nnoremap <silent> <leader>ev :edit ~/.vimrc.local<CR>

" <leader>cd changes vim's directory to the current file's.
nnoremap <leader>cd :cd %:p:h<CR>:pwd<CR>

" <leader>cp copies the current file's full path to the system clipboard.
nnoremap <leader>cp :let @+ = expand('%:p')<CR>:echo @+<CR>



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

" <leader>sv splits vertically, <leader>sh horizontally.
nnoremap <leader>sv :vsplit<CR>
nnoremap <leader>sh :split<CR>

" <leader>z zooms the current window to fill the screen, and again puts
" every window back at its size (or evens them out, if one was opened or
" closed meanwhile).  The other windows stay open, squeezed to a line.
function! s:ToggleZoom() abort
  if exists('t:zoom_sizes')
    if winnr('$') == t:zoom_count
      execute t:zoom_sizes
    else
      wincmd =
    endif
    unlet t:zoom_sizes t:zoom_count
  else
    let t:zoom_sizes = winrestcmd()
    let t:zoom_count = winnr('$')
    resize
    vertical resize
  endif
endfunction
nnoremap <silent> <leader>z :call <SID>ToggleZoom()<CR>

" <leader>bn next buffer, <leader>bp previous, <leader>bd delete it.
nnoremap <leader>bn :bnext<CR>
nnoremap <leader>bp :bprevious<CR>
nnoremap <leader>bd :bdelete<CR>

" <leader><leader> goes back to the file before this one (Ctrl-^).
nnoremap <leader><leader> <C-^>

" <leader>bl lists buffers, then waits for the number of one to open.
nnoremap <leader>bl :ls<CR>:buffer<Space>

" Tab and Shift-Tab switch buffers.  Tab is also Ctrl-I, so Ctrl-I no
" longer jumps forward in the jump list.
nnoremap <Tab> :bnext<CR>
nnoremap <S-Tab> :bprevious<CR>

" ── Finding ─────────────────────────────────────────────────────────────

" <leader>f opens a file by name from anywhere below the current directory
" (:find, with 'path' from 25-completion.vim; Tab completes).
nnoremap <leader>f :find<Space>

" <leader>gg searches the files below the current directory (:grep, from
" 20-search.vim); <leader>/ searches them for the word under the cursor.
" The matches open in the quickfix list.
nnoremap <leader>gg :grep<Space>
nnoremap <silent> <leader>/ :silent grep! -w <C-r><C-w><CR>:redraw!<CR>

" <leader>gb shows git blame for the current line, or the selected lines.
function! s:Blame(first, last) abort
  execute '!git -C' shellescape(expand('%:p:h'), 1) 'blame -L' a:first . ',' . a:last
        \ '--' shellescape(expand('%:t'), 1)
endfunction
nnoremap <silent> <leader>gb :call <SID>Blame(line('.'), line('.'))<CR>
xnoremap <silent> <leader>gb :<C-u>call <SID>Blame(line("'<"), line("'>"))<CR>

" ── Editing ─────────────────────────────────────────────────────────────

" J and K in visual mode move the selected lines down and up, re-indented.
xnoremap J :move '>+1<CR>gv=gv
xnoremap K :move '<-2<CR>gv=gv

" Ctrl-U and Ctrl-W in insert mode can be undone on their own.
inoremap <C-u> <C-g>u<C-u>
inoremap <C-w> <C-g>u<C-w>

" <leader>y yanks to the system clipboard; <leader>p and <leader>P put from
" it after and before the cursor, as p and P do.  Over a selection both
" replace it; <leader>p yanks what was there, <leader>P keeps the register.
nnoremap <leader>y "+y
xnoremap <leader>y "+y
nnoremap <leader>p "+p
nnoremap <leader>P "+P
xnoremap <leader>p "+p
xnoremap <leader>P "+P

" <leader>o and <leader>O add a blank line below and above (a count: that
" many) and stay in normal mode.
nnoremap <silent> <leader>o :<C-u>call append(line('.'), repeat([''], v:count1))<CR>
nnoremap <silent> <leader>O :<C-u>call append(line('.') - 1, repeat([''], v:count1))<CR>

" <leader>id puts today's date (2026-01-31) after the cursor.
nnoremap <leader>id "=strftime('%Y-%m-%d')<CR>p

" <leader>rw starts replacing the word under the cursor everywhere in the
" file, matching its case exactly (\C, whatever 'ignorecase' says);
" <leader>ri in any case (\c).  gdefault in 20-search.vim makes it every
" match on a line.
nnoremap <leader>rw :%s/\C\<<C-r><C-w>\>//<Left>
nnoremap <leader>ri :%s/\c\<<C-r><C-w>\>//<Left>

" gV selects the text just pasted or changed.
nnoremap gV `[v`]

" :w!! writes a file that was opened without permission, through sudo.
cnoremap w!! w !sudo tee % > /dev/null

" Ctrl-A and Ctrl-E move to the start and end of the command line, as in
" bash.  Loses Ctrl-A's "insert every match".
"cnoremap <C-a> <Home>
"cnoremap <C-e> <End>

" ── Comments ────────────────────────────────────────────────────────────

" Whether LINE, past its indent, starts with the comment marker OPEN and
" ends with CLOSE (empty for languages whose comments run to the line end).
function! s:IsComment(line, open, close) abort
  let l:text = substitute(a:line, '^\s*\|\s*$', '', 'g')
  return stridx(l:text, a:open) == 0
        \ && (a:close ==# '' || strpart(l:text, len(l:text) - len(a:close)) ==# a:close)
endfunction

" LINE without its comment marker, its indent kept.
function! s:Uncomment(line, open, close) abort
  let l:indent = matchstr(a:line, '^\s*')
  let l:text = substitute(strpart(a:line, len(l:indent)), '\s*$', '', '')
  let l:text = strpart(l:text, len(a:open), len(l:text) - len(a:open) - len(a:close))
  return l:indent . substitute(l:text, '^ \| $', '', 'g')
endfunction

" <leader>cc comments the current line (a count: that many lines) or the
" selected lines, or uncomments them when every non-blank one already is a
" comment.  The marker comes from 'commentstring' (# in python, /* */ in C)
" and goes at the smallest indent; blank lines are left alone.
function! s:ToggleComment(first, last) abort
  if &commentstring !~# '%s'
    echoerr "no 'commentstring' for filetype '" . &filetype . "'"
    return
  endif
  let [l:open, l:close] = map(split(&commentstring, '%s', 1), 'substitute(v:val, ''^\s\+\|\s\+$'', "", "g")')
  let l:lines = filter(range(a:first, min([a:last, line('$')])), 'getline(v:val) =~ ''\S''')
  if empty(l:lines)
    return
  endif
  if empty(filter(copy(l:lines), '!s:IsComment(getline(v:val), l:open, l:close)'))
    for l:n in l:lines
      call setline(l:n, s:Uncomment(getline(l:n), l:open, l:close))
    endfor
  else
    let l:col = min(map(copy(l:lines), 'matchend(getline(v:val), ''^\s*'')'))
    for l:n in l:lines
      let l:line = getline(l:n)
      call setline(l:n, strpart(l:line, 0, l:col) . l:open . ' ' . strpart(l:line, l:col)
            \ . (l:close ==# '' ? '' : ' ' . l:close))
    endfor
  endif
endfunction
nnoremap <silent> <leader>cc :<C-u>call <SID>ToggleComment(line('.'), line('.') + v:count1 - 1)<CR>
xnoremap <silent> <leader>cc :<C-u>call <SID>ToggleComment(line("'<"), line("'>"))<CR>

" gc comments as an operator: gcc a line, gcip a paragraph, gc over a
" selection; ic and ac select a comment.  Vim 9.1's comment package; an
" older vim has none, and <leader>cc above still works there.
silent! packadd! comment

" ── Cleaning up ─────────────────────────────────────────────────────────

" <leader>ww fixes whitespace when asked, never on its own: strips trailing
" whitespace and turns tabs into spaces, tabstop wide (:retab; a buffer
" with noexpandtab, make or go, keeps its tabs).  In the whole file, or in
" the selected lines.
function! s:FixWhitespace(first, last) abort
  let l:range = a:first . ',' . a:last
  call s:KeepView('keeppatterns ' . l:range . 's/\s\+$//e | ' . l:range . 'retab')
endfunction
nnoremap <silent> <leader>ww :call <SID>FixWhitespace(1, line('$'))<CR>
xnoremap <silent> <leader>ww :<C-u>call <SID>FixWhitespace(line("'<"), line("'>"))<CR>

" <leader>= re-indents the whole file by the filetype's indent rules.
nnoremap <silent> <leader>= :call <SID>KeepView('normal! gg=G')<CR>

" <leader>ss sorts the file, or the selected lines; <leader>uu sorts them
" and drops repeated ones.
nnoremap <leader>ss :sort<CR>
xnoremap <leader>ss :sort<CR>
nnoremap <leader>uu :sort u<CR>
xnoremap <leader>uu :sort u<CR>

" <leader>j lays out the JSON in the buffer, or in the selection (JSON
" inside a log line, say), two spaces deep.  Invalid JSON leaves the text
" as it was and shows python's error.  The z and unnamed registers come
" through unchanged.  Needs: python3.9+.
function! s:FormatJson(visual) abort
  if a:visual
    let l:saved = [getreginfo('z'), getreginfo('"')]
    normal! gv"zy
    let l:text = getreg('z', 1, 1)
  else
    let l:text = getline(1, '$')
  endif
  let l:out = systemlist('python3 -m json.tool --indent 2', l:text)
  if v:shell_error
    if a:visual
      call setreg('z', l:saved[0])
      call setreg('"', l:saved[1])
    endif
    echoerr join(l:out)
    return
  endif
  if a:visual
    call setreg('z', l:out, visualmode() ==# 'V' ? 'l' : 'v')
    normal! gv"zP
    call setreg('z', l:saved[0])
    call setreg('"', l:saved[1])
  else
    let l:view = winsaveview()
    silent %delete _
    call setline(1, l:out)
    call winrestview(l:view)
  endif
endfunction
nnoremap <silent> <leader>j :call <SID>FormatJson(0)<CR>
xnoremap <silent> <leader>j :<C-u>call <SID>FormatJson(1)<CR>

" ── Toggles ─────────────────────────────────────────────────────────────

" <leader>sc spelling, <leader>wr wrap, <leader>tn relative numbers,
" <leader>tl invisible characters.
nnoremap <leader>sc :setlocal spell!<CR>
nnoremap <leader>wr :setlocal wrap!<CR>
nnoremap <leader>tn :setlocal relativenumber!<CR>
nnoremap <leader>tl :setlocal list!<CR>

" F2 toggles paste mode (no auto-indent while pasting into a terminal
" without bracketed paste).
if exists('&pastetoggle') | set pastetoggle=<F2> | endif

" ── Quickfix and location lists ─────────────────────────────────────────

" ]q [q next and previous error, ]l [l the same in the location list.
nnoremap ]q :cnext<CR>
nnoremap [q :cprevious<CR>
nnoremap ]l :lnext<CR>
nnoremap [l :lprevious<CR>

" <leader>co opens the quickfix list, or closes it when it is open.
function! s:ToggleQuickfix() abort
  if empty(filter(getwininfo(), 'v:val.quickfix && !v:val.loclist'))
    copen
  else
    cclose
  endif
endfunction
nnoremap <silent> <leader>co :call <SID>ToggleQuickfix()<CR>

" ── Terminal ────────────────────────────────────────────────────────────

" Esc twice in a :terminal window returns to normal mode (the default is
" Ctrl-W N).  A program in it that uses Esc sees the first one late.
"tnoremap <Esc><Esc> <C-\><C-n>
