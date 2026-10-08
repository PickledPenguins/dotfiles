# Configuration

Every knob, hook file, module and dotfile, and the format the files share.
Back to the [README](../README.md).

## The options format

Every configuration file (68 of them; the exceptions are listed at the end
of this section) is a catalog: about 640 settings that are on and 420 that
are off, each with its description directly above it.

```bash
# A history expansion (!!, !$, !git) is put on the command line for a look
# before it runs.  Safer; costs one more Enter.
#shopt -s histverify
```

- **The description** is the comment lines directly above a setting: its
  first sentence says what it is, the rest what it does, what it costs and
  when you would not want it.  A `Needs: PROGRAM` line names what must be
  installed first, with the oldest version that works where that matters
  (`Needs: git 2.35+`).
- **Off** is a setting whose lines each start with the comment character
  directly followed by the code: `#shopt -s histverify`, `"set
  cursorcolumn` in vim, `!Xft.dpi: 96` in `~/.Xresources`.  Delete that
  character (on every line of a multi-line setting) to turn it on.
- **On** is live code; put the comment character in front of each line to
  turn it off.
- A comment character followed by a space is description; a blank line
  ends a setting.  Indented lines keep their indentation before the
  character (`    #ff = only` in a git section).
- **What starts on:** everything the configuration already did, and
  anything that only adds a name (a function, an alias, a git alias, a key
  that had no binding).  **What starts off:** anything that would change
  what an existing command, key or program does.  The kitty, IPython,
  matplotlib and sqlite files ship with everything off, so those programs
  behave as they do without a config file.
