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
| `DOTFILES_HISTDIR` | history | `~/.hist` | per-pane history files and the command log |
| `DOTFILES_HIST_DAYS` | history | `90` | days a closed pane's history file is kept |
| `DOTFILES_HIST_LOG_MONTHS` | history | `12` | months of the command log kept, this one included |
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
| `g:dotfiles_leader` | 50-keys | `','` | leader key |
| `g:dotfiles_plugins` | 60-plugins (off) | `[]` | extra `'owner/repo'` for vim-plug |

`g:dotfiles_modules` is set by the loader (the list `:DotfilesModules` prints).

## Bash modules (`~/.config/bash/rc.d/`)

"Off:" names a few of the settings each module offers switched off;
`dots options --off FILE-NAME` lists them all.

| Module | Provides |
|--------|----------|
| `00-env.sh` | `EDITOR`, `PAGER`, `LESS`, colored man pages, `GREP_COLORS`, `COLORTERM`, XDG variables, `RIPGREP_CONFIG_PATH`, `PYTHONSTARTUP`, locale fallback, `TIME_STYLE`, `PYTHONDONTWRITEBYTECODE`.  Off: less mouse/chop/centering, bat or vim as `MANPAGER`, `MANWIDTH`, `NO_COLOR`, moves of tool files out of `$HOME` (the toolchains' among them, which `20-path.sh` follows), `LC_COLLATE=C`, `PYTHONPYCACHEPREFIX`, `GPG_TTY`, `BROWSER` |
| `10-options.sh` | `globstar extglob autocd cdspell dirspell checkjobs huponexit histappend cmdhist lithist checkwinsize`, history sizes and control, history written after every command, `stty -ixon`, `umask 022`.  Off: `dotglob nocaseglob nullglob failglob nocasematch cdable_vars direxpand notify noclobber pipefail IGNOREEOF histexpand TMOUT histverify histreedit`, XDG history file, live history sharing, no mail check, `umask 077/027`, `ulimit` core and stack |
| `12-history.sh` | `hgrep PATTERN [N]` searches the command log.  Off: one history file per tmux pane (a split starts from its source pane, a new window or session takes over the pane closed last in a session of the same name, else a copy of the shared file), the log of every command with time, host, session and directory, a file a month, the last 12 kept |
| `20-path.sh` | `path_prepend`/`path_append`/`path_remove`; `~/.local/bin`, `~/bin`, cargo/go/npm bins, each where its home variable says; `MANPATH`.  Off: deno, bun, .NET, juliaup, ghcup/cabal, pixi, CUDA, Flatpak, snap |
| `25-ssh-agent.sh.off` | one shared ssh-agent per machine, environment in `~/.ssh/agent.env`.  Off inside: keychain or gpg-agent instead |
| `30-aliases.sh` | ls/grep/diff/ip color, `ll la l lt ltr lS lsd`, `.. ... .... ..... cd.. - d cdg`, `rm -I cp -i mv -i`, `mkdir -pv ln -v chmox`, `df du free dus psg top ports j mnt`, `c clc h hg e v sb vb path now week timestamp epoch ping tree serve cpv myip :q`, `pbcopy`/`pbpaste`, `g gs gl gd gp`, `alert`.  Off: grep skipping VCS dirs, `rm -i`, `--preserve-root`, `sudo ` alias expansion, `vi`→vim, `vim`→nvim, `open`, the oh-my-zsh git set |
| `40-functions.sh` | `mkcd tmpd up bd cdf extract targz ff rgv bak swapname bigfiles count sha mkscript note tree retry timit histstat man reload calc genpass urlencode urldecode fromepoch title hr envg port cheat weather` |
| `45-dirs.sh` | `mark jump unmark marks` bookmarks, `CDPATH`, `1`..`9` for the pushd stack.  Off: ls after cd, cd that pushes (auto_pushd) |
| `50-completion.sh` | bash-completion, `completion.d/`, git completion for the `g` alias, `git ctags` and `git hooks`.  Off: no `/etc/hosts` in host completion, pip completion |
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
| `10-ui.vim` | numbers, `cursorline` in the active window, `scrolloff`, `listchars`, splits below/right, `wrap`+`breakindent`, search count, true color, colorscheme, gray `colorcolumn` marks, yank flash (`hlyank`), cursor shape.  Off: `relativenumber`, `cmdheight`, `cursorcolumn`, `colorcolumn`, `eol:¬`, `fillchars`, `nowrap`, `title`, light background |
| `15-statusline.vim` | status line with buffer, path, flags, filetype, encoding, git branch, position.  Off: spelling language |
| `20-search.vim` | `hlsearch incsearch ignorecase smartcase wrapscan gdefault`, `inccommand`, `:grep` recursive (`rg`, else `grep -r`), quickfix auto-open, visual `*`/`#`.  Off: `nowrapscan`, very magic search, Esc clears highlight |
| `25-completion.vim` | `wildmenu`/`wildmode`/`wildignore`, `path+=**`, popup menu, `completeopt`, omni completion, spelling.  Off: bash-style wildmode, fuzzy, popup info, `noinsert`, `kspell`, Tab completion |
| `30-indent.vim` | width from the knob, spaces; 4 for rust/c/java/sh, tabs for make/go, 2 for python/yaml/json/web; `<`/`>` keep the selection.  Off: tabs by default, `copyindent` |
| `35-folding.vim` | fold method from the knob, all open at start, custom fold text.  Off: `foldenable`, `foldcolumn`, saved views |
| `40-files.vim` | swap/backup/undo under `~/.vim/tmp/`, persistent undo, no backups for secrets, last position, mkdir on write, strip trailing whitespace.  Off: `noswapfile`, autosave on focus loss |
| `45-filetypes.vim` | prose wrap+spell, gitcommit columns, python columns, `q` closes help, `g:is_bash`, `.pbs`/`.slurm`/`.env` filetypes, `:Make`.  Off: markdown conceal, soft-wrapped text, F5 runs python, fenced-code highlighting |
| `50-keys.vim` | leader `,`; leader maps (`<space> , qq QQ qa ev cd cp z sv sh bn bp bl bd f gg / gb y p P o O id rw ri cc ww = ss uu j sc wr tn tl co`), `gc` comment package, `Y`, `j`/`k`, `n`/`N`, F5 runs the file, `Ctrl-hjkl`, `Ctrl-arrows` resize, `Tab`/`S-Tab` buffers, visual `J`/`K`, `gV`, `]q [q ]l [l`, `w!!`, `F2` paste.  Off: `jk`, `;` as `:`, `Q` as `gq`, `Ctrl-S`, centered `Ctrl-D`/`Ctrl-U`, `J` in place, no arrow keys, emacs keys on the command line, `Esc Esc` in `:terminal` |
| `52-tags.vim` | `tags` searched upward from the file and from vim's directory; `<leader>tg` builds tags (`git ctags` in a repository), `tf` jumps by name, `th tv tt tp` open the tag under the cursor in a split, vertical split, tab, preview.  Off: `Ctrl-]` lists when ambiguous |
| `55-netrw.vim` | tree-style netrw, `-` and `<leader>ee`.  Off: hide dotfiles, netrw off |
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
| `core.gitconfig` | pager, whitespace, `autocrlf=input`, `defaultBranch=main`, push current+autoSetupRemote+followTags, `pull.rebase`, `fetch.prune`, rebase autoStash/autoSquash/updateRefs, `diff3`, `commit.verbose`, rerere, status, log, branch/tag sort, columns, autocorrect prompt, `transfer.fsckObjects`, credential cache.  Off: `core.editor` (git opens `$EDITOR`), `quotePath`, `fsmonitor`, `untrackedCache`, `hooksPath`, `sshCommand`, `init.templateDir` (every packaged hook installed, off, in each new repository), `useForceIfIncludes`, `pull.ff=only`, `fetch.all`, `fetch.pruneTags`, commit graph, `missingCommitsCheck`, `merge.ff=only`, `merge.autoStash`, commit template, submodules, `log.follow`, libsecret/store credentials, advice, `singleKey`, grep, `safe.directory`, LFS |
| `color.gitconfig` | `color.ui=auto` and per-command colors.  Off: moved-line colors, blame by age |
| `aliases.gitconfig` | `st a aa ap unstage discard staged conflicts cm cma ca cae fixup undo wip co sw cob br brdel brclean gone recent default pr lg lga last hist who fl contains root outgoing incoming standup find bl df dfs dfw dfn dfst f pl ps pst psf up sl sp ss snapshot ours theirs aliases ignored ignore assume unassume assumed tags cp rb rbi rbc rba whoami` |
| `diff.gitconfig` | histogram, colorMoved, renames+copies, mnemonic prefixes, vimdiff as difftool/mergetool.  Off: `noprefix`, submodule log, difftastic, delta, diff-so-fancy, meld, VS Code, PDF and docx text diffs |
| `url.gitconfig` | `gh:`, `gh-ssh:`, `gl:` shorthands.  Off: push to GitHub over ssh, all GitHub over ssh, `gl-ssh:`, `cb:`, `bb:` |
| `signing.gitconfig` | commit and tag signing; its include line in `~/.gitconfig` is off.  Off inside: signed pushes, ssh signing, allowed signers, `showSignature` |
| `ignore` | global excludes (editor, OS, environment, agent files).  Off: `*.orig`, Jupyter checkpoints, `.envrc`, packaging, coverage, clangd, node_modules, `*.log` |
| `attributes` | `diff=` drivers by extension, binary types, LF for scripts.  Off: PDF and docx diffs, generated minified and lock files |
| `template/` | a git template whose `hooks/` is what `git hooks install` leaves: the dispatcher on each event, every packaged hook linked switched off.  Used only once `init.templateDir` in `core.gitconfig` is switched on |

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
| `~/.ctags.d/default.ctags` | universal-ctags excludes (caches, virtualenvs, build output, `target`) and fields.  Off: no `vendor/`, no markdown |
| `~/.local/bin/git-ctags` | `git ctags`: a `tags` file at the worktree root, then the packaged `ctags` hook installed and switched on, which rebuilds it in the background after `post-checkout`, `post-merge`, `post-rewrite` and `post-commit`; `git ctags off` removes the hook and the file.  Exit 2 on a usage error, 1 without universal-ctags.  Needs: universal-ctags |
| `~/.local/bin/git-hooks` | `git hooks`: install the [packaged git hooks](#packaged-git-hooks-localsharegit-hooks) in a repository, list its hooks, show what one does, switch them on and off |
| `~/.local/share/git-hooks/` | the packaged git hooks and their dispatcher, one file each; see [Packaged git hooks](#packaged-git-hooks-localsharegit-hooks) |
| `~/.config/kitty/kitty.conf` | everything off: fonts, scrollback, copy on select, cursor, bell, window and tab look, opacity, themes, `term xterm-256color`, shell integration, remote control, keys; reads `local.conf` |
| `~/.ipython/profile_default/ipython_config.py` | everything off: autoreload, start-up imports, banner, vi mode, exit confirmation, autosuggestions, editor, auto-match, colors, traceback mode, show every expression, history |
| `~/.config/matplotlib/matplotlibrc` | everything off: screen and save dpi, figure size, constrained layout, tight bbox, PDF default, editable PDF fonts, grid, spines, font size, math font, LaTeX, Agg backend |
| `~/.sqliterc` | everything off: headers, box and column modes, NULL display, timer, foreign keys |

## Packaged git hooks (`~/.local/share/git-hooks/`)

Hooks people commonly want, every one off until switched on in a
repository.  Each file's header says what it does, its events, its
settings and the settings it needs; `git hooks show NAME` prints it.

```sh
git hooks available          # each packaged hook: state here, name, summary
git hooks install            # all of them, switched off (or install NAME...)
git config hooks.test "./run-tests.sh fast"
git hooks on test-push       # refused until a hook's required setting is made
git hooks                    # this repository's hooks: state, event, name, file
git hooks off                # everything that is on
git hooks remove             # back to the hooks the repository had
```

git runs one file per event, so `install` links `.git/hooks/EVENT` to
`dispatch`, which runs each `.git/hooks/EVENT.d/NAME` in name order with
git's arguments, its stdin and `GIT_HOOK_EVENT` set.  A hook is off while
its name ends in `.off`.  A pre- event stops at the first hook that fails,
which fails the commit, merge or push; a post- event runs every hook.
`HOOKS_SKIP="NAME..."` skips hooks for one command; `--no-verify` skips
all of an event's.  A hook the repository already had (a project's tracked
`pre-push` gate, linked as `pre-push.off`) moves into `EVENT.d` under its
event name, in the state it was in, and `git hooks on pre-push` still
switches it; `remove` moves it back once no packaged hook is left for the
event.  `git hooks on` and `off` also switch a plain hook at the top of
`.git/hooks` by name.  Settings are per repository (`git config`, or
`--global` for every one).  `git hooks` exits 2 on a usage error and 1
when it refuses: no such packaged hook, a hook not installed, a required
setting not made, or a hook and its `.off` both present.

| Hook | Event | Does | Settings |
|------|-------|------|----------|
| `whitespace` | pre-commit | refuses trailing whitespace and conflict markers (`git diff --cached --check`) | |
| `big-file` | pre-commit | refuses a staged file over the limit | `hooks.maxFileSize` (5m) |
| `secrets` | pre-commit | refuses added lines with a private key, an AWS, GitHub, Slack, OpenAI or Anthropic token, or a quoted password-like assignment, and added `.env`, `.netrc`, `id_*`, `*.pem`/`key`/`p12`/`pfx` files; `hooks:allow-secret` on a line passes it | |
| `debug-left` | pre-commit | refuses added `breakpoint()`, `pdb`/`ipdb`, `debugger;`, `binding.pry`; `hooks:allow-debug` on a line passes it | |
| `lint` | pre-commit | runs `hooks.lint` with the staged paths | `hooks.lint` (required), `hooks.lintFiles` (pathspecs) |
| `no-commit-on` | pre-commit | refuses a commit straight on a protected branch | `hooks.protect` (`main master`) |
| `branch-tag` | prepare-commit-msg | starts the message with the ticket in the branch name (`ABC-123: `) | `hooks.tagPattern` (`[A-Z][A-Z0-9]+-[0-9]+`) |
| `msg-format` | commit-msg | subject at most `hooks.subjectMax` characters, no trailing period, blank line 2; skips `fixup!`, `squash!`, `amend!` | `hooks.subjectMax` (72) |
| `test-merge` | pre-merge-commit | runs `hooks.test` on the merged tree before git commits a merge (not a fast-forward, a conflicted merge or `--no-commit`) | `hooks.test` (required) |
| `test-push` | pre-push | runs `hooks.test` in a clean temporary worktree of each pushed branch tip | `hooks.test` (required) |
| `protect` | pre-push | refuses deleting or force-pushing a protected branch | `hooks.protect` (`main master`) |
| `wip-guard` | pre-push | refuses commits whose subject matches `hooks.wipPattern` going to a protected branch | `hooks.protect`, `hooks.wipPattern` (`^(wip\|WIP\|fixup!\|squash!\|amend!)`) |
| `published` | pre-rebase | refuses to rebase commits a remote-tracking branch holds | |
| `deps-changed` | post-checkout, post-merge, post-rewrite | names the dependency files (requirements, lock files, `pyproject.toml`, `package.json`, ...) that changed | `hooks.depsFiles` |
| `pyc-clean` | post-checkout, post-merge, post-rewrite | deletes `__pycache__` outside hidden directories and `node_modules` | |
| `submodules` | post-checkout, post-merge, post-rewrite | `git submodule update --init --recursive` where `.gitmodules` exists | |
| `ctags` | post-checkout, post-merge, post-rewrite, post-commit | `git ctags --hook` in the background | |

`deps-changed`, `pyc-clean` and `submodules` skip a file checkout, an
amend and the steps inside a rebase; `ctags` runs on every one.  git has
no post-push event, so there is no post-push hook
([F.2.ad](future-work.md)).

## `.dotsignore`

In the source root.  One glob per line, `#` comments, matched with
`fnmatch` against the target-relative path and every leading directory of
it: `README.md` matches only at the top; `tests` skips everything under
`tests/`; `*.local` matches at any depth because `*` crosses `/`.  The
shipped file lists `README.md CLAUDE.md HANDOFF.md LICENSE dots
run-tests.sh tests docs reviews __pycache__`.  To not link a file you do
not want on any machine, add its target path here.
