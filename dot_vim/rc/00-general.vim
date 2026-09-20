" 00-general.vim -- core behavior that every other module assumes.
"
" Knobs (set in ~/.vimrc.before):
"   g:dotfiles_mouse      mouse mode string, '' for none      default: 'a'
"   g:dotfiles_clipboard  1 = yank/paste use the system clipboard  default: 1

set encoding=utf-8
scriptencoding utf-8
set fileencoding=utf-8
set fileformats=unix,dos,mac

set hidden                  " switch buffers without saving first
set backspace=indent,eol,start
set autoread                " reload a file changed outside vim ...
augroup dotfiles_autoread   " ... as soon as vim regains focus or the cursor stops
  autocmd!
  autocmd FocusGained,BufEnter,CursorHold * silent! checktime
augroup END
set history=1000
set ttimeout ttimeoutlen=10 " no lag after <Esc> in a terminal
set updatetime=300          " CursorHold and swap write after 300 ms idle
set nomodeline              " modelines in files are a classic attack surface
set nrformats-=octal        " Ctrl-A on 007 gives 008, not 010
set formatoptions+=j        " join lines removes a comment leader
set nojoinspaces            " one space after a period when joining
set virtualedit=block       " visual block can extend past line ends
set nostartofline           " keep the column when paging

let &mouse = get(g:, 'dotfiles_mouse', 'a')       " shift-drag still selects in the terminal
if get(g:, 'dotfiles_clipboard', 1) && has('clipboard')
  set clipboard^=unnamedplus,unnamed
endif

filetype plugin indent on
