# Future work

Known gaps, ideas, and decisions taken not to build something.  Nothing
here is scheduled; an item is cited by its label.  Back to the
[README](../README.md).  Open findings from test writing live in
`reviews/` until `caddressreview` closes them.

## F.1 dots

- **F.1.a  Orphan cleanup.**  Built as `dots prune` (2026-09-20).  The
  rule that unblocked it: remove only links into the source tree whose
  referent is gone; a link into the tree that still resolves (a
  `.dotsignore`d file someone linked by hand) is left.  Still open inside
  it: `prune` walks the top-level directories that hold targets in full,
  so a huge `~/.config` costs a directory walk; acceptable for a command
  run by hand.
- **F.1.b  `add -r DIR`.**  `add` refuses directories; importing a tree is
  `find DIR -type f | xargs dots add`.  A recursive flag is a few lines; not
  built because the refusal makes the user look at each file's mode before
  it becomes a `private_` decision in git history.  Declined on
  recommendation on 2026-09-20 (the owner answered "whatever is
  recommended"), not explicitly; reopen if importing another home
  directory turns out to be tedious.
- **F.1.c  Backup pruning.**  `~/.dotfiles-backup/<ts>/` trees accumulate.
  A `dots backups [--prune N]`.  Not built: `rm -r` is one command and
  automatic deletion is the one thing dots promises never to do.
- **F.1.d  Templating.**  Rejected.  chezmoi's `.tmpl` files are the reason
  to use chezmoi; here every per-machine difference so far fits a knob or
  a hook file (`complex/04` exercises every one).  Templates would end the
  edit-the-live-file property that symlinks give.
- **F.1.e  chezmoi in symlink mode.**  Rejected.  It would give `add`,
  `diff` and templating for the cost of a Go binary on every login node;
  the whole of `dots` is ~450 lines of stdlib Python and python3 is already
  there.
- **F.1.f  `forget` of a target that is not linked keeps no copy.**
  `dots:cmd_forget` copies the source to the target only when the target
  is `ok`; when it is `missing` or in conflict the source file is removed
  and its content then exists only in git, so uncommitted edits are lost
  (`test_forget_unlinked_target_just_drops_the_source` pins this).  From
  the 2026-10-07 creview and creadme audits; the architecture decision was
  reworded to say what the code does.  Not changed silently because both
  shapes are reasonable: for a `missing` target, copy the source there (the
  user asked to keep the file); for a conflict, move the source into the
  backup tree rather than delete it.  Either changes `forget`'s output (a
  `backup` line) and what is left in `$HOME`, plus `docs/cli.md`,
  `docs/lifecycle.md` and that test.
- **F.1.g  A path that selects nothing is silent.**  `dots apply ~/.vimrcx`
  prints `0 change(s)` and exits 0; `dots status ~/typo` prints `nothing
  managed`; `unlink` likewise (`dots:selected` just matches nothing).  A
  typo looks like success, while `forget` already says `skip ... not
  managed` and exits 1.  From the 2026-10-07 creview.  Future work because
  it adds a message and turns an exit 0 into 1 for an input that is
  accepted today.  Fix: in `apply`, `status` and `unlink`, print `skip
  PATH: not managed` for each path argument that selected no entry and
  exit 1, as `forget` does; new catalog case under `failures/`.
- **F.1.h  Managing a name that starts with a prefix word.**  `add` now
  refuses `~/private_notes` or `~/bin/dot_env`, since stored under its own
  name such a file would be read back as an attribute.  chezmoi solves it
  with a `literal_` prefix that ends attribute parsing.  The same here
  would be about five lines in `parse_name` and `source_name` plus a
  naming rule in `docs/concepts.md`.  From the 2026-10-07 ctesting audit;
  not built because no such file has turned up in a real home yet.
