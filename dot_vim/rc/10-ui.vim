" 10-ui.vim -- what the screen shows.
"
" Knobs (set in ~/.vimrc.before):
"   g:dotfiles_colorscheme    scheme name                   default: 'desert'
"   g:dotfiles_relativenumber 1 = relative line numbers      default: 0
"   g:dotfiles_colorcolumn    column to mark, 0 for none     default: 0
"   g:dotfiles_truecolor      1 = 24-bit color when TERM allows  default: 1

syntax enable
set number                  " line numbers
if get(g:, 'dotfiles_relativenumber', 0) | set relativenumber | endif
set ruler                   " line,col in the status area
set showcmd                 " pending operator in the bottom right
set showmode
set laststatus=2            " always a status line (15-statusline.vim fills it)
set cursorline              " highlight the current line ...
augroup dotfiles_cursorline " ... only in the active window
  autocmd!
  autocmd WinEnter,BufEnter * setlocal cursorline
  autocmd WinLeave          * setlocal nocursorline
augroup END
set scrolloff=5             " keep 5 lines above/below the cursor
set sidescrolloff=5
set display=lastline        " show as much of a long last line as fits
set list listchars=tab:»\ ,trail:·,nbsp:␣,extends:›,precedes:‹
set splitbelow splitright   " new splits go below / right
set shortmess+=I            " no intro screen
set belloff=all             " never beep or flash
set lazyredraw              " no redraw in the middle of a macro
set showmatch matchtime=2   " blink the matching bracket briefly
set signcolumn=auto
set wrap linebreak          " wrap long lines at word boundaries ...
set breakindent             " ... keeping the indent
let &showbreak = '↪ '

if get(g:, 'dotfiles_colorcolumn', 0)
  let &colorcolumn = g:dotfiles_colorcolumn
endif

if get(g:, 'dotfiles_truecolor', 1) && has('termguicolors')
      \ && ($COLORTERM ==# 'truecolor' || $COLORTERM ==# '24bit')
  set termguicolors
endif
set background=dark
execute 'silent! colorscheme' get(g:, 'dotfiles_colorscheme', 'desert')

" Cursor shape: bar in insert, block in normal (xterm, tmux, most emulators)
let &t_SI = "\e[6 q"
let &t_SR = "\e[4 q"
let &t_EI = "\e[2 q"
