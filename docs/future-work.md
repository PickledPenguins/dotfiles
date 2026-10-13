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
- **F.2.y  `smartindent` sent `#` lines to column 0.**  Built 2026-10-12.
  In filetypes without an indent plugin (conf, tmux, text, markdown, ini)
  `o#` landed at column 0, and in prose a line starting with "for" or
  "if" indented the next one. `smartindent` is now an off setting in
  `30-indent.vim` whose description says what it adds and costs;
  `autoindent` and filetype indent cover the rest. `inoremap # X<C-h>#`
  was not taken: it fixes `#` only and maps `#` in every buffer.
- **F.2.z  `j`/`k` as `gj`/`gk` made counts move screen lines.**  Built
  2026-10-12. With `wrap` on, `5j` from a line wrapped over four screen
  lines landed on buffer line 2, against the off `relativenumber`, which
  promises `5j` without counting. `50-keys.vim` now maps
  `nnoremap <expr> j v:count ? 'j' : 'gj'`, likewise `k`: plain `j`/`k`
  still move by screen line, `5gj` still counts screen lines, and a pty
  test checks both.

- **F.2.ab  `SYSTEMD_LESS="$LESS"` dropped systemd's `-S`, `-M` and `-K`.**
  Built 2026-10-12. Setting the variable replaces systemd's default
  `FRSXMK` rather than adding to it, so journalctl wrapped long lines and
  ignored Ctrl-C. `00-env.sh` now sets `SYSTEMD_LESS="$LESS -SMK"`, with
  the description saying why, and a test checks the value.
- **F.2.ac  The toolkit's `prompt_build` guard missed `;prompt_build`.**
  Built 2026-10-12, not yet sent upstream. A hook prepended with a bare
  `;` hid `prompt_build` from `prompt_layout`'s guard, so re-sourcing
  `~/.bashrc` built the prompt twice per display, and the prefix test took
  `prompt_buildx` for `prompt_build`. The toolkit's guard now compares
  whole commands, with newlines and blanks normalized, in its own commit
  with a bats test. The off `_venv_auto` line in `75-python.sh`, the last
  bare-`;` prepend after `60-prompt.sh`, now joins with `; ` behind a
  guard of its own like the other modules.
- **F.2.ad  No post-push hook.**  git has no event after a push completes:
  a push fires only `pre-push` and, on the local side, the
  `reference-transaction` hook for the remote-tracking refs. That hook
  also fires on every fetch, pull, branch and commit, so a "post-push"
  built on it would need to tell them apart from its input alone, and
  would guess. An action after a push stays a wrapper (`git ps && ...`).
  `git hooks -h` says so too.