- **F.1.i  A second checkout manages `~/.dotfiles`, not itself.**
  `source_dir` (`dots:46`) tries `$DOTS_SOURCE`, then `~/.dotfiles`, and
  only then the directory holding `dots`.  So `./dots apply` from a
  worktree or a second clone acts on `~/.dotfiles`, and on a machine where
  `~/.dotfiles` belongs to another tool the `~/.local/bin/dots` a
  checkout's `apply` linked manages that other tree.  `docs/cli.md`
  documents the order, so this is a trap rather than a misdescription.
  From the 2026-10-07 creview.  Future work because the fix is a design
  call with two shapes: prefer the directory holding `dots` when it
  contains `.dotsignore` (changes which tree a plain `dots` uses from a
  second checkout), or have `apply` print the source tree it used
  (changes its output).  Either way `docs/cli.md`'s `--source` row and the
  catalog cases follow.

## F.2 configuration

- **F.2.a  A `dots doctor`** that runs the integration checks against the
  live `$HOME` (bash loads, vim loads, tmux parses, git includes resolve).
  Not built: `./run-tests.sh long` does it against a copy, and a broken
  live shell is noticed immediately.
- **F.2.b  zsh.**  Not planned; the author uses bash on every machine, and
  the module layout would have to be duplicated rather than shared.
- **F.2.c  Machine profiles** (a `~/.config/bash/profile` naming a set of
  knobs and disabled modules, e.g. `hpc`, `desktop`).  Not built: two
  files, `~/.bashrc.before` and `disabled`, already are the profile, and a
  third layer of indirection needs more than one machine class to justify
  it.
- **F.2.d  BSD/macOS aliases.**  The `ls`/`rm`/`ss` aliases assume GNU;
  only `CLICOLOR` is set otherwise.  Untested here (no such machine), so
  left as a known limit rather than a guess.
- **F.2.e  More tools in the catalog.**  Not shipped because nothing here
  uses them and each new file is one more link in every home: neovim
  (`~/.config/nvim/init.vim` sourcing `~/.vimrc` would need its own undo
  and swap directories, since vim's and neovim's files are incompatible),
  alacritty, wezterm, starship, psql, R, npm, lazygit, bat.  Add one as a
  file in the options format with a loader in `tests/test_options.py`.
  htop is not a candidate: it rewrites its own config on exit, which would
  rewrite the repository's file.
- **F.2.f  Per-machine opt-out of whole files.**  `.dotsignore` is
  committed, so a file you never want linked on one machine (the kitty
  config on a server) is still linked there; harmless, since a program that
  is not installed never reads it, and every setting in the four
  catalog-only files is off.  A `~/.config/dots/ignore` read by `dots`
  would fix it; not built until a file does harm somewhere.
- **F.2.g  Exercising settings, not just loading them.**  The switch-on
  test proves each setting loads; it does not prove an alias's program
  exists or a key binding does what its description says.  Doing that is
  one assertion per setting, by hand; the integration tests do it for the
  settings that are on by default.
- **F.2.h  A `cached` command for command output.**  `cached [-t TTL]
  [--refresh] -- CMD...` runs CMD once, stores its output and exit status
  under `~/.cache/cached/` keyed by a hash of the command line and `$PWD`,
  and replays them until TTL expires: slow cluster commands (`squeue`,
  `qstat`, `lfs quota`) and network calls, from any shell, script or cron.
  The toolkit's `prompt/toolkit/lib/cache.sh` is not this: it records only
  when a key was last refreshed, in one shell's memory, so nothing outside
  that shell sees it.  Promoting it to its own module, or moving it out of
  the toolkit subtree (which forks the toolkit, since `git_info.sh` sources
  it from its own directory), was considered and rejected.  Open before
  building: whether `$PWD` is part of the key, whether a failed run is
  replayed or rerun, pruning of the cache directory, and refusing commands
  that read stdin or need a tty.  About 30-40 lines of bash; it belongs in
  `linuxbin` as a standalone script rather than here as a function, since a
  function in `40-functions.sh` exists only in interactive shells.
