" Indentation: two spaces, never tabs.  Filetype plugins may override.

set expandtab
set smarttab
set tabstop=2
set shiftwidth=2
set softtabstop=0
set shiftround              " >> and << snap to multiples of shiftwidth
set autoindent
set smartindent

augroup dotfiles_indent
  autocmd!
  autocmd FileType python,rust setlocal tabstop=4 shiftwidth=4
  autocmd FileType make,go     setlocal noexpandtab tabstop=8 shiftwidth=8
augroup END
