" 40-files.vim: swap, backup and undo files, and what happens on read
" and write. All three kinds live under ~/.vim/tmp/, so a working tree never
" collects .swp or ~ files. In bash's fast mode (DOTS_FAST_ACTIVE=1 from
" the shell that started vim) swap files go to tmpfs instead, unsynced.
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

" In bash's fast mode, swap files in tmpfs ($XDG_RUNTIME_DIR/vim-swap,
" else /dev/shm/vim-swap-USER, made mode 700) and never synced to disk:
" typing does not wait on a slow home disk. Recovery still works after vim
" or the terminal dies, not after the machine goes down; the "file is open
" elsewhere" warning only sees other vims started in fast mode. Swap files
" there older than 14 days go, looked for once a day (a stamp file), so a
" server that is never rebooted does not keep them.
function! s:FastSwapDir() abort
  let l:dirs = empty($XDG_RUNTIME_DIR) ? [] : [$XDG_RUNTIME_DIR . '/vim-swap']
  for l:d in l:dirs + ['/dev/shm/vim-swap-' . $USER]
    if isdirectory(fnamemodify(l:d, ':h'))
      if !isdirectory(l:d)
        silent! call mkdir(l:d, '', 0700)
      endif
      if isdirectory(l:d) && filewritable(l:d) == 2 && getfperm(l:d) ==# 'rwx------'
        return l:d
      endif
    endif
  endfor
  return ''
endfunction
function! s:FastSwapPrune(dir) abort
  let l:stamp = a:dir . '/.pruned'
  if getftime(l:stamp) > localtime() - 86400
    return
  endif
  for l:f in glob(a:dir . '/*', 1, 1)
    if getftime(l:f) < localtime() - 14 * 86400
      call delete(l:f)
    endif
  endfor
  call writefile([], l:stamp)
endfunction
if $DOTS_FAST_ACTIVE ==# '1'
  let s:fast_swap = s:FastSwapDir()
  if !empty(s:fast_swap)
    let &directory = s:fast_swap . '//'
    set swapsync=
    call s:FastSwapPrune(s:fast_swap)
  endif
endif

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
" mail where it means something, in a file edited with vim -b, and in a
" project whose .editorconfig says trim_trailing_whitespace = false (when
" EditorConfig is loaded, 30-indent.vim). In a file that already had some,
" the diff then shows those lines changed too.
augroup dotfiles_trailing
  autocmd!
  autocmd BufWritePre * if !&binary && &filetype !~# 'markdown\|diff\|mail' && !get(b:, 'dotfiles_keep_trailing') | let s:v = winsaveview() | keeppatterns %s/\s\+$//e | call winrestview(s:v) | endif
augroup END

" Save every changed buffer when vim loses focus (switching to another
" window or tmux pane).
"augroup dotfiles_autosave
  "autocmd!
  "autocmd FocusLost * silent! wall
"augroup END
