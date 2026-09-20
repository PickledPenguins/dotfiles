" 35-folding.vim -- folds exist but start open.
"
"   za toggle   zR open all   zM close all   zj/zk next/previous fold
"
" Knobs (set in ~/.vimrc.before):
"   g:dotfiles_foldmethod   indent | syntax | marker | manual   default: 'indent'

let &foldmethod = get(g:, 'dotfiles_foldmethod', 'indent')
set foldlevelstart=99       " everything open when a file loads
set foldnestmax=5
set nofoldenable            " off until the first za
set foldtext=DotfilesFoldText()

" fold line: first line of the fold, dashes, line count
function! DotfilesFoldText() abort
  let l:line = substitute(getline(v:foldstart), '^\s*', '', '')
  let l:n = v:foldend - v:foldstart + 1
  return repeat(' ', indent(v:foldstart)) . l:line . '  ··· ' . l:n . ' lines'
endfunction
