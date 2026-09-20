" Core behavior.

set encoding=utf-8
set fileencoding=utf-8
set hidden                  " switch buffers without saving
set backspace=indent,eol,start
set autoread                " reload a file changed outside vim
set history=1000
set ttimeoutlen=10          " no lag after <Esc>
set updatetime=300
set mouse=a                 " mouse in all modes; shift-drag for terminal select
set clipboard^=unnamedplus  " yank/paste through the system clipboard when available
set nomodeline              " modelines are a classic attack surface
filetype plugin indent on
