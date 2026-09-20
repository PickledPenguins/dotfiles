# Configuration

Every knob, hook file and module.  Back to the [README](../README.md).

## Precedence

For bash, from weakest to strongest:

1. the module's default (`${DOTFILES_X:-default}`)
2. **`~/.bashrc.before`** -- sets `DOTFILES_*` knobs; sourced before any module
3. the module itself (committed; edit it to change the default everywhere)
4. **`~/.bashrc.local`** -- sourced last; overrides anything a module set

Turning a module off entirely is separate from knobs: rename it
`NN-name.sh.off` (committed, every machine) or list its name in
**`~/.config/bash/disabled`** (this machine).  Vim follows the same shape
with `~/.vimrc.before` (`let g:dotfiles_x = ...`), the modules,
`~/.vimrc.local`.  tmux, git and ssh have no variables: their `.local`
files are read last (tmux, git) or first (ssh, where the first value wins).

## Hook files

None is committed or managed by `dots`; each is read only if it exists.

| File | Read by | When | For |
|------|---------|------|-----|
| `~/.bashrc.before` | `~/.bashrc` | before the modules | `DOTFILES_*` knobs |
| `~/.bashrc.local` | `rc.d/90-local.sh` | after the modules | aliases, `path_prepend`, secrets |
| `~/.config/bash/disabled` | `~/.bashrc` | before each module | module names to skip, one per line, `#` comments |
| `~/.config/bash/profile.d/*.sh` | `~/.bash_profile` | login shells only | ssh-agent, one-time exports |
| `~/.config/bash/completion.d/*.bash` | `rc.d/50-completion.sh` | after bash-completion | `foo completion bash` output |
| `~/.vimrc.before` | `~/.vimrc` | before the modules | `g:dotfiles_*` knobs |
| `~/.vimrc.local` | `~/.vimrc` | after the modules | overrides |
| `~/.tmux.conf.local` | `~/.tmux.conf` | after conf.d | overrides |
| `~/.gitconfig.local` | `~/.gitconfig` | last include | identity, signing key, `includeIf` |
| `~/.ssh/config.local` | `~/.ssh/config` | first include | `Host` blocks |
| `~/.ssh/config.d/*` | `~/.ssh/config` | second include | more `Host` blocks |

Identity, hostnames and secrets go in these files, never in the repository.

## Bash knobs (`~/.bashrc.before`)

| Knob | Module | Default | Effect |
|------|--------|---------|--------|
| `DOTFILES_EDITOR` | env | `vim` if installed, else `vi` | `$EDITOR`, `$VISUAL`, `$SUDO_EDITOR` |
| `DOTFILES_MAN_COLORS` | env | `1` | `0`: plain man pages |
| `DOTFILES_HISTSIZE` | options | `50000` | lines of history in memory |
| `DOTFILES_HISTFILESIZE` | options | `100000` | lines on disk |
| `DOTFILES_HISTIGNORE` | options | none | extra `:`-separated patterns not recorded |
| `DOTFILES_SHARED_HISTORY` | options | `1` | `0`: do not `history -a` after every command |
| `DOTFILES_AUTOCD` | options | `1` | `0`: a bare directory name is not a `cd` |
| `DOTFILES_NOCLOBBER` | options | `0` | `1`: `>` refuses to overwrite (`>\|` forces) |
| `DOTFILES_PIPEFAIL` | options | `0` | `1`: a pipeline fails when any stage fails |
| `DOTFILES_DOTGLOB` | options | `0` | `1`: `*` matches dotfiles |
| `DOTFILES_NOCASEGLOB` | options | `0` | `1`: case-insensitive globbing |
| `DOTFILES_PATH_PREPEND` | path | none | `:`-separated directories put first on PATH |
| `DOTFILES_PATH_APPEND` | path | none | `:`-separated directories put last |
| `DOTFILES_SSH_AGENT_ENV` | ssh-agent (off) | `~/.ssh/agent.env` | where the agent's environment is kept |
| `DOTFILES_SSH_AGENT_KEYS` | ssh-agent (off) | none | keys to `ssh-add` when the agent starts |
| `DOTFILES_SAFE_RM` | aliases | `1` | `0`: no `rm -I`, `cp -i`, `mv -i` aliases |
| `DOTFILES_MARKS_DIR` | dirs | `~/.local/share/marks` | where `mark` keeps bookmarks |
| `DOTFILES_CDPATH` | dirs | none | extra `CDPATH` entries after `$HOME` |
| `DOTFILES_PROMPT_LAYOUT` | prompt | `box` | `box`, `hpc` or `minimal` (see `prompt/layout.sh`) |
| `DOTFILES_PROMPT_GIT` | prompt-simple (off) | `1` | `0`: no branch in the simple prompt |
| `DOTFILES_PROMPT_COLOR` | prompt-simple (off) | auto | `0`/`1`: force color off/on |
| `DOTFILES_TITLE_FORMAT` | title | `%u@%h: %d` | terminal title; `%u` user, `%h` host, `%d` directory |
| `DOTFILES_TITLE_COMMANDS` | title | `0` | `1`: title shows the running command (installs a DEBUG trap) |
| `DOTFILES_CONDA_ROOT` | conda | first found of `~/miniconda3 ~/anaconda3 ~/miniforge3 ~/mambaforge /opt/anaconda3 /opt/miniconda3 /opt/miniforge3 /opt/conda` | conda install to source |
| `DOTFILES_CONDA_ENV` | conda | none | environment to activate at start |
| `DOTFILES_VENV_DIR` | python | `.venv` | directory `venv` creates and activates |
| `DOTFILES_VENV_AUTO` | python | `0` | `1`: activate/deactivate `.venv` when changing directory |
| `DOTFILES_BAT_AS_CAT` | tools | `1` | `0`: leave `cat` alone when bat is installed |
| `DOTFILES_FZF_OPTS` | tools | `--height 40% --layout=reverse --border` | `FZF_DEFAULT_OPTS` |
| `DOTFILES_HPC_WATCH` | hpc | `10` | seconds between refreshes for `qw`/`sw` |

