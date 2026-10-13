" 20-search.vim: searching and substitution.
"
" Each setting has its description in the comment above it. A setting with
" " directly in front of it ("set cursorcolumn) is off: delete that " to turn
" it on, or add one to turn a setting off. `dots options WORD` searches
" every file. For one machine only, put the line in ~/.vimrc.local instead.

" Highlight every match, and move to matches while the pattern is typed.
" <leader><space> clears the highlight (50-keys.vim).
set hlsearch
set incsearch

" Search ignoring case, unless the pattern has a capital letter.
set ignorecase
set smartcase

" After the last match, continue from the top.
set wrapscan

" Stop at the end of the file instead.
"set nowrapscan

" :s/a/b/ replaces every match on a line, as if /g were given; /g then
" means only the first. Surprising in commands copied from elsewhere.
set gdefault

" Show a :s substitution's result in the text while typing it (neovim
" only; vim has no such option).
if exists('&inccommand') | set inccommand=nosplit | endif

" :grep searches every file below the current directory: with ripgrep when
" it is installed, else with grep -r, skipping .git and binary files (vim's
" own default searches only the files named). :copen lists the matches.
if executable('rg')
  set grepprg=rg\ --vimgrep\ --smart-case\ --hidden\ --glob\ '!.git'
  set grepformat=%f:%l:%c:%m
else
  set grepprg=grep\ -rnI\ --exclude-dir=.git\ $*\ .
endif

" Open the quickfix or location list after :grep, :make, :vimgrep.
augroup dotfiles_quickfix
  autocmd!
  autocmd QuickFixCmdPost [^l]* cwindow
  autocmd QuickFixCmdPost l*    lwindow
augroup END

" * and # in visual mode search for the selected text.
xnoremap * y/\V<C-r>=escape(@",'/\')<CR><CR>
xnoremap # y?\V<C-r>=escape(@",'?\')<CR><CR>

" / and ? start in very magic mode: ( ) | + ? { } are regex operators
" without backslashes, as in other languages.
"nnoremap / /\v
"nnoremap ? ?\v

" Esc in normal mode also clears the search highlight. In some terminals
" mapping Esc delays or garbles arrow keys.
"nnoremap <silent> <Esc> :nohlsearch<CR><Esc>