- **F.2.i  `@cmd_time` counts the time spent at the prompt.**  The default
  `PROMPT_COMMAND` is `_title_prompt;prompt_build;_prompt_gap;history -a`.
  `prompt_build` arms the toolkit's timer, and the DEBUG trap fires for
  `_prompt_gap` while `PROMPT_COMMAND` is still running, so the start time
  is when the prompt was drawn (`prompt/toolkit/lib/cmd_timer.sh:50`).
  Wait 3.5 s, run `true`, and the next prompt shows `[✓] 3s`; the box
  layout shows `@cmd_time` on every prompt.  From the 2026-10-07 creview,
  ctesting and creadme reports (the description in `layout.sh` is right
  for the intended behavior).  Not fixed yet: the fix has more than one
  shape.  Either arm from an entry the toolkit appends at the very end of
  `PROMPT_COMMAND`, or ignore DEBUG while `PROMPT_COMMAND` runs; fixed in
  the toolkit subtree and split upstream, with a bats test there and a pty
  test here that idles before a fast command and expects no duration.  A
  local stopgap is to append `cmd_timer_arm` as the last `PROMPT_COMMAND`
  entry in `90-local.sh`.  What changes for a user: the shown durations get
  shorter and true.
- **F.2.q  `cat` runs bat when bat is installed.**  `rc.d/80-tools.sh:76`
  aliases `cat='bat --paging=never'`, against the module's own header
  (lines 3-5: a block that would change a familiar command is off).
  `cat -v`, `cat -e` and `cat -b` mean something else in bat, or do not
  exist, and on a terminal bat refuses binary files.  Reasoned from bat's
  option list; bat is not installed here.  From the 2026-10-08 creview.
  Future work because it changes what `cat` does for the owner.  Fix:
  comment the alias out with `Needs: bat`, keeping the `bat`/`batcat`
  alias, and move `cat`→bat to the off list of the `80-tools.sh` row in
  `docs/configuration.md`.
- **F.2.r  Completion scripts generated at every shell start.**
  `source <(kubectl completion bash)` (`rc.d/80-tools.sh:191`), `eval
  "$(gh completion -s bash)"` (199) and `eval "$(uv
  generate-shell-completion bash)"` (`75-python.sh:82`) each start the
  program in every interactive shell where it is installed; kubectl alone
  is about 50-100 ms.  `50-completion.sh:3-6` tells the reader to save
  such output into `completion.d/` once instead.  From the 2026-10-08
  creview.  Future work because there are two shapes: write the file into
  `completion.d/` on first run when it is missing (stale after an
  upgrade until deleted), or make the three lines off settings that point
  at the `completion.d` route (no completion until the user acts).
- **F.2.s  Opening a `/tmp` file switches viminfo off for the session.**
  `dot_vim/rc/40-files.vim:46` runs `setlocal viminfo=` for `/tmp/*`,
  `/dev/shm/*` and the secret patterns, but `viminfo` is global, so after
  bash's `fc` or `crontab -e` opens a file under `/tmp` the session saves
  no marks, history or registers on exit.  Checked: after `setlocal
  viminfo=` and `:enew`, `set viminfo?` prints `viminfo=`.  The comment
  says only "no viminfo for secrets and temporary files".  From the
  2026-10-08 creview.  Future work because there are two shapes for the
  temporary files: drop `viminfo=` from the `/tmp/*` and `/dev/shm/*`
  case, or keep their marks out with `set viminfo+=r/tmp,r/dev/shm`.  For
  the secret patterns the session-wide effect is the point (no register
  holding a secret is saved), and the comment should say so.
- **F.2.t  vim inside tmux gets no drag, wide clicks or focus events.**
  `dot_config/tmux/conf.d/00-options.conf:12` sets `default-terminal
  tmux-256color`; under that TERM vim 9.1 picks `ttymouse=xterm` (it picks
  `sgr` under `xterm-256color`) and leaves `t_fe` empty.  Checked in vim
  under that TERM.  So `mouse=a` drag and split resizing fail, clicks past
  column 223 are lost, tmux's `focus-events on` (line 30) does nothing for
  vim, and `FocusGained` checktime (`dot_vim/rc/00-general.vim:30`) and the
  statusline refresh (`15-statusline.vim:25`) never fire.  From the
  2026-10-08 settings creview.  Future work because it adds settings: when
  `&term =~ '^\(tmux\|screen\)'`, set `ttymouse=sgr`, `t_fe`/`t_fd` and the
  `<FocusGained>`/`<FocusLost>` key codes in `00-general.vim`.  vim in tmux
  then behaves as it does in xterm.
