" 35-folding.vim -- folds exist but start open.
"
"   za toggle   zR open all   zM close all   zj/zk next/previous fold
"
" Each setting has its description in the comment above it.  A setting with
" " directly in front of it ("set cursorcolumn) is off: delete that " to turn
" it on, or add one to turn a setting off.  `dots options WORD` searches
" every file.  For one machine only, put the line in ~/.vimrc.local instead.
"
" Knobs (set in ~/.vimrc.before):
"   g:dotfiles_foldmethod   indent | syntax | marker | manual   default: 'indent'

" Folds follow the indentation (or the knob's method); at most 5 deep.
let &foldmethod = get(g:, 'dotfiles_foldmethod', 'indent')
set foldnestmax=5

" Every fold open when a file loads, and folding off until the first za.
set foldlevelstart=99
set nofoldenable

" Folding on from the start (still all open, from foldlevelstart).
"set foldenable

" A column at the left showing where folds are; clicking it opens and closes.
"set foldcolumn=1

" A closed fold shows its first line, then how many lines it hides.
set foldtext=DotfilesFoldText()
function! DotfilesFoldText() abort
  let l:line = substitute(getline(v:foldstart), '^\s*', '', '')
  let l:n = v:foldend - v:foldstart + 1
  return repeat(' ', indent(v:foldstart)) . l:line . '  ··· ' . l:n . ' lines'
endfunction

" Remember each file's folds and cursor across sessions (in ~/.vim/view).
" A file changed elsewhere can come back with folds in the wrong places.
"augroup dotfiles_views
  "autocmd!
  "autocmd BufWinLeave ?* silent! mkview
  "autocmd BufWinEnter ?* silent! loadview
"augroup END
