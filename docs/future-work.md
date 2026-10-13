# Future work

Known gaps, ideas, and decisions taken not to build something. Nothing
here is scheduled; an item is cited by its label. Back to the
[README](../README.md). Open findings from test writing live in
`reviews/` until `caddressreview` closes them.

## F.1 dots

- **F.1.a  Orphan cleanup.**  Built as `dots prune` (2026-09-20). The
  rule that unblocked it: remove only links into the source tree whose
  referent is gone; a link into the tree that still resolves (a
  `.dotsignore`d file someone linked by hand) is left. Still open inside
  it: `prune` walks the top-level directories that hold targets in full,
  so a huge `~/.config` costs a directory walk; acceptable for a command
  run by hand.
- **F.1.b  `add -r DIR`.**  `add` refuses directories; importing a tree is
  `find DIR -type f | xargs dots add`. A recursive flag is a few lines; not
  built because the refusal makes the user look at each file's mode before
  it becomes a `private_` decision in git history. Declined on
  recommendation on 2026-09-20 (the owner answered "whatever is
  recommended"), not explicitly; reopen if importing another home
  directory turns out to be tedious.
- **F.1.c  Backup pruning.**  `~/.dotfiles-backup/<ts>/` trees accumulate.
  A `dots backups [--prune N]`. Not built: `rm -r` is one command and
  automatic deletion is the one thing dots promises never to do.
- **F.1.d  Templating.**  Rejected. chezmoi's `.tmpl` files are the reason
  to use chezmoi; here every per-machine difference so far fits a knob or
  a hook file (`complex/04` exercises every one). Templates would end the
  edit-the-live-file property that symlinks give.
- **F.1.e  chezmoi in symlink mode.**  Rejected. It would give `add`,
  `diff` and templating for the cost of a Go binary on every login node;
  the whole of `dots` is ~450 lines of stdlib Python and python3 is already
  there.
- **F.1.f  `forget` of a target that is not linked keeps no copy.**
  Built 2026-10-12, both shapes: a missing target or a stale link gets the
  copy, and for a conflict the source moves into the backup tree with a
  `backup` line. `forget` no longer deletes content outside git.
- **F.1.g  A path that selects nothing was silent.**  Built 2026-10-12.
  `dots apply ~/.vimrcx` printed `0 change(s)` and exited 0, `status` and
  `unlink` likewise. Now `apply`, `status` and `unlink` print `skip PATH:
  not managed` before the summary for each path that selects no target and
  exit 1, as `forget` does; the paths that match are still acted on.
  Catalog case `failures/12-apply-an-unmanaged-path`.
- **F.1.h  Managing a name that starts with a prefix word.**  `add` now
  refuses `~/private_notes` or `~/bin/dot_env`, since stored under its own
  name such a file would be read back as an attribute. chezmoi solves it
  with a `literal_` prefix that ends attribute parsing. The same here
  would be about five lines in `parse_name` and `source_name` plus a
  naming rule in `docs/concepts.md`. From the 2026-10-07 ctesting audit;
  not built because no such file has turned up in a real home yet.
- **F.1.i  A second checkout managed `~/.dotfiles`, not itself.**  Built
  2026-10-12. `source_dir` tried `~/.dotfiles` before the directory holding
  `dots`, so `./dots apply` from a clone or worktree acted on
  `~/.dotfiles`, and where `~/.dotfiles` belonged to another tool (a bare
  repository, yadm) it linked `$HOME` into that tree. Now a `dots` with a
  `.dotsignore` beside it manages its own tree; `~/.dotfiles` is the
  fallback for a `dots` copied on its own. The cost, in `docs/cli.md`: a
  clone's `apply` links `$HOME` into the clone, and deleting it leaves the
  links dangling. Printing the tree used (the other shape) was not built.

## F.2 configuration

- **F.2.a  A `dots doctor`** that runs the integration checks against the
  live `$HOME` (bash loads, vim loads, tmux parses, git includes resolve).
  Not built: `./run-tests.sh long` does it against a copy, and a broken
  live shell is noticed immediately.
- **F.2.b  zsh.**  Not planned; the author uses bash on every machine, and
  the module layout would have to be duplicated rather than shared.
- **F.2.c  Machine profiles** (a `~/.config/bash/profile` naming a set of
  knobs and disabled modules, e.g. `hpc`, `desktop`). Not built: two
  files, `~/.bashrc.before` and `disabled`, already are the profile, and a
  third layer of indirection needs more than one machine class to justify
  it.
- **F.2.d  BSD/macOS aliases.**  The `ls`/`rm`/`ss` aliases assume GNU;
  only `CLICOLOR` is set otherwise. Untested here (no such machine), so
  left as a known limit rather than a guess.
- **F.2.e  More tools in the catalog.**  Not shipped because nothing here
  uses them and each new file is one more link in every home: neovim
  (`~/.config/nvim/init.vim` sourcing `~/.vimrc` would need its own undo
  and swap directories, since vim's and neovim's files are incompatible),
  alacritty, wezterm, starship, psql, R, npm, lazygit, bat. Add one as a
  file in the options format with a loader in `tests/test_options.py`.
  htop is not a candidate: it rewrites its own config on exit, which would
  rewrite the repository's file.
- **F.2.f  Per-machine opt-out of whole files.**  `.dotsignore` is
  committed, so a file you never want linked on one machine (the kitty
  config on a server) is still linked there; harmless, since a program that
  is not installed never reads it, and every setting in the four
  catalog-only files is off. A `~/.config/dots/ignore` read by `dots`
  would fix it; not built until a file does harm somewhere.
- **F.2.g  Exercising settings, not just loading them.**  The switch-on
  test proves each setting loads; it does not prove an alias's program
  exists or a key binding does what its description says. Doing that is
  one assertion per setting, by hand; the integration tests do it for the
  settings that are on by default.
- **F.2.h  A `cached` command for command output.**  `cached [-t TTL]
  [--refresh] -- CMD...` runs CMD once, stores its output and exit status
  under `~/.cache/cached/` keyed by a hash of the command line and `$PWD`,
  and replays them until TTL expires: slow cluster commands (`squeue`,
  `qstat`, `lfs quota`) and network calls, from any shell, script or cron.
  The toolkit's `prompt/toolkit/lib/cache.sh` is not this: it records only
  when a key was last refreshed, in one shell's memory, so nothing outside
  that shell sees it. Promoting it to its own module, or moving it out of
  the toolkit subtree (which forks the toolkit, since `git_info.sh` sources
  it from its own directory), was considered and rejected. Open before
  building: whether `$PWD` is part of the key, whether a failed run is
  replayed or rerun, pruning of the cache directory, and refusing commands
  that read stdin or need a tty. About 30-40 lines of bash; it belongs in
  `linuxbin` as a standalone script rather than here as a function, since a
  function in `40-functions.sh` exists only in interactive shells.
- **F.2.i  `@cmd_time` counts the time spent at the prompt.**  Removed
  from `layout.sh` on 2026-10-12 rather than fixed: the owner does not use
  it. The bug stays in the toolkit: `prompt_build` arms the timer and the
  DEBUG trap fires for `_prompt_gap` while `PROMPT_COMMAND` still runs
  (`prompt/toolkit/lib/cmd_timer.sh:50`), so a duration includes the time
  at the prompt. To bring it back, fix the timer first: record the start
  in `PS0`, which bash 4.4+ expands after Enter and before the command, as
  `${_z:$((_CMD_TIMER_START=EPOCHSECONDS,0)):0}` with `_z` set (an unset
  `_z` skips the arithmetic), keeping the DEBUG trap only for older bash;
  `15-tmux-env.sh` also appends to `PS0`. A toolkit commit, sent upstream.
- **F.2.q  `cat` ran bat when bat was installed.**  Built 2026-10-12:
  the alias in `rc.d/80-tools.sh` is an off setting (`Needs: bat`), as the
  module's header asks of a block that changes a familiar command; its
  description names the cat flags bat lacks and the refused binary files.
  The `bat`/`batcat` alias and `BAT_STYLE` stay on.
- **F.2.r  Completion scripts generated at every shell start.**  Built
  2026-10-12. kubectl's and gh's completion ran the program in every
  interactive shell where it was installed, kubectl alone about 50-100 ms.
  `80-tools.sh` now installs a stub completion for `kubectl`, `k` and `gh`
  that loads the real one on the first Tab and returns 124 so bash retries
  with it: no start-up cost, never stale after an upgrade, unlike a cached
  file in `completion.d/`. uv's line was already off. A test checks
  neither program runs before the first Tab.
- **F.2.s  Opening a `/tmp` file switched backups and viminfo off for the
  session.**  Built 2026-10-12. `setlocal nobackup nowritebackup viminfo=`
  on the global options turned all three off for every later file after
  bash's `fc` or `crontab -e` opened one under `/tmp`, so a failed write
  could truncate a file and nothing was saved to viminfo. Now
  `backupskip` covers the secret patterns and `/dev/shm` (it also skips
  the write copy), `viminfo+=r/tmp,r/dev/shm` keeps their marks out, swap
  and undo stay off per buffer, and only a secret switches viminfo off for
  the session, as the comment says. `$TMPDIR` paths are in vim's default
  `backupskip` but not in the swap/undo autocmd.
- **F.2.t  vim inside tmux got no drag, wide clicks or focus events.**
  Built 2026-10-12. Under `TERM=tmux-256color` vim 9.1 picked
  `ttymouse=xterm` and left `t_fe` empty, so `mouse=a` could not drag,
  clicks past column 223 were lost and `FocusGained` never fired.
  `dot_vim/rc/00-general.vim` now sets `ttymouse=sgr`, `t_fe`/`t_fd` and
  the focus key codes when `TERM` starts with `tmux` or `$TMUX` is set; on
  although new settings start off, because it only makes `mouse=a` and
  tmux's `focus-events` work. GNU screen is left alone. Not caught: vim
  over ssh from tmux with `TERM=screen-256color` (no `$TMUX` on the far
  side); the comment says to set it in `~/.vimrc.local` there.
- **F.2.u  vim does not read `.editorconfig`.**  Built 2026-10-12, off:
  `"if has('patch-9.0.1799') | packadd! editorconfig | endif` in
  `dot_vim/rc/30-indent.vim`, off because it changes how vim saves every
  file under `$HOME` (`~/.editorconfig`'s `[*]`), and the
  `g:dotfiles_indent` knob stops applying there. On: the guards that make
  switching it on safe, for the package or the `60-plugins.vim.off`
  plugin. `g:EditorConfig_disable_rules` drops `charset` and
  `end_of_line`, which would rewrite latin-1 and CRLF files whole; a hook
  makes a project's `trim_trailing_whitespace = false` stop the
  strip-on-write in `40-files.vim`; `dot_editorconfig` gives
  `Makefile*` and `GNUmakefile` tabs, which `[*]`'s spaces would break.
- **F.2.v  `gdefault` is on.**  Built 2026-10-12: `#set gdefault`, and
  `<leader>rw` and `<leader>ri` type the `/g` themselves.
- **F.2.y  `smartindent` sends `#` lines to column 0.**
  `dot_vim/rc/30-indent.vim:32`. Checked: in `conf` buffers (ssh config,
  tmux.conf) `o#` lands at column 0; python, sh and yaml are unaffected,
  their indent plugins override it. From the 2026-10-08 settings
  creview. Future work because there are two shapes: drop `smartindent`
  (`autoindent` and filetype indent cover the rest), or keep it with
  `inoremap # X<C-h>#`.
- **F.2.z  `j`/`k` as `gj`/`gk` make counts move screen lines.**
  `dot_vim/rc/50-keys.vim:58`. With `wrap` on, `5j` moves five screen
  lines, not five buffer lines, against the off `relativenumber`
  (`10-ui.vim:22`), which promises `5j` and `d3k` without counting. From
  the 2026-10-08 settings creview. Future work because it changes a
  movement key. Fix: `nnoremap <expr> j v:count ? 'j' : 'gj'`, likewise
  `k`.

- **F.2.ab  `SYSTEMD_LESS="$LESS"` dropped systemd's `-S`, `-M` and `-K`.**
  Built 2026-10-12. Setting the variable replaces systemd's default
  `FRSXMK` rather than adding to it, so journalctl wrapped long lines and
  ignored Ctrl-C. `00-env.sh` now sets `SYSTEMD_LESS="$LESS -SMK"`, with
  the description saying why, and a test checks the value.
- **F.2.ac  The toolkit's `prompt_build` guard misses `;prompt_build`.**
  `dot_config/bash/prompt/toolkit/prompt.sh:455` skips the prepend only
  when `PROMPT_COMMAND` starts with `prompt_build` or holds `;
  prompt_build`; a hook added in front with `;` and no space hides it, and
  a second `prompt_layout` adds `prompt_build` again. `65-title.sh` was
  the one such hook here and now joins with `; ` (the 2026-10-08 settings
  creview's first finding, fixed with a guard on each prepend). Fix: also
  match `*';prompt_build'*`, with a bats test, in its own commit sent
  upstream.
- **F.2.ad  No post-push hook.**  git has no event after a push completes:
  a push fires only `pre-push` and, on the local side, the
  `reference-transaction` hook for the remote-tracking refs. That hook
  also fires on every fetch, pull, branch and commit, so a "post-push"
  built on it would need to tell them apart from its input alone, and
  would guess. An action after a push stays a wrapper (`git ps && ...`).
  `git hooks -h` says so too.
- **F.2.ae  Repositories made from the git template depend on the
  checkout's path.**  `dots` links each file of
  `~/.config/git/template/hooks/` to the source tree by absolute path, and
  `git init` copies a symlink as it is, so `.git/hooks/EVENT` in a new
  repository points into `.../dotfiles/dot_config/git/template/`, while
  `git hooks install` links through `~/.local/share/git-hooks`. Move the
  checkout and every repository made from the template has dangling hooks,
  which git skips without a word; `dots apply` repairs the home links, not
  those. Only once `init.templateDir` in `core.gitconfig` is switched on.
  From the 2026-10-10 creview. Future work because the fix has more than
  one shape: a sentence in the template row of `configuration.md`, or a
  template whose hooks resolve through `~/.local/share/git-hooks` (which
  `dots` cannot produce: it links every file to its source).
- **F.2.ak  What is an alias, a function, or a program on PATH.**  From
  the owner's TODOs of 2026-10-12; the TODO's sentence stops at "to ensure
  we always". The rule proposed: an alias when the words only go in front
  of the arguments; a function when the arguments land in the middle, or
  it must change the shell itself (cd, variables, history, traps); a
  script in `~/.local/bin` otherwise, since a script also works from
  `xargs`, `find -exec`, vim's `:!`, cron and other shells, and costs no
  startup time. Then a pass over `30-aliases.sh` and `40-functions.sh`
  sorting each name by it.

## F.3 tests

- **F.3.a  mutmut or cosmic-ray** instead of the hand-written mutant list,
  if either becomes available on the machines this runs on. The list
  stays either way as the documented minimum.
- **F.3.b  Visual check of the prompt** (render `PS1` through bash and
  compare a golden frame). The toolkit's bats suite covers it;
  here only "each layout builds" is asserted.
- **F.3.c  A gate on shell startup time.**  Every new terminal pays for
  `~/.bashrc`, and nothing fails when a module adds 200 ms. Measured on
  2026-10-07 in a throwaway home: `bash -i -c exit` 70-76 ms over 7 runs,
  median 72 ms. Fix: a `perf` command in `run-tests.sh` that times 15
  starts in a temporary linked home and fails above a baseline median
  stored in `.build/` plus 25%, with the baseline and machine recorded in
  `docs/testing.md`. From the 2026-10-07 ctesting audit. Future work
  because it is a new gate with a threshold to choose, and a timing gate
  is noisy on a shared login node. The 2026-10-08 ctesting audit asks
  for a second median in the same gate: `prompt_build` in a git
  repository with a warm cache, which the toolkit's v0.1.9 cache work
  brought from about 6 ms to 0.3 ms.
- **F.3.d  Mutation of the shell code.**  `./run-tests.sh mutate` covers
  `dots` only. The bash modules carry branches the long suite asserts
  (`_venv_auto`, `_title_arm`, the `20-path.sh` helpers, `bd`, `swap`,
  `extract`) and so does the toolkit's git cache (`lib/git_info.sh`,
  mutated by hand on 2026-10-08: 9 mutants, all caught after three tests
  were added), but nothing re-runs those mutants. From the 2026-10-08
  ctesting audit. Fix: a second list, `FILE ||| find ||| with` per line,
  driven through `breaks-it` by `mutate`, whose test command is the long
  subset that loads the file, or `bats` for a toolkit file. Future work
  because it is a new gate, and each mutant costs a long-suite subset
  (seconds, not the fast suite's milliseconds). The 2026-10-10 ctesting
  audit adds `git-hooks` (`ensure_dispatch`, `tidy`, `switch`, `on_now`),
  the dispatcher's pre- against post- status rule and `HOOKS_SKIP`
  matching, and the 18 packaged hooks, whose tests are in the long
  `test_git_hooks.py`.
- **F.3.e  A toolkit test file named for a release.**
  `prompt/toolkit/tests/test_v012_changes.bats` holds 31 tests of features
  from v0.1.2 to v0.1.4 (cache, command timer, `term_utils`, `_ps_expand`,
  collectors, `pbs_nodes`), whose subjects mostly have files already; a
  reader looking for a feature's tests has to know which release added
  it. From the 2026-10-08 ctesting audit. Future work because the move
  has more than one shape: the cache and timer tests have no file to go
  to, and moving a test that sources one library into a file whose
  `setup` loads them all changes what it isolates. A toolkit-only commit
  either way, with the README's test table updated.
- **F.3.f  `tests/hooks/pre-push` is a second copy of the packaged
  `test-push` hook.**  Both unset the git variables, check out each pushed
  tip in a temporary worktree, run the tests there and stop the push on a
  failure; the repository's copy also skips a commit that lacks the file.
  A fix to one has to be made in the other. And `./run-tests.sh hook`
  (`run-tests.sh:63`) links `.git/hooks/pre-push.off` beside whatever is
  at `.git/hooks/pre-push`: once `git hooks install` has put the
  dispatcher there, the `git hooks on pre-push` it advises stops with
  `git hooks: both .../pre-push and .../pre-push.off exist; remove one`.
  From the 2026-10-10 creview. Future work because either fix changes a
  runner command and a documented path, and which hook to run is the
  owner's call. Fix: drop `tests/hooks/pre-push` and `hook`, and document
  `git config hooks.test "./run-tests.sh fast"` with
  `git hooks install test-push`; or keep `hook` and link into
  `pre-push.d/pre-push.off` when the dispatcher owns the event.
- **F.3.g  Push hooks are tested only against a named remote.**
  `protect`, `wip-guard` and `test-push` take the remote from `$1`, which
  is the URL when a push names one. `wip-guard` then builds
  `--remotes=URL`, which matches no ref, so a new branch has every commit
  in its history checked, not only the unpushed ones. No test pushes to a
  URL. From the 2026-10-10 ctesting audit. Future work because the test
  would fail today on what may be a defect: whether a URL push should fall
  back to every remote-tracking branch (`--remotes`) is a design call.

## F.4 housekeeping

Things done by hand outside the repository, moved from the 2026-09-20
handoff.

- **F.4.a  Publishing.**  There is no remote. The other projects are
  under `github.com/PickledPenguins/`; whether this one goes there is not
  decided.
- **F.4.b  `~/.gitignore`.**  The old `~/env/.gitconfig` set
  `excludesfile = ~/.gitignore`; this set uses `~/.config/git/ignore`,
  which already holds that file's one line
  (`**/.claude/settings.local.json`). The set is live, so `~/.gitignore`
  can go; not checked whether anything else reads it.
- **F.4.c  `~/env/` and `~/.bash_aliases`.**  The old configuration, kept
  as a backup. `~/.bash_aliases -> env/.bash_aliases` is still in `$HOME`
  and nothing sources it. Both can go once nothing from them is missed.
- **F.4.d  ssh hosts that relied on agent-offered keys.**
  `IdentitiesOnly yes` in `~/.ssh/config` offers only keys named by
  `IdentityFile`; a host that worked with any agent key needs an
  `IdentityFile` line in `~/.ssh/config.local`. Not checked against the
  owner's hosts.
- **F.4.e  Agent files and generated paths in the root.**  The
  workspace layout standard puts `CLAUDE.md` in `.claude/`, `HANDOFF.md`
  and `reviews/` in `.agent/`, and the test runner under `tests/`. Here
  they sit in the root, as this repository's `CLAUDE.md` lists them. From
  the 2026-10-07 creview (the `.benchmarks/` half was fixed:
  `run-tests.sh` passes `-p no:benchmark`). Future work because each move
  changes a documented path: `.dotsignore`, the `CLAUDE.md` root list,
  `docs/testing.md` and the pre-push hook all name `run-tests.sh` and
  `reviews/`. `dots` stays in the root, since `dot_local/bin/dots` and the
  README use `~/.dotfiles/dots`.