- **F.2.ae  Repositories made from the git template depend on the
  checkout's path.**  Documented 2026-10-13. `dots` links each file of
  `~/.config/git/template/hooks/` to the source tree by absolute path, and
  `git init` copies a symlink as it is, so after moving the checkout every
  repository made from the template has dangling hooks, which git skips
  without a word. `git hooks install` does not repair them: it counts a
  dangling `NAME.off` as installed. The `templateDir` description and the
  template row of `configuration.md` now give the tested repair,
  `find .git/hooks -xtype l -delete && git init` after `dots apply`, and
  say a hook switched on comes back off. Only matters once
  `init.templateDir` is switched on. Not built: a template whose hooks
  resolve through `~/.local/share/git-hooks`, which needs a `dots`
  attribute making a symlink with a given target (chezmoi's `symlink_`);
  the route if `templateDir` goes on for good.
- **F.2.ak  What is an alias, a function, or a program on PATH.**  Built
  2026-10-13. The rule is in [contributing.md](contributing.md#where-a-change-goes).
  Every alias and function in `rc.d/` was sorted by it: 44 became scripts
  in the `linuxbin` repository's `bin/` (`bin/hpc/` for `qtail` and
  `srun-i`), each with its own `docs/README_<name>.md` and tests there;
  none is used by dotfiles itself, so dotfiles has no bin directory of its
  own for them. A package directory goes on PATH through
  `DOTFILES_PATH_APPEND`, appended so a system program of the same name
  wins; `path_clash` (`20-path.sh`) lists the names that clash, and
  `path_prepend`/`path_append` typed at the prompt print them. Bugs fixed
  on the way, in the linuxbin commit: `targz .` wrote `..tar.gz`;
  `genpass` and `bigfiles` returned 141 under `pipefail`; `psg` printed
  its header with no match; `port` printed a header with no match. What
  is still open there is in linuxbin's `docs/future-work.md` (F.1.a-c).

## F.3 tests

- **F.3.a  mutmut or cosmic-ray** instead of the hand-written mutant list,
  if either becomes available on the machines this runs on. The list
  stays either way as the documented minimum.
- **F.3.b  Visual check of the prompt** (render `PS1` through bash and
  compare a golden frame). The toolkit's bats suite covers it;
  here only "each layout builds" is asserted.
- **F.3.c  A gate on shell startup time.**  Built 2026-10-13, opt-in.
  `./run-tests.sh perf` (`tests/perf.py`, no pytest) times 15
  interactive starts and a warm `prompt_build` in a temporary linked home
  and fails more than 25% over this host's baseline, kept in
  `.git/perf-baseline.json` so every worktree shares it; the first run or
  `--rebaseline` records it. It is in neither `all` nor `test-push`: the
  packaged `perf-push` hook runs it on each pushed commit, installed off
  by `./run-tests.sh hook` and switched on with `git hooks on perf-push`.
  The entry's 0.3 ms for `prompt_build` was the git cache alone; the
  whole call was 40 ms, now 13.5 ms (F.3.h); the gate also times it
  inside tmux, with a stub `tmux`.
- **F.3.h  Forks in every `prompt_build`.**  Measured 2026-10-13 in a
  temporary linked home: 40 ms at the top of this repository, 32 ms in
  `/tmp`. Each fork of an interactive bash costs one to three ms, and
  every prompt pays it, after every command. In parts:
  - Layout: built 2026-10-13, 39 to 22 ms. `_top_seg` and `_env_seg`
    (`dot_config/bash/prompt/layout.sh`) were a command substitution
    each that ran four to six more (`$(_ps_seg_shlvl)`,
    `$(_ps_seg_jobs)` ...); they print the segments straight out, and
    decide where a separator goes from what each segment reads (`SHLVL`,
    `jobs %%`, `DISPLAY`, the `GIT_*` globals), with the output
    unchanged in 220 combinations.
  - A, forks inside segments: built 2026-10-13 (toolkit v0.1.13), 22 to
    13.5 ms a prompt at the top of this repository, 28 to 16 ms with a
    stub `tmux` (the perf gate's `prompt` and `prompt_tmux`).
    `_ps_seg_pwd` forked three (`strip_ansi`, `tr`, `str_width`),
    `_ps_seg_tmux` three, `_ps_seg_venv` one (`basename`).
    `strip_ansi`, `str_width` and `str_repeat` take `-v VAR`, as
    `printf -v` does, and `_ps_sanitize_into` deletes control bytes in
    bash under `LC_ALL=C` where `tr -d` did; now only `tmux` itself
    forks.
  - D, a space for an unreachable tmux: built 2026-10-13. `_env_seg`
    spaced the pane whenever `TMUX` was set, so a server that did not
    answer left `:9  | (e)`; it calls `_ps_tmux_into`, which fails then,
    and spaces only a pane it got.
  - C, segments that set a variable instead of printing: rejected
    2026-10-13. Each segment is still one `$( )` in `_ps_expand_into`
    (`prompt.sh:210`), about 4.4 ms a prompt in all. Saving it changes
    the segment interface the toolkit documents, so every custom segment
    and the rules for writing one would be rewritten, and runs each
    segment in the shell itself, where a stray `exit` closes the shell
    and a `cd` or a variable leaks into it. The perf gate catches that
    cost growing.
  - B, a tmux collector with a TTL: open, the owner's call. It saves the
    one `tmux display-message` a prompt inside tmux (6.5 ms), and a
    renamed session or a new window then shows up to the TTL (5 s) late.
- **F.3.d  Mutation of the shell code.**  Built 2026-10-13 as
  `./run-tests.sh mutate-shell`: `tests/shell-mutants.txt` holds
  `FILE ||| FIND ||| WITH ||| TESTS` per line, TESTS a `-k` expression over
  the long suite or a toolkit `.bats` file; each mutant runs through
  `breaks-it` on a copy of the checkout under `.build/mutate-shell`, and a
  FIND no longer in its file is reported stale and fails the gate. Each
  TESTS must pass unmutated first, so a `-k` that selects nothing cannot
  pass for a caught mutant. 47
  mutants over the packaged hooks and dispatcher, `git hooks`, the
  `20-path.sh` helpers and `path_clash`, the `40-functions.sh` helpers,
  `_title_arm`, `_venv_auto`, `layout.sh` and the toolkit's git cache
  (43 at first; the `extract` and `swapname` mutants left with those
  tools for linuxbin, F.2.ak). The first run left 4 survivors:
  three tests added (`path_prepend` of a missing directory, `extract`
  failing on a missing file alone, the git cache's TTL) and one equivalent
  mutant dropped, then a fourth test (`git hooks remove` keeping the
  dispatcher while another hook stays) for a `tidy` mutant added later.
  About 6 min, so not part of `all`.
- **F.3.e  A toolkit test file was named for a release.**  Built
  2026-10-13. `test_v012_changes.bats` held 31 tests of v0.1.2 to v0.1.4;
  they now sit with their subjects, in the new `cache.bats` and
  `cmd_timer.bats` and in `collectors.bats`, `git_info.bats`,
  `prompt_segments.bats` and `term_utils.bats`. `cmd_timer.bats` also took
  the trap tests from `collectors.bats`. Six went: two that checked for a
  `DEBUG` trap right after sourcing, which no longer installs one, so they
  passed whatever the skip variables did; two that repeated
  `term_utils.bats`; and two merged into one. The `git_info` TTL test still
  runs `git_info.sh` alone in a bare bash, so it still proves the library
  loads `cache.sh` itself.
- **F.3.f  `tests/hooks/pre-push` was a second copy of the packaged
  `test-push` hook.**  Built 2026-10-13. The repository's copy is gone;
  `./run-tests.sh hook` sets `hooks.test` to `./run-tests.sh fast` and runs
  `git hooks install test-push`, which installs it switched off, after
  removing any link to the old copy. `git hooks on test-push` switches it
  on. Every git hook stays in this repository, in the git-hooks catalog.
- **F.3.g  Push hooks were tested only against a named remote.**  Built
  2026-10-13. Git gives a hook the URL in place of the remote's name when a
  push names one. `test-push` does not read it and `protect` only prints
  it; `wip-guard` then checks every commit in a new branch's history,
  since no remote-tracking ref says what a URL has. That is kept as the
  cautious reading of "the commits the remote does not have yet", the same
  as a named remote with nothing fetched; falling back to every remote's
  branches would let a commit through that another remote has but this one
  lacks. The header and `configuration.md` say so, and a test pushes to a
  URL.

## F.4 housekeeping

Things done by hand outside the repository, moved from the 2026-09-20
handoff.

- **F.4.a  Publishing.**  Settled: public at
  `github.com/PickledPenguins/dotfiles` since 2026-10-10 at the latest,
  like the other projects. Its whole history was scanned on 2026-10-13
  for private keys and AWS, GitHub and Anthropic tokens: the only hits are
  the `secrets` hook's test fixtures, and `private_dot_ssh/config` names
  only commented `example.edu` hosts. Pushing stays the owner's call;
  `CLAUDE.md`, untracked on 2026-10-11, leaves the public tip with the
  next push of `main` and stays in its history.
- **F.4.b  `~/.gitignore`.**  The old `~/env/.gitconfig` set
  `excludesfile = ~/.gitignore`; this set uses `~/.config/git/ignore`,
  which already holds that file's one line
  (`**/.claude/settings.local.json`). The set is live, so `~/.gitignore`
  can go; not checked whether anything else reads it.
- **F.4.c  `~/env/` and `~/.bash_aliases`.**  The old configuration, kept
  as a backup. `~/.bash_aliases -> env/.bash_aliases` is still in `$HOME`
  and nothing sources it. Both can go once nothing from them is missed.
- **F.4.d  ssh hosts that relied on agent-offered keys.**  Checked
  2026-10-13 and kept on. `IdentitiesOnly yes` in `~/.ssh/config` offers
  only keys named by `IdentityFile`, or the default key files when none
  is. On this machine the agent holds two keys, `id_ed25519` and
  `id_rsa`, both default files, so every host still gets them. A machine
  where a key is only in the agent (a login node reached with
  `ForwardAgent`) can lose it; the setting's description and
  `docs/lifecycle.md#ssh` give the fixes in `~/.ssh/config.local`.
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
