" 15-statusline.vim -- a status line without a plugin:
"
"   [2] ~/src/app.py [+]  python | utf-8[unix]        git:main   12/340 : 8  4%
"
" Each setting has its description in the comment above it.  A setting with
" " directly in front of it ("set cursorcolumn) is off: delete that " to turn
" it on, or add one to turn a setting off.  `dots options WORD` searches
" every file.  For one machine only, put the line in ~/.vimrc.local instead.

" The git branch of the buffer's file, cached per buffer and read again
" on entering it, writing it or regaining focus (one git per refresh).
function! DotfilesGitBranch() abort
  if !executable('git') | return '' | endif
  if !exists('b:dotfiles_branch')
    let l:dir = expand('%:p:h')
    let l:out = isdirectory(l:dir) ? system('git -C ' . shellescape(l:dir) . ' symbolic-ref --short HEAD 2>/dev/null') : ''
    let b:dotfiles_branch = v:shell_error ? '' : substitute(l:out, '\n', '', 'g')
  endif
  return empty(b:dotfiles_branch) ? '' : 'git:' . b:dotfiles_branch . '  '
endfunction
augroup dotfiles_statusline
  autocmd!
  autocmd BufEnter,BufWritePost,FocusGained * unlet! b:dotfiles_branch
augroup END

" Left: buffer number, path (cut from the left when long), flags [+]
" modified [RO] [help] [Preview], filetype, encoding and line endings.
set statusline=
set statusline+=\ [%n]
set statusline+=\ %<%f
set statusline+=\ %m%r%h%w
set statusline+=\ \ %{&filetype}
set statusline+=\ \|\ %{&fileencoding?&fileencoding:&encoding}[%{&fileformat}]

" Spelling language, when spell checking is on.
"set statusline+=%{&spell?'\ \ [spell:'.&spelllang.']':''}

" Everything from here on sits at the right.
set statusline+=%=

" The git branch.
set statusline+=%{DotfilesGitBranch()}

" line/total : column, and how far through the file.
set statusline+=%l/%L\ :\ %c
set statusline+=\ \ %P\
