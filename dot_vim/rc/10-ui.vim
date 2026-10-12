" 10-ui.vim: what the screen shows: numbers, the current line, invisible
" characters, wrapping, colors, the cursor.
"
" Each setting has its description in the comment above it.  A setting with
" " directly in front of it ("set cursorcolumn) is off: delete that " to turn
" it on, or add one to turn a setting off.  `dots options WORD` searches
" every file.  For one machine only, put the line in ~/.vimrc.local instead.
"
" Knobs (set in ~/.vimrc.before):
"   g:dotfiles_colorscheme   scheme name   default: 'desert'

" ── Numbers and position ────────────────────────────────────────────────

" Syntax colors.
syntax enable

" Line numbers.
set number

" Line numbers relative to the cursor (the current line keeps its own
" number with the line above): 5j and d3k without counting.
"set relativenumber

" line,column at the bottom right, and a pending operator (d2...) beside it.
set ruler
set showcmd

" -- INSERT -- and the other mode names in the command line.
set showmode

" A status line on every window, even alone (15-statusline.vim fills it).
set laststatus=2

" Two lines for the command line, so long messages need no Enter.
"set cmdheight=2

" ── Current line and column ─────────────────────────────────────────────

" Highlight the cursor's line, in the active window only.
set cursorline
augroup dotfiles_cursorline
  autocmd!
  autocmd WinEnter,BufEnter * setlocal cursorline
  autocmd WinLeave          * setlocal nocursorline
augroup END

" Highlight the cursor's column too, for lining up YAML or tables.  Slows
" redrawing in big files.
"set cursorcolumn

" A vertical line at column 80, to see when lines get long (python's
" is at 100, 45-filetypes.vim).
"set colorcolumn=80

" ── Scrolling and splitting ─────────────────────────────────────────────

" Keep 5 lines above and below the cursor, and 5 columns beside it.
set scrolloff=5
set sidescrolloff=5

" Show as much of a long last line as fits instead of a column of @.
set display=lastline

" New splits open below and to the right.
set splitbelow splitright

" ── Characters ──────────────────────────────────────────────────────────

" Show tabs as » filled with · to their width (»··· at tabstop 4), trailing
" spaces as ·, non-breaking spaces as ␣, and › ‹ where a line runs off the
" screen.
set list listchars=tab:»·,trail:·,nbsp:␣,extends:›,precedes:‹

" Mark line ends with ¬ as well.
"set listchars+=eol:¬

" No ~ on the empty lines after the end of the file.
"set fillchars+=eob:\

" A solid bar between vertical splits instead of |.
"set fillchars+=vert:│

" ── Wrapping ────────────────────────────────────────────────────────────

" Wrap long lines on screen at a word boundary, keeping their indent, and
" mark the continuation with ↪.  The file itself is not changed.
set wrap linebreak
set breakindent
let &showbreak = '↪ '

" Long lines run off the right edge instead of wrapping (scroll with zl, zh).
"set nowrap

" ── Messages and bells ──────────────────────────────────────────────────

" No intro screen on an empty vim.
set shortmess+=I

" Show the match count when searching: [3/10].
set shortmess-=S

" Never beep or flash.
set belloff=all

" Do not redraw in the middle of a macro or a mapping (faster).
set lazyredraw

" Briefly jump to the matching bracket when typing one.
set showmatch matchtime=2

" The sign column (git, linters) appears only when there are signs.
set signcolumn=auto

" vim sets the terminal title to the file name.  Replaces the shell's
" title from 65-title.sh while vim runs.
"set title

" ── Colors ──────────────────────────────────────────────────────────────

" 24-bit colors when the terminal says it has them ($COLORTERM, set by
" 00-env.sh); schemes then look as designed.
if has('termguicolors') && ($COLORTERM ==# 'truecolor' || $COLORTERM ==# '24bit')
  set termguicolors
endif

" Dark background: schemes pick their dark variant.
set background=dark

" Light background instead: schemes pick their light variant.
"set background=light

" The colorcolumn marks in a quiet slate gray instead of the scheme's red:
" dark on a dark background, light on a light one.  Set again whenever a
" color scheme loads.
augroup dotfiles_colorcolumn
  autocmd!
  autocmd ColorScheme * if &background ==# 'dark'
        \ | highlight ColorColumn ctermbg=238 guibg=#3c4450
        \ | else
        \ | highlight ColorColumn ctermbg=254 guibg=#e4e8ee
        \ | endif
augroup END

" The color scheme, from the knob.  Built in: blue darkblue default delek
" desert elflord evening habamax industry koehler lunaperche morning murphy
" pablo peachpuff quiet retrobox ron shine slate sorbet torte wildcharm
" zaibatsu zellner (:colorscheme <Tab> lists what this vim has).
execute 'silent! colorscheme' get(g:, 'dotfiles_colorscheme', 'desert')

" Yanked text flashes briefly, to show what was copied.  Vim 9.1's hlyank
" package; an older vim has none.
silent! packadd! hlyank

" ── Cursor ──────────────────────────────────────────────────────────────

" Cursor shape: a bar in insert mode, an underline in replace mode, a block
" otherwise (xterm, tmux, kitty and most terminals).
let &t_SI = "\e[6 q"
let &t_SR = "\e[4 q"
let &t_EI = "\e[2 q"
