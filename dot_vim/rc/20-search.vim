" 20-search.vim -- searching and substitution.

set hlsearch                " highlight matches ...
set incsearch               " ... as the pattern is typed
set ignorecase              " case-insensitive ...
set smartcase               " ... unless the pattern has a capital
set wrapscan                " continue from the top after the last match
set gdefault                " :s///  replaces every match on the line; add g to undo
if exists('&inccommand') | set inccommand=nosplit | endif   " live :s preview (vim 9.1+ / nvim)

" grep with ripgrep when it is installed:  :grep PATTERN  then :copen
if executable('rg')
  set grepprg=rg\ --vimgrep\ --smart-case\ --hidden\ --glob\ '!.git'
  set grepformat=%f:%l:%c:%m
endif

" open the quickfix window after any :grep / :make
augroup dotfiles_quickfix
  autocmd!
  autocmd QuickFixCmdPost [^l]* cwindow
  autocmd QuickFixCmdPost l*    lwindow
augroup END

" * and # search for the visual selection
xnoremap * y/\V<C-r>=escape(@",'/\')<CR><CR>
xnoremap # y?\V<C-r>=escape(@",'?\')<CR><CR>