- Every file says this in its header and mentions `dots options`, which is
  how [`dots options`](cli.md#dots-options---on----off--f-words) recognizes
  the files it reads.  `dots options WORD` lists every setting whose file,
  description or code contains WORD, with the file and line to edit.

`tests/test_options.py` holds the files to this: every setting that is off
has a description of at least 15 characters, every setting that is on has
one unless it is structure (`[section]`, `Host *`, `augroup`, `fi`), and
every setting that is off, switched on alone, still loads in its real
program without an error.

Not in the format, on purpose: `~/.dircolors` (the `dircolors -p` table of
file types), `~/.config/bash/prompt/toolkit/` (bash-prompt-toolkit, a library),
`~/.ssh/sockets/.keep` (empty).

## Precedence

For bash, from weakest to strongest:

1. the module's default (`${DOTFILES_X:-default}`)
2. **`~/.bashrc.before`** -- sets `DOTFILES_*` knobs; sourced before any module
3. the module itself (committed; switch a setting there to change it everywhere)
4. **`~/.bashrc.local`** -- sourced last; any setting line, switched on or
   undone, for this machine only

Turning a module off entirely is separate: rename it `NN-name.sh.off`
(committed, every machine) or list its name in
**`~/.config/bash/disabled`** (this machine).  Vim follows the same shape
with `~/.vimrc.before` (`let g:dotfiles_x = ...`), the modules,
`~/.vimrc.local`.  tmux, git and ssh have no variables: their `.local`
files are read last (tmux, git) or first (ssh, where the first value wins).

Knobs are for values that differ between machines (a size, a path, a
name).  On/off choices are settings in the files, switched by their comment
character, or per machine in the `.local` file.

## Hook files

None is committed or managed by `dots`; each is read only if it exists.

| File | Read by | When | For |
|------|---------|------|-----|
| `~/.bashrc.before` | `~/.bashrc` | before the modules | `DOTFILES_*` knobs |
| `~/.bashrc.local` | `rc.d/90-local.sh` | after the modules | settings for this machine, aliases, `path_prepend`, secrets |
| `~/.config/bash/disabled` | `~/.bashrc` | before each module | module names to skip, one per line, `#` comments |
| `~/.config/bash/profile.d/*.sh` | `~/.bash_profile` | login shells only (each tmux pane is one) | ssh-agent, one-time exports |
| `~/.config/bash/completion.d/*.bash` | `rc.d/50-completion.sh` | after bash-completion | `foo completion bash` output |
| `~/.vimrc.before` | `~/.vimrc` | before the modules | `g:dotfiles_*` knobs |
| `~/.vimrc.local` | `~/.vimrc` | after the modules | overrides |
| `~/.tmux.conf.local` | `~/.tmux.conf` | after conf.d | overrides |
| `~/.gitconfig.local` | `~/.gitconfig` | last include | identity, signing key, `includeIf` |
| `~/.ssh/config.local` | `~/.ssh/config` | first include | `Host` blocks |
| `~/.ssh/config.d/*` | `~/.ssh/config` | second include | more `Host` blocks |
| `~/.config/kitty/local.conf` | `~/.config/kitty/kitty.conf` | last | overrides |

Identity, hostnames and secrets go in these files, never in the repository.

## Bash knobs (`~/.bashrc.before`)

| Knob | Module | Default | Effect |
|------|--------|---------|--------|
| `DOTFILES_EDITOR` | env | `vim` if installed, else `vi` | `$EDITOR`, `$VISUAL`, `$SUDO_EDITOR` |
| `DOTFILES_HISTSIZE` | options | `50000` | lines of history in memory |
| `DOTFILES_HISTFILESIZE` | options | `100000` | lines on disk |
| `DOTFILES_HISTIGNORE` | options | none | extra `:`-separated patterns not recorded |
| `DOTFILES_PATH_PREPEND` | path | none | `:`-separated directories put first on PATH |
| `DOTFILES_PATH_APPEND` | path | none | `:`-separated directories put last |
| `DOTFILES_SSH_AGENT_ENV` | ssh-agent (off) | `~/.ssh/agent.env` | where the agent's environment is kept |
| `DOTFILES_SSH_AGENT_KEYS` | ssh-agent (off) | none | keys to `ssh-add` when the agent starts |
| `DOTFILES_MARKS_DIR` | dirs | `~/.local/share/marks` | where `mark` keeps bookmarks |
| `DOTFILES_CDPATH` | dirs | none | extra `CDPATH` entries after `$HOME` |

| `DOTFILES_PROMPT_GIT` | prompt-simple (off) | `1` | `0`: no branch in the simple prompt |
| `DOTFILES_PROMPT_COLOR` | prompt-simple (off) | auto | `0`/`1`: force color off/on |
| `DOTFILES_TITLE_FORMAT` | title | `%u@%h: %d` | terminal title; `%u` user, `%h` host, `%d` directory |
| `DOTFILES_CONDA_ROOT` | conda | first found of `~/miniconda3 ~/anaconda3 ~/miniforge3 ~/mambaforge /opt/anaconda3 /opt/miniconda3 /opt/miniforge3 /opt/conda` | conda install to source |
| `DOTFILES_CONDA_ENV` | conda | none | environment to activate at start |
| `DOTFILES_VENV_DIR` | python | `.venv` | directory `venv` creates and activates |
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
| `g:dotfiles_colorscheme` | 10-ui | `'desert'` | color scheme; the module lists the built-in ones |
| `g:dotfiles_indent` | 30-indent | `2` | default `shiftwidth`/`tabstop` |
| `g:dotfiles_foldmethod` | 35-folding | `'indent'` | `indent`, `syntax`, `marker`, `manual` |
| `g:dotfiles_leader` | 50-keys | `' '` | leader key |
| `g:dotfiles_plugins` | 60-plugins (off) | `[]` | extra `'owner/repo'` for vim-plug |

`g:dotfiles_modules` is set by the loader (the list `:DotfilesModules` prints).

## Bash modules (`~/.config/bash/rc.d/`)

"Off:" names a few of the settings each module offers switched off;
`dots options --off FILE-NAME` lists them all.

| Module | Provides |
|--------|----------|
| `00-env.sh` | `EDITOR`, `PAGER`, `LESS`, colored man pages, `GREP_COLORS`, `COLORTERM`, XDG variables, `RIPGREP_CONFIG_PATH`, `PYTHONSTARTUP`, locale fallback, `TIME_STYLE`, `PYTHONDONTWRITEBYTECODE`.  Off: less mouse/chop/centering, bat or vim as `MANPAGER`, `MANWIDTH`, `NO_COLOR`, a dozen moves of tool files out of `$HOME`, `LC_COLLATE=C`, `PYTHONPYCACHEPREFIX`, `GPG_TTY`, `BROWSER` |
| `10-options.sh` | `globstar extglob autocd cdspell dirspell checkjobs huponexit histappend cmdhist lithist checkwinsize`, history sizes and control, history written after every command, `stty -ixon`, `umask 022`.  Off: `dotglob nocaseglob nullglob failglob nocasematch cdable_vars direxpand notify noclobber pipefail IGNOREEOF histexpand TMOUT histverify histreedit`, XDG history file, live history sharing, no mail check, `umask 077/027`, `ulimit` core and stack |
| `20-path.sh` | `path_prepend`/`path_append`/`path_remove`; `~/.local/bin`, `~/bin`, cargo/go/npm bins; `MANPATH`.  Off: deno, bun, .NET, juliaup, ghcup/cabal, pixi, CUDA, Flatpak, snap |
| `25-ssh-agent.sh.off` | one shared ssh-agent per machine, environment in `~/.ssh/agent.env`.  Off inside: keychain or gpg-agent instead |
| `30-aliases.sh` | ls/grep/diff/ip color, `ll la l lt ltr lS lsd`, `.. ... .... ..... cd.. - d cdg`, `rm -I cp -i mv -i`, `mkdir -pv ln -v chmox`, `df du free dus psg top ports j mnt`, `c clc h hg e v sb vb path now week timestamp epoch ping tree serve cpv myip :q`, `pbcopy`/`pbpaste`, `g gs gl gd gp`, `alert`.  Off: grep skipping VCS dirs, `rm -i`, `--preserve-root`, `sudo ` alias expansion, `vi`→vim, `vim`→nvim, `open`, the oh-my-zsh git set |
| `40-functions.sh` | `mkcd tmpd up bd cdf extract targz ff fd_ rgv bak swap bigfiles count sha mkscript note tree retry timer histstat man reload calc genpass urlencode urldecode fromepoch title hr envg port cheat weather` |
| `45-dirs.sh` | `mark jump unmark marks` bookmarks, `CDPATH`, `1`..`9` for the pushd stack.  Off: ls after cd, cd that pushes (auto_pushd) |
| `50-completion.sh` | bash-completion, `completion.d/`, git completion for the `g` alias.  Off: no `/etc/hosts` in host completion, pip completion |
| `60-prompt.sh` | the toolkit prompt: `prompt/toolkit/prompt.sh` + `prompt/layout.sh` (every segment described and switchable there).  The toolkit's own variables are in its [README](../dot_config/bash/prompt/toolkit/README.md); `CMD_TIMER_SKIP_TRAP=1` leaves the DEBUG trap to another tool and drops `@cmd_time` |
| `61-prompt-simple.sh.off` | one-line colored prompt with git branch.  Off inside: time, short directory, `PROMPT_DIRTRIM`, exit status |
| `65-title.sh` | terminal title at each prompt.  Off: the running command in the title |
| `70-conda.sh` | finds conda and sources its `conda.sh`; optional env activation; `ca cda cel` |
| `75-python.sh` | `py pyv pipup pyclean json pt ipy jl jn`, `venv`, uv completion.  Off: `.venv` auto-activation, `PIP_REQUIRE_VIRTUALENV`, ipdb breakpoints, `PYTHON_BASIC_REPL` |
| `80-tools.sh` | each only if installed: Homebrew, Nix, mise, asdf, pyenv, nvm (lazy), fnm, rbenv, SDKMAN!, ghcup, cargo env, lesspipe, bat and `cat`→bat, `fd`, eza for `ll lt`, fzf with `fe fkill fbr`, zoxide, direnv, docker/kubectl/aws/terraform/gh/lazygit shortcuts and completion, tmux `ta tn tl tat`, yazi `y`, `lfcd`.  Off: eza as ls/tree, vivid, fzf previews, `zoxide --cmd cd`, starship, atuin, thefuck, fortune, fastfetch |
| `85-hpc.sh` | PBS (`qs qsa qw qi qd qn qh qtail`), Slurm (`sq sqa sw si sc sn sacct-today sstart srun-i`), modules (`ml mla mll mlp mls`) -- each only if present.  Off: `qint`, `sint`, `SQUEUE_FORMAT`/`SACCT_FORMAT`, `LMOD_REDIRECT`, `LMOD_PAGER`, one thread per program, `TMPDIR` on scratch |
| `90-local.sh` | sources `~/.bashrc.local` |

## Vim modules (`~/.vim/rc/`)

| Module | Provides |
|--------|----------|
| `00-general.vim` | encoding, `hidden`, `autoread` on focus, `ttimeoutlen`, `updatetime`, `nomodeline`, `mouse=a`, system clipboard, `filetype plugin indent on`.  Off: `autowrite`, `confirm`, `exrc secure`, `viminfofile`, `timeoutlen`, `ttymouse=sgr` |
| `10-ui.vim` | numbers, `cursorline` in the active window, `scrolloff`, `listchars`, splits below/right, `wrap`+`breakindent`, search count, true color, colorscheme, cursor shape.  Off: `relativenumber`, `cmdheight`, `cursorcolumn`, `colorcolumn`, `eol:¬`, `fillchars`, `nowrap`, `title`, light background |
| `15-statusline.vim` | status line with buffer, path, flags, filetype, encoding, git branch, position.  Off: spelling language |
| `20-search.vim` | `hlsearch incsearch ignorecase smartcase wrapscan gdefault`, `inccommand`, `rg` as `grepprg`, quickfix auto-open, visual `*`/`#`.  Off: `nowrapscan`, very magic search, Esc clears highlight |
| `25-completion.vim` | `wildmenu`/`wildmode`/`wildignore`, popup menu, `completeopt`, omni completion, spelling.  Off: bash-style wildmode, fuzzy, popup info, `noinsert`, `kspell`, Tab completion |
| `30-indent.vim` | width from the knob, spaces; 4 for rust/c/java/sh, tabs for make/go, 2 for python/yaml/json/web; `<`/`>` keep the selection.  Off: tabs by default, `copyindent` |
| `35-folding.vim` | fold method from the knob, all open at start, custom fold text.  Off: `foldenable`, `foldcolumn`, saved views |
| `40-files.vim` | swap/backup/undo under `~/.vim/tmp/`, persistent undo, no backups for secrets, last position, mkdir on write, strip trailing whitespace.  Off: `noswapfile`, autosave on focus loss |
| `45-filetypes.vim` | prose wrap+spell, gitcommit columns, python columns, `q` closes help, `g:is_bash`, `.pbs`/`.slurm`/`.env` filetypes, `:Make`.  Off: markdown conceal, soft-wrapped text, F5 runs python, fenced-code highlighting |
| `50-keys.vim` | leader maps (`<space> w q Q ev sv cd x y P p rw v s n p d b ss tw tn tl tc co cc`), `,ww` fixes whitespace, `Y`, `j`/`k`, `n`/`N`, F5 runs the file, `Ctrl-hjkl`, `Ctrl-arrows` resize, `Tab`/`S-Tab` buffers, visual `J`/`K`, `gV`, `]q [q ]l [l`, `w!!`, `F2` paste.  Off: `jk`, `;` as `:`, `Q` as `gq`, `Ctrl-S`, centered `Ctrl-D`/`Ctrl-U`, `J` in place, no arrow keys, emacs keys on the command line, `Esc Esc` in `:terminal` |
| `55-netrw.vim` | tree-style netrw, `-` and `<leader>e`.  Off: hide dotfiles, netrw off |
| `60-plugins.vim.off` | vim-plug with commentary, surround, repeat, fugitive, gitgutter, fzf, editorconfig; about 25 more described and off |

## tmux modules (`~/.config/tmux/conf.d/`)

| Module | Provides |
|--------|----------|
| `00-options.conf` | `tmux-256color` + true color, cursor shapes, focus events, `escape-time 0`, OSC 52 clipboard, 50000 lines, mouse, base index 1, renumber, names, vi copy mode, titles, activity monitoring.  Off: `screen-256color`, `terminal-features`, passthrough, extended keys, directory as window name, vi status keys, `repeat-time`, switch session on destroy, `remain-on-exit`, non-login shells, lock |
| `10-keys.conf` | `r` reload, `\|`/`-` splits and `c` keeping the directory, `hjkl` panes, `HJKL` resize, `x`/`X` kill, `z` zoom, `b` break, `@` join, `y` synchronize panes, `Tab` last window, `M-arrows`, `S`/`C-s`/`R` sessions, `g` popup shell, `C-l` clear, `C-p` log pane, `m` mouse toggle.  Off: `C-a` or `C-Space` prefix, `"`/`%` keeping the directory, `M-hjkl`, vim-tmux-navigator, `S-arrows`, lazygit popup |
| `20-status.conf` | status line: session, windows, prefix indicator, window count, host, clock; the palette in the header.  Off: top, centered, load and date, pane border titles |
| `30-copy.conf` | `v V C-v y Y Esc` in copy mode, mouse drag and clicks, piping to xclip/xsel/wl-copy/pbcopy, `P` paste from clipboard.  Off: `H`/`L` line ends, one-line wheel, `Enter` copy mode |
| `40-nested.conf` | `F12` toggles the outer tmux off for a nested one.  Off: status on top over ssh |
| `50-plugins.conf.off` | tpm with sensible, resurrect, yank; continuum, open, thumbs, extrakto, tmux-fzf, prefix-highlight, themes, navigator described and off |

## Git files (`~/.gitconfig` includes, `~/.config/git/`)

| File | Provides |
|------|----------|
| `core.gitconfig` | pager, whitespace, `autocrlf=input`, `defaultBranch=main`, push current+autoSetupRemote+followTags, `pull.rebase`, `fetch.prune`, rebase autoStash/autoSquash/updateRefs, `diff3`, `commit.verbose`, rerere, status, log, branch/tag sort, columns, autocorrect prompt, `transfer.fsckObjects`, credential cache.  Off: `core.editor` (git opens `$EDITOR`), `quotePath`, `fsmonitor`, `untrackedCache`, `hooksPath`, `sshCommand`, `useForceIfIncludes`, `pull.ff=only`, `fetch.all`, `fetch.pruneTags`, commit graph, `missingCommitsCheck`, `merge.ff=only`, `merge.autoStash`, commit template, submodules, `log.follow`, libsecret/store credentials, advice, `singleKey`, grep, `safe.directory`, LFS |
| `color.gitconfig` | `color.ui=auto` and per-command colors.  Off: moved-line colors, blame by age |
| `aliases.gitconfig` | `st a aa ap unstage discard staged conflicts cm cma ca cae fixup undo wip co sw cob br brdel brclean gone recent default pr lg lga last hist who fl contains root outgoing incoming standup find bl df dfs dfw dfn dfst f pl ps pst psf up sl sp ss snapshot ours theirs aliases ignored ignore assume unassume assumed tags cp rb rbi rbc rba whoami` |
| `diff.gitconfig` | histogram, colorMoved, renames+copies, mnemonic prefixes, vimdiff as difftool/mergetool.  Off: `noprefix`, submodule log, difftastic, delta, diff-so-fancy, meld, VS Code, PDF and docx text diffs |
| `url.gitconfig` | `gh:`, `gh-ssh:`, `gl:` shorthands.  Off: push to GitHub over ssh, all GitHub over ssh, `gl-ssh:`, `cb:`, `bb:` |
| `signing.gitconfig` | commit and tag signing; its include line in `~/.gitconfig` is off.  Off inside: signed pushes, ssh signing, allowed signers, `showSignature` |
| `ignore` | global excludes (editor, OS, environment, agent files).  Off: `*.orig`, Jupyter checkpoints, `.envrc`, packaging, coverage, clangd, node_modules, `*.log` |
| `attributes` | `diff=` drivers by extension, binary types, LF for scripts.  Off: PDF and docx diffs, generated minified and lock files |

## Other dotfiles

| Target | Purpose |
|--------|---------|
| `~/.profile` | POSIX login: PATH and `LANG` for non-bash shells and display managers.  Off: `EDITOR` for desktop programs, session `umask` |
| `~/.bash_profile` | `.profile`, then `profile.d/*.sh`, then `.bashrc`.  Off: tmux on ssh login, `startx` on tty1 |
| `~/.bash_logout` | `clear_console` on a top-level logout.  Off: `clear` |
| `~/.inputrc` | readline: case-insensitive completion, single-Tab listing, colored stats, history search on Up/Down, Ctrl-arrows by word, Ctrl-Delete, Alt-S sudo.  Off: vi mode with mode strings and cursor shapes, `keyseq-timeout`, hidden files, horizontal lists, menu completion, `mark-modified-lines`, `expand-tilde`, Ctrl-P/N prefix search, `search-ignore-case`, Ctrl-W by path, Ctrl-Backspace, Alt-L, vi `jj`/`gg`/`G` |
| `~/.editorconfig` | 2-space default (python too), 4 for rust/c/java/sh, tabs for make/go.  Off: `max_line_length`, CRLF for batch files |
| `~/.curlrc` | follow redirects, connect timeout, stalled-transfer limit, retries, progress bar.  Off: whole-transfer time limit, silent, compressed, fail, newline after output, remote time, create dirs, netrc, IPv4, user agent, proxy |
| `~/.wgetrc` | timeouts, retries.  Off: timestamping, resume, wait, no parent, HSTS file in `~/.cache`, user agent, proxy |
| `~/.screenrc` | no splash, 10000 lines, status line, tmux-like keys.  Off: `C-b` escape, mouse, windows from 1, login shells |
| `~/.dircolors` | `dircolors -p` with `OTHER_WRITABLE` readable on dark terminals |
| `~/.gdbinit` | history, no pagination, pretty printing, intel syntax.  Off: history dedup, debuginfod on or off, full-length printing, null-stop, quiet thread events, auto-load from every directory or from `~/work`, GEF, gdb-dashboard |
| `~/.nanorc` | autoindent, 4-space tabs (2 in python), line numbers, soft wrap, syntax files.  Off: cut from cursor, guide stripe, no help, minibar, position and search history, backups, common editor keys |
| `~/.condarc` | `auto_activate_base: false`, `changeps1: false`, conda-forge only.  Off: `pkgs_dirs`, outdated notice, self-update, default packages, threads, `env_prompt`, error reports, proxy |
| `~/.Xresources` | xterm font, colors, scrollback, clipboard keys; urxvt basics.  Off: Xft rendering and dpi, URL double-click, light scheme |
| `~/.local/bin/dots` | this checkout's `dots`, on `PATH` through `~/.local/bin`; `dots unlink` removes it |
| `~/.local/share/bash-completion/completions/dots` | Tab completion of the `dots` subcommands and their options, loaded by bash-completion on first use (`50-completion.sh`) |
| `~/.ssh/config` (600, `~/.ssh` 700) | includes, keepalive, multiplexing (`~/.ssh/sockets/`), `AddKeysToAgent`, `IdentitiesOnly`, no agent/X11 forwarding by default.  Off: example hosts (cluster, bastion, GitHub on 443, Jupyter tunnel), `accept-new`, `UpdateHostKeys`, `ConnectTimeout`, IPv4, no GSSAPI, quiet log, `SetEnv TERM`, `SendEnv`, `ExitOnForwardFailure`, legacy ssh-rsa |
| `~/.config/ripgrep/config` | smart case, hidden files, ignores, colors.  Off: follow links, sorted output, no VCS ignores, minified files |
| `~/.config/python/pythonrc.py` | REPL history and completion before 3.13; `json math re Path pp` imported.  Off: datetime, numpy/pandas, pretty display, rich, colored prompt |
| `~/.config/pip/pip.conf` | timeout.  Off: `require-virtualenv`, version check, mirror, extra index, trusted host, no cache, `--user` |
| `~/.ctags.d/default.ctags` | universal-ctags excludes and fields.  Off: no markdown |
| `~/.config/kitty/kitty.conf` | everything off: fonts, scrollback, copy on select, cursor, bell, window and tab look, opacity, themes, `term xterm-256color`, shell integration, remote control, keys; reads `local.conf` |
| `~/.ipython/profile_default/ipython_config.py` | everything off: autoreload, start-up imports, banner, vi mode, exit confirmation, autosuggestions, editor, auto-match, colors, traceback mode, show every expression, history |
| `~/.config/matplotlib/matplotlibrc` | everything off: screen and save dpi, figure size, constrained layout, tight bbox, PDF default, editable PDF fonts, grid, spines, font size, math font, LaTeX, Agg backend |
| `~/.sqliterc` | everything off: headers, box and column modes, NULL display, timer, foreign keys |

## `.dotsignore`

In the source root.  One glob per line, `#` comments, matched with
`fnmatch` against the target-relative path and every leading directory of
it: `README.md` matches only at the top; `tests` skips everything under
`tests/`; `*.local` matches at any depth because `*` crosses `/`.  The
shipped file lists `README.md CLAUDE.md HANDOFF.md LICENSE dots
run-tests.sh tests docs reviews __pycache__`.  To not link a file you do
not want on any machine, add its target path here.
