" 25-completion.vim: completion on the command line and in insert mode.
"
" Each setting has its description in the comment above it.  A setting with
" " directly in front of it ("set cursorcolumn) is off: delete that " to turn
" it on, or add one to turn a setting off.  `dots options WORD` searches
" every file.  For one machine only, put the line in ~/.vimrc.local instead.

" ── Command line ────────────────────────────────────────────────────────

" Tab completes the longest common part first and shows a menu; Tab again
" steps through it.  Case is ignored.
set wildmenu
set wildmode=longest:full,full
set wildignorecase

" Tab lists every match and completes the longest common part, bash style,
" instead of a menu.
"set wildmode=longest:list,full

" Files never offered: objects, bytecode, swap files, and the insides of
" git, cache, dependency and build directories.
set wildignore+=*.o,*.obj,*.pyc,*.class,*.swp,*~
set wildignore+=*/.git/*,*/__pycache__/*,*/node_modules/*,*/.venv/*,*/build/*

" :find and gf look in every directory below the current one as well
" (<leader>f in 50-keys.vim uses it); Tab skips what 'wildignore' names.
" Slow to complete in a very large tree, such as all of $HOME.
set path+=**

" The menu is a vertical popup instead of a row (vim 8.2.4325+).
if has('patch-8.2.4325') | set wildoptions+=pum | endif

" Fuzzy matching on the command line: :e cfgvm finds config.vim (vim 9.0+).
"set wildoptions+=fuzzy

" ── Insert mode ─────────────────────────────────────────────────────────

" Ctrl-N/Ctrl-P show a menu even for one match, insert the longest common
" part, and show extra information in a preview window.
set completeopt=menuone,longest,preview

" Extra information in a popup beside the menu instead of a preview window.
"set completeopt-=preview completeopt+=popup

" Nothing is inserted or selected until you choose (as IDEs behave).
"set completeopt+=noinsert,noselect

" Do not scan included files or tags while completing (slow in big trees);
" Ctrl-X Ctrl-I and Ctrl-X Ctrl-] still do that on demand.
set complete-=i
set complete-=t

" Words from the spelling dictionary too, when spell checking is on.
"set complete+=kspell

" Ctrl-X Ctrl-O completes language keywords from the syntax file when the
" filetype has no better omni completion.
set omnifunc=syntaxcomplete#Complete

" At most 12 rows in the popup menu.
set pumheight=12

" A completed word takes the case that was typed.
set infercase

" Tab completes a word when the cursor follows one, and inserts a Tab
" otherwise; Shift-Tab steps back.
"function! DotfilesTab() abort
  "return col('.') > 1 && getline('.')[col('.') - 2] =~# '\k' ? "\<C-n>" : "\<Tab>"
"endfunction
"inoremap <expr> <Tab> DotfilesTab()
"inoremap <S-Tab> <C-p>

" ── Spelling ────────────────────────────────────────────────────────────

" American English, nine suggestions ranked best first (z= shows them).
set spelllang=en_us
set spellsuggest=best,9