- **F.2.u  vim does not read `.editorconfig`.**  vim 9.0.1799+ ships
  editorconfig as an optional package, and nothing here runs `packadd`
  (`exists(':EditorConfigReload')` is 0); `dot_vim/rc/30-indent.vim:2` now
  says so.  `~/.editorconfig` is therefore dead for vim, and the
  strip-trailing-whitespace autocmd (`40-files.vim:68-71`) ignores a
  project's `trim_trailing_whitespace = false`.  From the 2026-10-08
  settings creview.  Future work because loading it changes how vim edits
  every file under `$HOME`: `[*]` in `dot_editorconfig:15-16` sets `charset
  = utf-8` and `end_of_line = lf`, so a latin-1 or CRLF file is rewritten
  whole on its next save.  Fix: `if has('patch-9.0.1799') | packadd!
  editorconfig | endif` in `30-indent.vim`, with `charset` and
  `end_of_line` moved out of `[*]` (or described), and the whitespace
  autocmd skipped when editorconfig set `trim_trailing_whitespace`.
- **F.2.v  `gdefault` is on.**  `dot_vim/rc/20-search.vim:25`.  vim's own
  help warns that it breaks plugins and inverts `/g`: a pasted or
  plugin-run `:s/a/b/g` replaces only the first match.  It changes
  existing behavior, against `CLAUDE.md`'s rule that new settings start
  off.  `50-keys.vim:214` (`<leader>rw`, `<leader>ri`) relies on it.  From the
  2026-10-08 settings creview.  Future work because it changes what `:s`
  does for the owner.  Fix: `#set gdefault`, and `/g` added to
  `<leader>rw` and `<leader>ri`.
- **F.2.y  `smartindent` sends `#` lines to column 0.**
  `dot_vim/rc/30-indent.vim:32`.  Checked: in `conf` buffers (ssh config,
  tmux.conf) `o#` lands at column 0; python, sh and yaml are unaffected,
  their indent plugins override it.  From the 2026-10-08 settings
  creview.  Future work because there are two shapes: drop `smartindent`
  (`autoindent` and filetype indent cover the rest), or keep it with
  `inoremap # X<C-h>#`.
- **F.2.z  `j`/`k` as `gj`/`gk` make counts move screen lines.**
  `dot_vim/rc/50-keys.vim:58`.  With `wrap` on, `5j` moves five screen
  lines, not five buffer lines, against the off `relativenumber`
  (`10-ui.vim:22`), which promises `5j` and `d3k` without counting.  From
  the 2026-10-08 settings creview.  Future work because it changes a
  movement key.  Fix: `nnoremap <expr> j v:count ? 'j' : 'gj'`, likewise
  `k`.

- **F.2.ab  `SYSTEMD_LESS="$LESS"` drops systemd's `-S` and `-K`.**
  `dot_config/bash/rc.d/00-env.sh:55`.  journalctl then wraps long lines
  and Ctrl-C no longer quits less.  From the 2026-10-08 settings creview.
  Future work because it changes how journalctl pages.  Fix:
  `SYSTEMD_LESS="$LESS -SK"`, with the description saying why.
