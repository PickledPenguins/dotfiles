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
  `~/.dotfiles` belongs to another tool the command `install.sh` linked
  manages that other tree.  `docs/cli.md` documents the order, so this is
  a trap rather than a misdescription; the README's install line ("a
  machine where the repository lives elsewhere") reads as if the linked
  command used its own checkout.  From the 2026-10-07 creview.  Future work
  because the fix is a design call with two shapes: prefer the directory
  holding `dots` when it contains `.dotsignore` (changes which tree a
  plain `dots` uses from a second checkout), or have `install.sh` print the
  source tree the command will use (changes nothing at run time).  Either
  way `docs/cli.md`'s `--source` row and the catalog cases follow.

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
  `PROMPT_COMMAND` is `_title_prompt;prompt_build;history -a`.
  `prompt_build` arms the toolkit's timer, and the DEBUG trap fires for
  `history -a` while `PROMPT_COMMAND` is still running, so the start time
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
- **F.2.j  Empty rows in the default box outside a repository.**  The
  `git` row in `prompt/layout.sh:139` puts literal `⎇` and `→` around
  segments that print nothing outside git, and the toolkit never drops a
  row whose segments are all empty: a plain directory shows `│  ⎇    →  │`,
  a blank `status` row, and on a workstation a blank `env` row.  From the
  2026-10-07 creview of the toolkit.  Future work because it is a design
  call: either the toolkit skips a row when every segment in it printed
  nothing (a toolkit change, sent upstream, that changes every layout
  using it), or the glyphs move into the git segments (changes what
  `@git_branch` and `@git_remote` print).  What changes for a user: two or
  three fewer rows on every prompt outside git.
- **F.2.k  Two spaces before `$` when `@cmd_time` is empty.**  The `cmd`
  row (`prompt/layout.sh:148`, `'─[@exit] @cmd_time \$ '`) and `line2`
  render `─[✓]  $` on most prompts.  From the 2026-10-07 creview of the
  toolkit.  Future work because it changes what the prompt shows.  Fix:
  drop the space after `@cmd_time` in both rows and have a `layout.sh`
  segment wrap the toolkit's `@cmd_time` with a trailing space when it
  prints anything (as `_my_user_host` wraps `@user_host`).
- **F.2.l  The repository root on `PATH`.**  `rc.d/20-path.sh:34`
  (`path_append "$DOTFILES_DIR"`) makes `dots` a command and also every
  root script: `run-tests.sh` typed without `./` in another project runs
  this suite (the owner's other projects use the same name), and
  `install.sh` anywhere runs this one.  Since `install.sh` links
  `~/.local/bin/dots`, which `20-path.sh` already puts first, the line is
  no longer needed for `dots`.  From the 2026-10-07 creview.  Future work
  because it removes a `PATH` entry existing machines rely on until
  `install.sh` has run there.  Fix: drop the line, have the README's
  install section say `install.sh` runs once per machine, and update the
  `20-path.sh` row in `docs/configuration.md`.
- **F.2.m  `merge.conflictStyle = zdiff3` on old git.**  The value needs
  git 2.35 (`dot_config/git/core.gitconfig`, now with a `Needs:` line);
  older git (Ubuntu 20.04 has 2.25, RHEL 7 1.8) rejects it and merge,
  rebase, pull and `checkout -m` die on the config.  Not reproduced: only
  current git is installed here.  From the 2026-10-07 creview.  Future
  work because the choice trades the better markers on new git against
  working on old machines: `diff3` works everywhere and shows the same
  three sections with less trimming; keeping `zdiff3` and putting
  `conflictStyle = diff3` in `~/.gitconfig.local` on an old machine works
  too, and is what the `Needs:` line now tells the reader.

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
  is noisy on a shared login node.

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
  `docs/testing.md` and the pre-commit hook all name `run-tests.sh` and
  `reviews/`.  `dots` stays in the root, since `install.sh` and the README
  use `~/.dotfiles/dots`.
