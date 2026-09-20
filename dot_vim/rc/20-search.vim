" Searching.

set hlsearch                " highlight matches
set incsearch               " ... as you type
set ignorecase              " case-insensitive ...
set smartcase               " ... unless the pattern has a capital
set wrapscan
if executable('rg')
  set grepprg=rg\ --vimgrep\ --smart-case
  set grepformat=%f:%l:%c:%m
endif
