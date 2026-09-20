" 15-statusline.vim -- a status line with no plugin.
"
"   [2] ~/src/app.py [+]  python | utf-8[unix]        git:main   12/340 : 8  4%
"
" Knobs (set in ~/.vimrc.before):
"   g:dotfiles_statusline_git  1 = show the git branch (one `git` per buffer switch)  default: 1

function! DotfilesGitBranch() abort
  if !get(g:, 'dotfiles_statusline_git', 1) || !executable('git') | return '' | endif
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

set statusline=
set statusline+=\ [%n]                       " buffer number
set statusline+=\ %<%f                       " path, truncated from the left when too long
set statusline+=\ %m%r%h%w                   " [+] modified, [RO], [help], [Preview]
set statusline+=\ \ %{&filetype}             " python
set statusline+=\ \|\ %{&fileencoding?&fileencoding:&encoding}[%{&fileformat}]
set statusline+=%=                           " right side from here
set statusline+=%{DotfilesGitBranch()}
set statusline+=%l/%L\ :\ %c                 " line/total : column
set statusline+=\ \ %P\                      " percent through the file
