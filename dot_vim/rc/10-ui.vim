" What the screen shows.

syntax enable
set number                  " line numbers
set ruler
set showcmd                 " pending operator in the bottom right
set showmode
set laststatus=2            " always a status line
set cursorline
set scrolloff=5             " keep 5 lines above/below the cursor
set sidescrolloff=5
set wildmenu                " Tab-completion menu for : commands
set wildmode=longest:full,full
set wildignore+=*.o,*.pyc,*.swp,*/.git/*,*/__pycache__/*
set list listchars=tab:»\ ,trail:·,nbsp:␣
set splitbelow splitright   " new splits go below / right
set shortmess+=I            " no intro screen
set belloff=all
set background=dark
silent! colorscheme desert
