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
  it becomes a `private_` decision in git history.
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

## F.3 tests

- **F.3.a  mutmut or cosmic-ray** instead of the hand-written mutant list,
  if either becomes available on the machines this runs on.  The list
  stays either way as the documented minimum.
- **F.3.b  Visual check of the prompt** (render `PS1` through bash and
  compare a golden frame).  Upstream's bats suite covers the toolkit;
  here only "each layout builds" is asserted.