- **F.2.ac  The toolkit's `prompt_build` guard misses `;prompt_build`.**
  `dot_config/bash/prompt/toolkit/prompt.sh:455` skips the prepend only
  when `PROMPT_COMMAND` starts with `prompt_build` or holds `;
  prompt_build`; a hook added in front with `;` and no space hides it, and
  a second `prompt_layout` adds `prompt_build` again.  `65-title.sh` was
  the one such hook here and now joins with `; ` (the 2026-10-08 settings
  creview's first finding, fixed with a guard on each prepend).  Fix: also
  match `*';prompt_build'*`, with a bats test, in its own commit sent
  upstream.
- **F.2.ad  No post-push hook.**  git has no event after a push completes:
  a push fires only `pre-push` and, on the local side, the
  `reference-transaction` hook for the remote-tracking refs.  That hook
  also fires on every fetch, pull, branch and commit, so a "post-push"
  built on it would need to tell them apart from its input alone, and
  would guess.  An action after a push stays a wrapper (`git ps && ...`).
  `git hooks -h` says so too.
- **F.2.ae  Repositories made from the git template depend on the
  checkout's path.**  `dots` links each file of
  `~/.config/git/template/hooks/` to the source tree by absolute path, and
  `git init` copies a symlink as it is, so `.git/hooks/EVENT` in a new
  repository points into `.../dotfiles/dot_config/git/template/`, while
  `git hooks install` links through `~/.local/share/git-hooks`.  Move the
  checkout and every repository made from the template has dangling hooks,
  which git skips without a word; `dots apply` repairs the home links, not
  those.  Only once `init.templateDir` in `core.gitconfig` is switched on.
  From the 2026-10-10 creview.  Future work because the fix has more than
  one shape: a sentence in the template row of `configuration.md`, or a
  template whose hooks resolve through `~/.local/share/git-hooks` (which
  `dots` cannot produce: it links every file to its source).
- **F.2.aj  `:` instead of ` -- ` between a name and its description.**
  From the owner's TODOs of 2026-10-12: shorter, and the owner's house
  rule T4 says the same.  The ` -- ` form is the convention everywhere: the
  first line of every module and hook (`# 10-options.sh -- ...`, which
  `tests/test_docs.py` checks) and each function's `# NAME ARGS -- ...`
  line, about 175 lines in 70 files.  One mechanical commit, with the
  `test_docs.py` pattern and `docs/contributing.md` changed with it.
- **F.2.ak  What is an alias, a function, or a program on PATH.**  From
  the owner's TODOs of 2026-10-12; the TODO's sentence stops at "to ensure
  we always".  The rule proposed: an alias when the words only go in front
  of the arguments; a function when the arguments land in the middle, or
  it must change the shell itself (cd, variables, history, traps); a
  script in `~/.local/bin` otherwise, since a script also works from
  `xargs`, `find -exec`, vim's `:!`, cron and other shells, and costs no
  startup time.  Then a pass over `30-aliases.sh` and `40-functions.sh`
  sorting each name by it.
- **F.2.ao  Batch and CI jobs read the login files.**  From the owner's
  TODOs of 2026-10-12 (`50-completion.sh`): a PBS, Slurm, GitLab or
  GitHub job should run the same for everyone, so it should not read this
  configuration.  `~/.bashrc` already stops at once in a shell that is not
  interactive (`dot_bashrc`, `case $- in *i*`), so `rc.d/` never loads in a
  job.  What does load is the login part: a PBS job script runs in a login
  shell, as does GitLab's shell executor (`bash --login`), and that reads
  `~/.bash_profile`, so `~/.profile` (PATH, locale) and every
  `profile.d/*.sh`; at logout `~/.bash_logout` runs `clear_console` when
  `SHLVL` is 1, the known cause of GitLab's "prepare environment: exit
  status 1".  Slurm's `sbatch` runs `#!/bin/bash` as no login shell (only
  `#!/bin/bash -l` reads the files) but copies the submitting shell's whole
  environment, which `#SBATCH --export=NONE` stops, not a dotfile.  GitHub
  Actions runs `bash --noprofile --norc`, so reads nothing.  Proposed: an
  off setting at the top of `~/.bash_profile` and `~/.profile`, and the
  same test in `~/.bash_logout`, returning when the shell is not
  interactive and `PBS_JOBID`, `SLURM_JOB_ID`, `GITLAB_CI` or
  `GITHUB_ACTIONS` is set.  Interactive jobs (`qsub -I`, `srun --pty
  bash`) keep the whole configuration.  What goes: a job script that
  counted on `~/.local/bin` or a conda path from `~/.profile` must set PATH
  itself.  About 6 lines in 3 files, a test per variable.
