" 30-indent.vim: indentation: spaces or tabs, and how wide, by filetype.
" vim reads .editorconfig only when the editorconfig setting below is on
" (or the plugin in 60-plugins.vim.off).
"
" Each setting has its description in the comment above it. A setting with
" " directly in front of it ("set cursorcolumn) is off: delete that " to turn
" it on, or add one to turn a setting off. `dots options WORD` searches
" every file. For one machine only, put the line in ~/.vimrc.local instead.
"
" Knobs (set in ~/.vimrc.before):
"   g:dotfiles_indent   default width   default: 2

" The default indent width, from the knob; soft tabs follow it.
let s:w = get(g:, 'dotfiles_indent', 2)
let &tabstop = s:w
let &shiftwidth = s:w
set softtabstop=-1

" Indent with spaces.
set expandtab

" Indent with real tabs by default instead (filetypes below still choose).
"set noexpandtab

" Tab at the start of a line inserts one indent level; >> and << snap to
" whole levels.
set smarttab
set shiftround

" A new line keeps the previous line's indent.
set autoindent

" In filetypes without an indent plugin (conf, tmux, text, markdown, ini),
" a new line also gets a level after a line ending in { or starting with a
" 'cinwords' keyword (if, for, while, do, else, switch, case), and } takes
" one away. Off because it costs more than it gives there: a line starting
" with # goes to column 0, so comments lose their indent, and in prose a
" line starting with "for" or "if" pushes the next one in. Filetypes with
" an indent plugin ignore it.
"set smartindent

" A new line copies the previous line's exact mix of tabs and spaces.
"set copyindent preserveindent

" Widths per filetype: 4 for rust, java, C, C++ and shell; real tabs 8 wide
" for make and go; 2 for python, yaml, json and the web languages (python's
" own ftplugin sets 4, and softtabstop 4, which these replace).
augroup dotfiles_indent
  autocmd!
  autocmd FileType rust,java,c,cpp,sh,bash                setlocal shiftwidth=4 tabstop=4
  autocmd FileType make,go                                setlocal noexpandtab shiftwidth=8 tabstop=8
  autocmd FileType python,yaml,json,html,css,javascript   setlocal shiftwidth=2 tabstop=2 softtabstop=-1
augroup END

" Shifting a visual selection with < or > keeps it selected, for shifting again.
xnoremap < <gv
xnoremap > >gv

" ── EditorConfig ────────────────────────────────────────────────────────

" Read .editorconfig files (vim 9.0.1799+ ships the plugin as an optional
" package): a project's own file sets indentation, final newline and
" trailing-whitespace stripping for its files, and beats the filetype widths
" above. Off because it changes how vim saves every file under $HOME, which
" ~/.editorconfig covers with [*]: the g:dotfiles_indent knob no longer
" applies there (change indent_size in ~/.editorconfig too), and a project
" file with wrong rules wins as well. The two settings below keep it from
" re-encoding files or changing their line endings. Not together with the
" editorconfig plugin in 60-plugins.vim.off, which is the same plugin.
"if has('patch-9.0.1799') | packadd! editorconfig | endif

" EditorConfig, once loaded (above or by 60-plugins.vim.off), ignores
" charset and end_of_line: with them, ~/.editorconfig's utf-8 and lf would
" rewrite every latin-1 or CRLF file under $HOME on its next save (a
" whole-file diff) and mark it modified as soon as it opens. vim keeps the
" encoding and line ending it detected instead; a project's crlf or latin1
" is not applied to new files. Other editors still read both. Does nothing
" until EditorConfig is loaded.
let g:EditorConfig_disable_rules = ['charset', 'end_of_line']

" A project's trim_trailing_whitespace = false also stops this setup's own
" strip-on-write (40-files.vim), which otherwise strips every file but
" markdown, diffs and mail. Does nothing until EditorConfig is loaded.
function! s:EditorConfigTrailing(config) abort
  let b:dotfiles_keep_trailing = get(a:config, 'trim_trailing_whitespace', '') ==# 'false'
  return 0
endfunction
augroup dotfiles_editorconfig
  autocmd!
  autocmd SourcePost */plugin/editorconfig.vim
        \ call editorconfig#AddNewHook(function('s:EditorConfigTrailing'))
augroup END
