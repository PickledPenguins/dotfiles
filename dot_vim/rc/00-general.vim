" 00-general.vim -- core behavior every other module assumes: encoding,
" buffers, timing, mouse, clipboard.
"
" Each setting has its description in the comment above it.  A setting with
" " directly in front of it ("set cursorcolumn) is off: delete that " to turn
" it on, or add one to turn a setting off.  `dots options WORD` searches
" every file.  For one machine only, put the line in ~/.vimrc.local instead.

" ── Files and encodings ─────────────────────────────────────────────────

" UTF-8 inside vim and for new files; existing files are read as unix,
" then dos, then old mac line endings.
set encoding=utf-8
scriptencoding utf-8
set fileencoding=utf-8
set fileformats=unix,dos,mac

" Leave a modified buffer for another without saving it first.
set hidden

" Backspace deletes indentation, line breaks and text from before the
" insert started.
set backspace=indent,eol,start

" Reload a file changed outside vim, as soon as vim gets focus back or the
" cursor rests (only while the buffer has no unsaved changes).
set autoread
augroup dotfiles_autoread
  autocmd!
  autocmd FocusGained,BufEnter,CursorHold * silent! checktime
augroup END

" Save the file automatically on :make, :next, :!cmd and friends.
"set autowrite

" :q on a modified buffer asks whether to save instead of failing.
"set confirm

" Ignore modelines (vim: settings inside files), a known way for a file to
" run code.  Files with a modeline lose it.
set nomodeline

" Read a .vimrc or .exrc in the directory vim starts in, with `secure`
" limiting what it may do.  Only for trees you trust.
"set exrc secure

" Keep ~/.viminfo (marks, registers, history) under ~/.vim/tmp instead of $HOME.
"set viminfofile=~/.vim/tmp/viminfo

" ── Timing ──────────────────────────────────────────────────────────────

" Command-line history entries kept.
set history=1000

" No pause after Esc in a terminal: key codes must arrive within 10 ms.
set ttimeout ttimeoutlen=10

" How long vim waits for the rest of a mapping such as <leader>w (default
" 1000 ms).  Shorter feels faster; too short makes two-key maps hard.
"set timeoutlen=500

" CursorHold events and swap file writes after 300 ms idle (default 4 s).
set updatetime=300

" ── Editing ─────────────────────────────────────────────────────────────

" Ctrl-A on 007 gives 008, not octal 010.
set nrformats-=octal

" Joining lines removes a comment leader from the joined line.
set formatoptions+=j

" One space after a period when joining lines, not two.
set nojoinspaces

" Visual block mode can extend past the end of short lines.
set virtualedit=block

" Keep the cursor's column when paging and jumping.
set nostartofline

" ── Mouse and clipboard ─────────────────────────────────────────────────

" The mouse clicks, scrolls, selects and resizes in every mode.  Shift+drag
" still selects terminal text.  For one machine without: set mouse= in
" ~/.vimrc.local.
set mouse=a

" Mouse clicks beyond column 223 in wide terminals that vim does not
" recognize (xterm protocol).
"set ttymouse=sgr

" Yank and put use the system clipboard (both X11 selections) when vim has
" clipboard support; "+y and "+p are not needed.
if has('clipboard') | set clipboard^=unnamedplus,unnamed | endif

" ── Filetypes ───────────────────────────────────────────────────────────

" Filetype detection, per-filetype settings and indentation.
filetype plugin indent on
