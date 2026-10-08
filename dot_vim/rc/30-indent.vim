" 30-indent.vim -- indentation: spaces or tabs, and how wide, by filetype.
" vim 9.0.1799+ ships editorconfig as an optional package that these files
" do not load, so a project's .editorconfig is not read.
"
" Each setting has its description in the comment above it.  A setting with
" " directly in front of it ("set cursorcolumn) is off: delete that " to turn
" it on, or add one to turn a setting off.  `dots options WORD` searches
" every file.  For one machine only, put the line in ~/.vimrc.local instead.
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

" A new line keeps the previous line's indent, and adds a level after {
" or a keyword in languages without an indent plugin.
set autoindent
set smartindent

" A new line copies the previous line's exact mix of tabs and spaces.
"set copyindent preserveindent

" Widths per filetype: 4 for python, rust, java, C, C++ and shell; real
" tabs 8 wide for make and go; 2 for yaml, json and the web languages.
augroup dotfiles_indent
  autocmd!
  autocmd FileType python,rust,java,c,cpp,sh,bash   setlocal shiftwidth=4 tabstop=4
  autocmd FileType make,go                          setlocal noexpandtab shiftwidth=8 tabstop=8
  autocmd FileType yaml,json,html,css,javascript    setlocal shiftwidth=2 tabstop=2
augroup END

" Shifting a visual selection with < or > keeps it selected, for shifting again.
xnoremap < <gv
xnoremap > >gv