Read-only variables the loader sets for modules and for you:

| Variable | Value |
|----------|-------|
| `DOTFILES_DIR` | the source tree (exported) |
| `DOTFILES_BASH_DIR` | `~/.config/bash` |
| `DOTFILES_DEBUG` | set to `1` in the environment to print each module and its load time to stderr |

## Vim knobs (`~/.vimrc.before`)

| Knob | Module | Default | Effect |
|------|--------|---------|--------|
| `g:dotfiles_mouse` | 00-general | `'a'` | `mouse` value; `''` for none |
| `g:dotfiles_clipboard` | 00-general | `1` | `0`: yank/paste do not touch the system clipboard |
| `g:dotfiles_colorscheme` | 10-ui | `'desert'` | color scheme |
| `g:dotfiles_relativenumber` | 10-ui | `0` | `1`: relative line numbers |
| `g:dotfiles_colorcolumn` | 10-ui | `0` | column to mark, e.g. `80` |
| `g:dotfiles_truecolor` | 10-ui | `1` | `0`: never `termguicolors` |
| `g:dotfiles_statusline_git` | 15-statusline | `1` | `0`: no branch in the status line |
| `g:dotfiles_indent` | 30-indent | `2` | default `shiftwidth`/`tabstop` |
| `g:dotfiles_tabs` | 30-indent | `0` | `1`: real tabs by default |
| `g:dotfiles_foldmethod` | 35-folding | `'indent'` | `indent`, `syntax`, `marker`, `manual` |
| `g:dotfiles_backup` | 40-files | `1` | `0`: no backup copies (swap and undo stay) |
| `g:dotfiles_leader` | 50-keys | `' '` | leader key |
| `g:dotfiles_netrw_hidden` | 55-netrw | `1` | `0`: hide dotfiles in the browser |
| `g:dotfiles_plugins` | 60-plugins (off) | `[]` | extra `'owner/repo'` for vim-plug |

`g:dotfiles_modules` is set by the loader (the list `:DotfilesModules` prints).

## Bash modules (`~/.config/bash/rc.d/`)

