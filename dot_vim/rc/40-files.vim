" 40-files.vim: swap, backup and undo files, and what happens on read
" and write. All three kinds live under ~/.vim/tmp/, so a working tree never
" collects .swp or ~ files.
"
" Each setting has its description in the comment above it. A setting with
" " directly in front of it ("set cursorcolumn) is off: delete that " to turn
" it on, or add one to turn a setting off. `dots options WORD` searches
" every file. For one machine only, put the line in ~/.vimrc.local instead.

" ── Swap, backup, undo ──────────────────────────────────────────────────

" Make ~/.vim/tmp/{swap,backup,undo} (mode 700) when missing.
for s:d in ['swap', 'backup', 'undo']
  if !isdirectory(expand('~/.vim/tmp/' . s:d))
    call mkdir(expand('~/.vim/tmp/' . s:d), 'p', 0700)
  endif
endfor

" Swap files (crash recovery, the "file is open elsewhere" warning) under
" ~/.vim/tmp/swap; the trailing // names them after the full path.
set directory=~/.vim/tmp/swap//

" No swap files at all: no warning when a file is open twice, and no
" recovery after a crash.
"set noswapfile

" A copy of the previous version of each file you save, in ~/.vim/tmp/backup.
set backupdir=~/.vim/tmp/backup//
set backup

" A copy while writing only, deleted once the write succeeded.
set writebackup

" Undo history kept across sessions, 1000 steps per file.
if has('persistent_undo')
  set undodir=~/.vim/tmp/undo//
  set undofile
  set undolevels=1000
endif

" No backup copy, not even while writing, for secrets and temporary files:
" /dev/shm, gpg files, ~/.ssh, pass stores (vim already skips /tmp).
" Every other file keeps both.
set backupskip+=/dev/shm/*,*.gpg,*.asc,*/.ssh/*,*/pass.*/*

" No marks saved in viminfo for files under /tmp and /dev/shm; history and
" registers are still saved.
set viminfo+=r/tmp,r/dev/shm

" No undo or swap files for secrets and temporary files: /tmp, /dev/shm, gpg
" files, ~/.ssh, pass stores. Opening a secret also switches viminfo off for
" the rest of the session, on purpose: no register or history line that may
" hold a secret is saved.
augroup dotfiles_nobackup
  autocmd!
  autocmd BufNewFile,BufRead /tmp/*,/dev/shm/*,*.gpg,*.asc,*/.ssh/*,*/pass.*/*
        \ setlocal noundofile noswapfile
  autocmd BufNewFile,BufRead *.gpg,*.asc,*/.ssh/*,*/pass.*/* set viminfo=
augroup END

" ── Reading ─────────────────────────────────────────────────────────────

" Reopen a file at the line where you left it (not for commit messages).
augroup dotfiles_lastpos
  autocmd!
  autocmd BufReadPost *
        \ if line("'\"") > 1 && line("'\"") <= line("$") && &filetype !~# 'commit'
        \ |   execute "normal! g'\""
        \ | endif
augroup END

" ── Writing ─────────────────────────────────────────────────────────────

" :w makes missing parent directories.
augroup dotfiles_mkdir
  autocmd!
  autocmd BufWritePre * if !isdirectory(expand('<afile>:p:h')) | call mkdir(expand('<afile>:p:h'), 'p') | endif
augroup END

" Strip trailing whitespace on every write, except in markdown, diffs and
" mail where it means something, and in a file edited with vim -b. In a
" file that already had some, the diff then shows those lines changed too.
augroup dotfiles_trailing
  autocmd!
  autocmd BufWritePre * if !&binary && &filetype !~# 'markdown\|diff\|mail' | let s:v = winsaveview() | keeppatterns %s/\s\+$//e | call winrestview(s:v) | endif
augroup END

" Save every changed buffer when vim loses focus (switching to another
" window or tmux pane).
"augroup dotfiles_autosave
  "autocmd!
  "autocmd FocusLost * silent! wall
"augroup END
