" 30-indent.vim -- indentation: spaces, width by filetype.
"
" Knobs (set in ~/.vimrc.before):
"   g:dotfiles_indent   default width                default: 2
"   g:dotfiles_tabs     1 = real tabs by default     default: 0

let s:w = get(g:, 'dotfiles_indent', 2)
let &tabstop = s:w
let &shiftwidth = s:w
set softtabstop=-1          " follow shiftwidth
if get(g:, 'dotfiles_tabs', 0) | set noexpandtab | else | set expandtab | endif
set smarttab                " Tab at line start inserts shiftwidth
set shiftround              " >> and << snap to multiples of shiftwidth
set autoindent
set smartindent

" per-filetype overrides -- a project's .editorconfig wins over these (vim 9+)
augroup dotfiles_indent
  autocmd!
  autocmd FileType python,rust,java,c,cpp,sh,bash   setlocal shiftwidth=4 tabstop=4
  autocmd FileType make,go                          setlocal noexpandtab shiftwidth=8 tabstop=8
  autocmd FileType yaml,json,html,css,javascript    setlocal shiftwidth=2 tabstop=2
augroup END

" Ctrl-T / Ctrl-D in insert mode and > < in visual mode use shiftwidth (default);
" keep visual selection after shifting
xnoremap < <gv
xnoremap > >gv