| Module | Provides |
|--------|----------|
| `00-env.sh` | `EDITOR`, `PAGER`, `LESS`, XDG variables, `RIPGREP_CONFIG_PATH`, `PYTHONSTARTUP`, locale fallback, colored man pages, `TIME_STYLE`, `PYTHONDONTWRITEBYTECODE` |
| `10-options.sh` | `shopt`s (histappend, globstar, extglob, cdspell, autocd, ...), history size and sharing, `stty -ixon`, `umask 022`, the opinionated knobs |
| `20-path.sh` | `path_prepend`/`path_append`/`path_remove`; `~/.local/bin`, `~/bin`, the dotfiles dir, cargo/go/npm bins; `MANPATH` |
| `25-ssh-agent.sh.off` | one shared ssh-agent per machine, environment in `~/.ssh/agent.env` |
| `30-aliases.sh` | ls/grep/diff color, `ll la l lt ltr lS lsd`, `.. ... ....`, `-`, `d`, safety aliases, `df du dus free psg top ports j`, `c clc h hg e v sb vb path now week wget ping ip tree serve`, `g gs gl gd gp`, `alert` |
| `40-functions.sh` | `mkcd tmpd up extract targz ff fd_ bak swap calc retry timer count title tree sha man reload` |
| `45-dirs.sh` | `mark jump unmark marks` bookmarks, `CDPATH`, `1`..`9` for the pushd stack |
| `50-completion.sh` | bash-completion, `completion.d/`, git completion for the `g` alias |
| `60-prompt.sh` | the toolkit prompt: `prompt/prompt.sh` + `prompt/layout.sh` |
| `61-prompt-simple.sh.off` | one-line colored prompt with git branch |
| `65-title.sh` | terminal title at each prompt (and optionally the running command) |
| `70-conda.sh` | finds conda and sources its `conda.sh`; optional env activation |
| `75-python.sh` | `py pyv pipup pyclean json`, `venv`, optional `.venv` auto-activation |
| `80-tools.sh` | lesspipe, fzf, direnv, zoxide, bat, eza, nvm (lazy), pyenv, cargo env, gh completion -- each only if installed |
| `85-hpc.sh` | PBS (`qs qsa qw qi qd qn qtail`), Slurm (`sq sqa sw si sc sn sacct-today srun-i`), modules (`ml mla mll mlp`) -- each only if the scheduler is present |
| `90-local.sh` | sources `~/.bashrc.local` |

## Vim modules (`~/.vim/rc/`)

| Module | Provides |
|--------|----------|
| `00-general.vim` | encoding, `hidden`, `autoread` on focus, `ttimeoutlen`, `nomodeline`, mouse, clipboard, `filetype plugin indent on` |
| `10-ui.vim` | numbers, `cursorline` in the active window, `scrolloff`, `listchars`, splits below/right, `wrap`+`breakindent`, true color, colorscheme, cursor shape |
| `15-statusline.vim` | status line with buffer, path, flags, filetype, encoding, git branch, position |
| `20-search.vim` | `hlsearch incsearch ignorecase smartcase gdefault`, `inccommand`, `rg` as `grepprg`, quickfix auto-open, visual `*`/`#` |
| `25-completion.vim` | `wildmenu`/`wildmode`/`wildignore`, `completeopt`, omni completion, spell language |
| `30-indent.vim` | width and tabs from the knobs; 4 for python/rust/c/java/sh, tabs for make/go, 2 for yaml/json/web |
| `35-folding.vim` | fold method from the knob, all open at start, custom fold text |
| `40-files.vim` | swap/backup/undo under `~/.vim/tmp/`, persistent undo, no backups for secrets, last position, mkdir on write, strip trailing whitespace |
| `45-filetypes.vim` | prose wrap+spell, gitcommit columns, python columns, `q` closes help, `.pbs`/`.slurm`/`.env` filetypes, `:Make` |
| `50-keys.vim` | leader maps (`w q Q v s n p d b y P ss tw tn tl co cc ev sv`), `Ctrl-hjkl`, `Tab`/`S-Tab` buffers, visual `J`/`K`, `]q [q ]l [l`, `w!!`, `F2` paste |
| `55-netrw.vim` | tree-style netrw, `-` and `<leader>e` |
| `60-plugins.vim.off` | vim-plug with commentary, surround, repeat, fugitive, gitgutter, fzf, editorconfig |

## tmux modules (`~/.config/tmux/conf.d/`)

