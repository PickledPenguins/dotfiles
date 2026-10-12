" 45-filetypes.vim: per-filetype behavior beyond indentation
" (30-indent.vim), and file names vim does not recognize by itself.
"
" Each setting has its description in the comment above it.  A setting with
" " directly in front of it ("set cursorcolumn) is off: delete that " to turn
" it on, or add one to turn a setting off.  `dots options WORD` searches
" every file.  For one machine only, put the line in ~/.vimrc.local instead.

augroup dotfiles_filetypes
  autocmd!

  " Prose (markdown, text, rst, commit messages, mail): hard-wrap at 80
  " columns while typing, spell checking on.
  autocmd FileType markdown,text,rst,gitcommit,mail setlocal textwidth=80 spell formatoptions+=t

  " Commit messages: 72 columns (the body wraps there), a mark at 51 for
  " the subject limit, cursor on the first line.
  autocmd FileType gitcommit setlocal textwidth=72 colorcolumn=51 | normal! gg

  " Python: a mark at column 100 (a common wider limit than PEP 8's 80),
  " folds by indentation.
  autocmd FileType python setlocal colorcolumn=100 foldmethod=indent

  " make and go use real tabs (30-indent.vim); show them as ▸.
  autocmd FileType make,go setlocal listchars+=tab:▸\

  " YAML folds by indentation.
  autocmd FileType yaml setlocal foldmethod=indent

  " JSON shows its quotes instead of hiding them.
  autocmd FileType json setlocal conceallevel=0

  " q closes help and quickfix windows.
  autocmd FileType help,qf nnoremap <buffer> q :close<CR>

  " Markdown hides the markup of *emphasis* and [links](url) where the
  " cursor is not.
  "autocmd FileType markdown setlocal conceallevel=2

  " Text in plain-text files wraps on screen only, never hard at textwidth.
  "autocmd FileType text setlocal textwidth=0 wrap linebreak

  " F5 in a python file saves it and runs it with python3.
  "autocmd FileType python nnoremap <buffer> <F5> :write <Bar> !python3 %<CR>
augroup END

" Shell scripts are highlighted as bash, not POSIX sh (bash's [[ ]], arrays).
let g:is_bash = 1

" Code blocks in markdown are highlighted in their language.  Opening a
" markdown file then loads those syntax files too.
"let g:markdown_fenced_languages = ['bash=sh', 'python', 'json', 'yaml', 'vim', 'c', 'diff']

" File names vim does not know: PBS and Slurm job scripts and .env files
" as shell, Dockerfile.* as Dockerfile, .jsonl as JSON, *.gitconfig as git
" config.
augroup dotfiles_extensions
  autocmd!
  autocmd BufNewFile,BufRead *.pbs,*.slurm,*.sbatch  setfiletype sh
  autocmd BufNewFile,BufRead .env,.env.*,*.envrc      setfiletype sh
  autocmd BufNewFile,BufRead Dockerfile.*             setfiletype dockerfile
  autocmd BufNewFile,BufRead *.jsonl                  setfiletype json
  autocmd BufNewFile,BufRead *.gitconfig,gitconfig    setfiletype gitconfig
augroup END

" :Make runs make without the "press Enter" pause and opens the quickfix
" window when there are errors.
command! -nargs=* Make silent make <args> | redraw! | cwindow
