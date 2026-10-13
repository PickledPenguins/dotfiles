" 52-tags.vim: tags files (ctags): where vim looks, and the <leader>t maps.
"
"   Ctrl-]          jump to the definition under the cursor; Ctrl-T back
"   g] / g Ctrl-]   list every definition / jump if only one, else list
"   Ctrl-W ]        open the definition in a split
"   Ctrl-X Ctrl-]   in insert mode, complete from the tags
"   <leader>tg      build the tags (git ctags in a repository, else ctags)
"   <leader>tf      jump to a tag by name; Tab completes
"   <leader>th / tv / tt / tp
"                   the definition under the cursor in a split, a vertical
"                   split, a new tab, the preview window
"
" Each setting has its description in the comment above it. A setting with
" " directly in front of it ("set cursorcolumn) is off: delete that " to turn
" it on, or add one to turn a setting off. `dots options WORD` searches
" every file. For one machine only, put the line in ~/.vimrc.local instead.

" Vim looks for a tags file beside the current file, then in each directory
" above it, then in vim's own directory and above: a file deep in a project
" finds the project's tags at its root.
set tags=./tags;,tags;

" <leader>tg builds the tags: `git ctags` (~/.local/bin) when the current
" file is in a git repository, which also keeps them current through the
" repository's ctags hook; plain ctags in vim's directory otherwise. Needs:
" universal-ctags.
function! s:BuildTags() abort
  let l:dir = expand('%:p:h')
  if l:dir ==# ''
    let l:dir = getcwd()
  endif
  call system('git -C ' . shellescape(l:dir) . ' rev-parse --show-toplevel')
  if v:shell_error
    let l:out = systemlist('ctags')
  else
    let l:out = systemlist('git -C ' . shellescape(l:dir) . ' ctags')
  endif
  if v:shell_error
    echoerr join(l:out)
    return
  endif
  echo empty(l:out) ? 'tags built in ' . getcwd() : join(l:out, "\n")
endfunction
nnoremap <silent> <leader>tg :call <SID>BuildTags()<CR>

" <leader>tf jumps to a tag by name, listing them when there are several.
nnoremap <leader>tf :tjump<Space>

" <leader>th, <leader>tv and <leader>tt open the definition under the
" cursor in a split, a vertical split and a new tab; <leader>tp shows it in
" the preview window (Ctrl-W z closes it). Several definitions: a list.
nnoremap <leader>th :stjump <C-r><C-w><CR>
nnoremap <leader>tv :vertical stjump <C-r><C-w><CR>
nnoremap <leader>tt :tab stjump <C-r><C-w><CR>
nnoremap <leader>tp :ptjump <C-r><C-w><CR>

" Ctrl-] lists the definitions when a name has several, instead of taking
" the first (it is then g Ctrl-]).
"nnoremap <C-]> g<C-]>
