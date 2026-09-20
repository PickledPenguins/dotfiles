" 40-files.vim -- swap, backup, undo and where they go.
"
" All three live under ~/.vim/tmp/ (created here) so a working tree never
" gets .swp or ~ files.  Undo history persists across sessions.
"
" Knobs (set in ~/.vimrc.before):
"   g:dotfiles_backup   0 = no backup copies (swap and undo stay)   default: 1

for s:d in ['swap', 'backup', 'undo']
  if !isdirectory(expand('~/.vim/tmp/' . s:d))
    call mkdir(expand('~/.vim/tmp/' . s:d), 'p', 0700)
  endif
endfor

set directory=~/.vim/tmp/swap//         " trailing // keys the name on the full path
set backupdir=~/.vim/tmp/backup//
if get(g:, 'dotfiles_backup', 1) | set backup | else | set nobackup | endif
set writebackup                         " always a backup while writing
if has('persistent_undo')
  set undodir=~/.vim/tmp/undo//
  set undofile
  set undolevels=1000
endif

" never back up or write undo for secrets and temp files
augroup dotfiles_nobackup
  autocmd!
  autocmd BufNewFile,BufRead /tmp/*,/dev/shm/*,*.gpg,*.asc,*/.ssh/*,*/pass.*/*
        \ setlocal nobackup nowritebackup noundofile noswapfile viminfo=
augroup END

" reopen a file at the last cursor position
augroup dotfiles_lastpos
  autocmd!
  autocmd BufReadPost *
        \ if line("'\"") > 1 && line("'\"") <= line("$") && &filetype !~# 'commit'
        \ |   execute "normal! g'\""
        \ | endif
augroup END

" create missing parent directories on :w
augroup dotfiles_mkdir
  autocmd!
  autocmd BufWritePre * if !isdirectory(expand('<afile>:p:h')) | call mkdir(expand('<afile>:p:h'), 'p') | endif
augroup END

" strip trailing whitespace on write, except where it means something
augroup dotfiles_trailing
  autocmd!
  autocmd BufWritePre * if &filetype !~# 'markdown\|diff\|mail' | let s:v = winsaveview() | keeppatterns %s/\s\+$//e | call winrestview(s:v) | endif
augroup END
