" 45-filetypes.vim -- per-filetype behavior beyond indentation (30-indent).

augroup dotfiles_filetypes
  autocmd!
  " prose: wrap at 80, spell check, no line numbers in the way
  autocmd FileType markdown,text,rst,gitcommit,mail
        \ setlocal textwidth=80 spell formatoptions+=t
  " commit messages: start at the top, 72 columns, subject line marked
  autocmd FileType gitcommit setlocal textwidth=72 colorcolumn=51,73 | normal! gg
  " python: pep8 width marker, folds by indent
  autocmd FileType python setlocal colorcolumn=80,100 foldmethod=indent
  " makefiles and go: real tabs (30-indent), and show them clearly
  autocmd FileType make,go setlocal listchars+=tab:▸\ 
  " shell: 2-space is common, but let shellcheck know it is bash
  autocmd FileType sh let b:is_bash = 1
  " yaml: indent-aware folding
  autocmd FileType yaml setlocal foldmethod=indent
  " json: no concealment of quotes
  autocmd FileType json setlocal conceallevel=0
  " help: q closes
  autocmd FileType help,qf nnoremap <buffer> q :close<CR>
augroup END

" extra extensions
augroup dotfiles_extensions
  autocmd!
  autocmd BufNewFile,BufRead *.pbs,*.slurm,*.sbatch  setfiletype sh
  autocmd BufNewFile,BufRead .env,.env.*,*.envrc      setfiletype sh
  autocmd BufNewFile,BufRead Dockerfile.*             setfiletype dockerfile
  autocmd BufNewFile,BufRead *.jsonl                  setfiletype json
  autocmd BufNewFile,BufRead *.gitconfig,gitconfig    setfiletype gitconfig
augroup END

" :Make runs make quietly and opens the quickfix window on errors
command! -nargs=* Make silent make <args> | redraw! | cwindow