| Module | Provides |
|--------|----------|
| `00-options.conf` | `tmux-256color` + true color, focus events, `escape-time 0`, OSC 52 clipboard, 50000 lines, mouse, base index 1, renumber, vi copy mode, titles, activity monitoring |
| `10-keys.conf` | `r` reload, `\|`/`-` splits and `c` keeping the directory, `hjkl` panes, `HJKL` resize, `x`/`X` kill, `b` break, `S` sessions, `Tab` last window, `M-arrows`, `C-s` new session, `C-l` clear, `C-p` log pane, `m` mouse toggle; `C-a` prefix lines commented |
| `20-status.conf` | status line: session, windows, prefix indicator, window count, host, clock; colors in three numbers |
| `30-copy.conf` | `v V C-v y Y Esc` in copy mode, mouse drag and clicks, piping to xclip/xsel/wl-copy/pbcopy, `P` paste from clipboard |
| `40-nested.conf` | `F12` toggles the outer tmux off for a nested one |
| `50-plugins.conf.off` | tpm with sensible, resurrect, yank |

## Git files (`~/.gitconfig` includes, `~/.config/git/`)

| File | Provides |
|------|----------|
| `core.gitconfig` | editor, pager, whitespace, `autocrlf=input`, `defaultBranch=main`, push current+autoSetupRemote+followTags, `pull.rebase`, `fetch.prune`, rebase autoStash/autoSquash/updateRefs, `zdiff3`, `commit.verbose`, rerere, status, log, branch/tag sort, columns, autocorrect prompt, `transfer.fsckObjects`, credential cache |
| `color.gitconfig` | `color.ui=auto` and per-command colors |
| `aliases.gitconfig` | `st a aa ap unstage discard cm cma ca cae fixup undo wip co sw cob br brdel brclean default lg lga last hist who fl contains root df dfs dfw dfn dfst f pl ps psf pst up sl sp ss aliases ignored tags cp rb rbi rbc rba` |
| `diff.gitconfig` | histogram, colorMoved, renames+copies, mnemonic prefixes, vimdiff as difftool/mergetool, delta commented |
| `url.gitconfig` | `gh:`, `gh-ssh:`, `gl:` shorthands; push to GitHub over ssh |
| `signing.gitconfig` | commit and tag signing (GPG or ssh); commented out in `~/.gitconfig` |
| `ignore` | global excludes (editor, OS, environment, agent files) |
| `attributes` | `diff=` drivers by extension, binary types, LF for scripts |

## Other dotfiles

| Target | Purpose |
|--------|---------|
| `~/.profile` | POSIX login: PATH and `LANG` for non-bash shells and display managers |
| `~/.bash_profile` | `.profile`, then `profile.d/*.sh`, then `.bashrc` |
| `~/.bash_logout` | `clear_console` on a top-level logout |
| `~/.inputrc` | readline: case-insensitive completion, single-Tab listing, colored stats, history search on Up/Down, Ctrl-arrows by word |
| `~/.editorconfig` | 2-space default, 4 for python/rust/c/java/sh, tabs for make/go |
| `~/.curlrc` | follow redirects, timeouts, retries, progress bar |
| `~/.wgetrc` | timeouts, retries, resume, timestamping |
| `~/.screenrc` | no splash, 10000 lines, status line, tmux-like keys |
| `~/.dircolors` | `dircolors -p` with `OTHER_WRITABLE` readable on dark terminals |
| `~/.gdbinit` | history, no pagination, pretty printing, intel syntax |
| `~/.nanorc` | autoindent, 4-space tabs, line numbers, soft wrap, syntax files |
| `~/.condarc` | `auto_activate_base: false`, `changeps1: false`, conda-forge first |
| `~/.Xresources` | xterm font, colors, scrollback, clipboard keys; urxvt basics |
| `~/.ssh/config` (600, `~/.ssh` 700) | includes, keepalive, multiplexing (`~/.ssh/sockets/`), `AddKeysToAgent`, no agent/X11 forwarding by default |
| `~/.config/ripgrep/config` | smart case, hidden files, ignores, colors |
| `~/.config/python/pythonrc.py` | REPL history and completion before 3.13; `json math re Path pp` imported |
| `~/.config/pip/pip.conf` | timeout; `require-virtualenv` and mirror commented |
| `~/.ctags.d/default.ctags` | universal-ctags excludes and fields |

## `.dotsignore`

In the source root.  One glob per line, `#` comments, matched with
`fnmatch` against the target-relative path and every leading directory of
it: `README.md` matches only at the top; `tests` skips everything under
`tests/`; `*.local` matches at any depth because `*` crosses `/`.  The
shipped file lists `README.md CLAUDE.md LICENSE dots run-tests.sh tests
docs reviews __pycache__`.
