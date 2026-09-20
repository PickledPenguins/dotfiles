" Swap, backup and undo files -- out of the working tree, under ~/.vim/tmp.

for s:d in ['swap', 'backup', 'undo']
  if !isdirectory(expand('~/.vim/tmp/' . s:d))
    call mkdir(expand('~/.vim/tmp/' . s:d), 'p', 0700)
  endif
endfor

set directory=~/.vim/tmp/swap//         " trailing // keys the name on the full path
set backupdir=~/.vim/tmp/backup//
set backup
if has('persistent_undo')
  set undodir=~/.vim/tmp/undo//
  set undofile
endif

" Jump back to the last cursor position when reopening a file
augroup dotfiles_lastpos
  autocmd!
  autocmd BufReadPost * if line("'\"") > 1 && line("'\"") <= line("$") | execute "normal! g'\"" | endif
augroup END