- **F.2.ap  Read-only variables a system file sets.**  From the owner's
  TODOs of 2026-10-12, with `TIMEOUT` as the example, most likely `TMOUT`:
  clusters set it in `/etc/profile` and mark it read-only, so the shell
  logs out when idle.  Bash cannot unset or change a read-only variable in
  the shell that has it, and the attribute is not inherited: a new bash
  gets the plain value, or none when it was not exported.  The one way
  without a debugger is to replace the shell: a knob
  `DOTFILES_UNSET_READONLY="TMOUT ..."` read at the top of
  `~/.bash_profile`, and when one of those names is read-only there,
  `exec env -u NAME... bash -i` (not `-l`, which would read `/etc/profile`
  and set it again), with a variable in the environment so the new shell
  never does it twice.  What goes: that shell is not a login shell
  (`logout` refuses, use `exit`; `shopt login_shell` is off), the
  `/etc/profile` part already ran so nothing else is lost, and startup
  forks one more bash on those machines only.  It does not help when the
  system sets it in `/etc/bash.bashrc`, which every interactive bash
  reads.  About 10 lines in `dot_bash_profile`, a knob row, a test with a
  read-only variable.
- **F.2.aq  A tmux pane keeps the DISPLAY of the ssh login that made
  it.**  From the owner's TODOs of 2026-10-12.  On attach, tmux copies
  `DISPLAY`, `SSH_AUTH_SOCK`, `XAUTHORITY` and the other names in its
  default `update-environment` into the session, which only panes made
  afterwards see; shells already running keep the old values, so X
  programs started there fail.  ssh X11 forwarding adds the new display's
  cookie to the same `~/.Xauthority`, so `XAUTHORITY` rarely changes;
  `DISPLAY` and `SSH_AUTH_SOCK` do.  Proposed: a tmux hook on
  `client-attached` touching a stamp file, and a `PROMPT_COMMAND` function
  that, when the stamp is newer than its last look (a `-nt` test, no
  fork), runs `eval "$(tmux show-environment -s)"` for those names, so
  every shell picks them up at its next prompt.  Programs already running
  (an open vim) keep the old values.  Asking tmux at every prompt instead
  would cost a fork each.  An off setting in a new `rc.d` module and one
  in `conf.d`, about 15 lines, a test that attaches with a new DISPLAY.

## F.3 tests

- **F.3.a  mutmut or cosmic-ray** instead of the hand-written mutant list,
  if either becomes available on the machines this runs on.  The list
  stays either way as the documented minimum.
- **F.3.b  Visual check of the prompt** (render `PS1` through bash and
  compare a golden frame).  The toolkit's bats suite covers it;
  here only "each layout builds" is asserted.
- **F.3.c  A gate on shell startup time.**  Every new terminal pays for
  `~/.bashrc`, and nothing fails when a module adds 200 ms.  Measured on
  2026-10-07 in a throwaway home: `bash -i -c exit` 70-76 ms over 7 runs,
  median 72 ms.  Fix: a `perf` command in `run-tests.sh` that times 15
  starts in a temporary linked home and fails above a baseline median
  stored in `.build/` plus 25%, with the baseline and machine recorded in
  `docs/testing.md`.  From the 2026-10-07 ctesting audit.  Future work
  because it is a new gate with a threshold to choose, and a timing gate
  is noisy on a shared login node.  The 2026-10-08 ctesting audit asks
  for a second median in the same gate: `prompt_build` in a git
  repository with a warm cache, which the toolkit's v0.1.9 cache work
  brought from about 6 ms to 0.3 ms.
