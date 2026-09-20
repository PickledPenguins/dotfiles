" 25-completion.vim -- command-line and insert-mode completion.

" command line: Tab shows a menu, longest common prefix first
set wildmenu
set wildmode=longest:full,full
set wildignorecase
set wildignore+=*.o,*.obj,*.pyc,*.class,*.swp,*~
set wildignore+=*/.git/*,*/__pycache__/*,*/node_modules/*,*/.venv/*,*/build/*
if has('patch-8.2.4325') | set wildoptions+=pum | endif   " vertical popup menu

" insert mode: Ctrl-N / Ctrl-P / Ctrl-X Ctrl-O
set completeopt=menuone,longest,preview
set complete-=i             " do not scan included files (slow on big trees)
set complete-=t             " nor tags; Ctrl-X Ctrl-] does that on demand
set omnifunc=syntaxcomplete#Complete
set pumheight=12            " popup menu rows
set infercase               " completion keeps the case of what was typed

" spelling suggestions from the popup when spell is on
set spelllang=en_us
set spellsuggest=best,9