- **F.3.d  Mutation of the shell code.**  `./run-tests.sh mutate` covers
  `dots` only.  The bash modules carry branches the long suite asserts
  (`_venv_auto`, `_title_arm`, the `20-path.sh` helpers, `bd`, `swap`,
  `extract`) and so does the toolkit's git cache (`lib/git_info.sh`,
  mutated by hand on 2026-10-08: 9 mutants, all caught after three tests
  were added), but nothing re-runs those mutants.  From the 2026-10-08
  ctesting audit.  Fix: a second list, `FILE ||| find ||| with` per line,
  driven through `breaks-it` by `mutate`, whose test command is the long
  subset that loads the file, or `bats` for a toolkit file.  Future work
  because it is a new gate, and each mutant costs a long-suite subset
  (seconds, not the fast suite's milliseconds).  The 2026-10-10 ctesting
  audit adds `git-hooks` (`ensure_dispatch`, `tidy`, `switch`, `on_now`),
  the dispatcher's pre- against post- status rule and `HOOKS_SKIP`
  matching, and the 18 packaged hooks, whose tests are in the long
  `test_git_hooks.py`.
- **F.3.e  A toolkit test file named for a release.**
  `prompt/toolkit/tests/test_v012_changes.bats` holds 31 tests of features
  from v0.1.2 to v0.1.4 (cache, command timer, `term_utils`, `_ps_expand`,
  collectors, `pbs_nodes`), whose subjects mostly have files already; a
  reader looking for a feature's tests has to know which release added
  it.  From the 2026-10-08 ctesting audit.  Future work because the move
  has more than one shape: the cache and timer tests have no file to go
  to, and moving a test that sources one library into a file whose
  `setup` loads them all changes what it isolates.  A toolkit-only commit
  either way, with the README's test table updated.
- **F.3.f  `tests/hooks/pre-push` is a second copy of the packaged
  `test-push` hook.**  Both unset the git variables, check out each pushed
  tip in a temporary worktree, run the tests there and stop the push on a
  failure; the repository's copy also skips a commit that lacks the file.
  A fix to one has to be made in the other.  And `./run-tests.sh hook`
  (`run-tests.sh:63`) links `.git/hooks/pre-push.off` beside whatever is
  at `.git/hooks/pre-push`: once `git hooks install` has put the
  dispatcher there, the `git hooks on pre-push` it advises stops with
  `git hooks: both .../pre-push and .../pre-push.off exist; remove one`.
  From the 2026-10-10 creview.  Future work because either fix changes a
  runner command and a documented path, and which hook to run is the
  owner's call.  Fix: drop `tests/hooks/pre-push` and `hook`, and document
  `git config hooks.test "./run-tests.sh fast"` with
  `git hooks install test-push`; or keep `hook` and link into
  `pre-push.d/pre-push.off` when the dispatcher owns the event.
- **F.3.g  Push hooks are tested only against a named remote.**
  `protect`, `wip-guard` and `test-push` take the remote from `$1`, which
  is the URL when a push names one.  `wip-guard` then builds
  `--remotes=URL`, which matches no ref, so a new branch has every commit
  in its history checked, not only the unpushed ones.  No test pushes to a
  URL.  From the 2026-10-10 ctesting audit.  Future work because the test
  would fail today on what may be a defect: whether a URL push should fall
  back to every remote-tracking branch (`--remotes`) is a design call.

## F.4 housekeeping

Things done by hand outside the repository, moved from the 2026-09-20
handoff.

- **F.4.a  Publishing.**  There is no remote.  The other projects are
  under `github.com/PickledPenguins/`; whether this one goes there is not
  decided.
- **F.4.b  `~/.gitignore`.**  The old `~/env/.gitconfig` set
  `excludesfile = ~/.gitignore`; this set uses `~/.config/git/ignore`,
  which already holds that file's one line
  (`**/.claude/settings.local.json`).  The set is live, so `~/.gitignore`
  can go; not checked whether anything else reads it.
- **F.4.c  `~/env/` and `~/.bash_aliases`.**  The old configuration, kept
  as a backup.  `~/.bash_aliases -> env/.bash_aliases` is still in `$HOME`
  and nothing sources it.  Both can go once nothing from them is missed.
- **F.4.d  ssh hosts that relied on agent-offered keys.**
  `IdentitiesOnly yes` in `~/.ssh/config` offers only keys named by
  `IdentityFile`; a host that worked with any agent key needs an
  `IdentityFile` line in `~/.ssh/config.local`.  Not checked against the
  owner's hosts.
- **F.4.e  Agent files and generated paths in the root.**  The
  workspace layout standard puts `CLAUDE.md` in `.claude/`, `HANDOFF.md`
  and `reviews/` in `.agent/`, and the test runner under `tests/`.  Here
  they sit in the root, as this repository's `CLAUDE.md` lists them.  From
  the 2026-10-07 creview (the `.benchmarks/` half was fixed:
  `run-tests.sh` passes `-p no:benchmark`).  Future work because each move
  changes a documented path: `.dotsignore`, the `CLAUDE.md` root list,
  `docs/testing.md` and the pre-push hook all name `run-tests.sh` and
  `reviews/`.  `dots` stays in the root, since `dot_local/bin/dots` and the
  README use `~/.dotfiles/dots`.
