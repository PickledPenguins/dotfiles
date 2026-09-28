# Usage

Workflows past the quick start.  Every sequence here is a case in
`tests/examples/` and runs in the long suite.  Back to the
[README](../README.md).

## A machine that already has dotfiles

`tests/examples/complex/01-fresh-machine-bootstrap`

```sh
git clone <repo> ~/.dotfiles
cd ~/.dotfiles
./dots status | grep -v '^missing'      # what is in the way
./dots apply                            # links everything it can, exit 1 for the rest
grep -A2 '^\[user\]' ~/.gitconfig > ~/.gitconfig.local    # keep the identity
./dots apply --force                    # the rest, originals to ~/.dotfiles-backup/<ts>/
./dots status                           # ok: N
exec bash
```

The backup tree keeps home-relative paths, so `diff -r ~/.dotfiles-backup/*/ ~` shows
what the old files had that the new ones do not.

## Importing a home directory into a new repository

`tests/examples/complex/02-migrate-a-home-into-a-new-source`

```sh
mkdir ~/.dotfiles && git -C ~/.dotfiles init
dots add ~/.bashrc ~/.vimrc ~/.config/git/config ~/.ssh/config ~/.local/bin/hi
git -C ~/.dotfiles add -A && git -C ~/.dotfiles commit -m "import home"
dots forget ~/.netrc                    # second thoughts: back to a plain file
```

`add` takes files, not directories; for a whole tree:
`find ~/.config/app -type f | xargs dots add`.  Modes decide the prefixes:
600 files become `private_`, executables `executable_`.  Check with
`dots managed --show-source` before committing.

## Trying one tool's configuration first

`tests/examples/moderate/03-apply-subset-by-path`

```sh
dots apply ~/.config/tmux ~/.tmux.conf
dots status ~/.config/tmux              # ok: N
dots unlink ~/.config/tmux ~/.tmux.conf # and back
```

## Finding and switching one setting

Every setting is in a file with its description above it, and one that is
off has its comment character directly in front
([the options format](configuration.md#the-options-format)).  Find it,
then add or delete that one character:

```sh
dots options history                  # every setting that mentions history
dots options --off vim                # what the vim files offer that is off
dots options -f histverify            # one setting in full, with its code
vim +57 ~/.config/bash/rc.d/10-options.sh    # delete the # in front
```

For one machine only, leave the module alone and put the setting's line,
switched on, in `~/.bashrc.local` (or `~/.vimrc.local`,
`~/.tmux.conf.local`, `~/.gitconfig.local`); a setting that is on is undone
there with its opposite (`unalias rm cp mv`, `shopt -u autocd`,
`set nonumber`).

## Turning things off

Whole modules, most to least permanent (`docs/configuration.md` has the
tables):

```sh
git mv ~/.dotfiles/dot_config/bash/rc.d/70-conda.sh{,.off}   # everywhere, committed
echo conda >> ~/.config/bash/disabled                          # this machine only
printf 'unalias rm cp mv\n' >> ~/.bashrc.local                 # one setting, this machine
```

Vim: rename `~/.vim/rc/NN-name.vim` to `.vim.off`.  tmux: rename
`NN-name.conf` to `.conf.off`.  git: put `#` in front of the `path =` line
in `~/.gitconfig`.

## Per-machine settings, all at once

`tests/examples/complex/04-per-machine-customization`

```sh
cat > ~/.bashrc.before <<'EOF'
DOTFILES_PROMPT_LAYOUT=minimal
DOTFILES_PATH_PREPEND=$HOME/tools
EOF
printf 'conda\nhpc\n' > ~/.config/bash/disabled
echo "alias ll='ls -la'" > ~/.bashrc.local
echo 'let g:dotfiles_indent = 4' > ~/.vimrc.before
echo 'set -g history-limit 7' > ~/.tmux.conf.local
printf '[user]\n\tname = Me\n\temail = me@example.com\n' > ~/.gitconfig.local
```

None of these files is managed or committed.

## Seeing why a shell is slow

```sh
DOTFILES_DEBUG=1 bash -i -c true
```

prints each module with its load time.  `conda` used to cost 1.2 s per
shell through `conda shell.bash hook`; the module sources `conda.sh`
directly (8 ms).  `completion` at ~40 ms is bash-completion itself.

## Reorganizing the source tree

`tests/examples/complex/03-reorganize-the-source-tree`

Renaming a file to change an attribute (`git mv dot_bashrc private_dot_bashrc`)
keeps the target; `apply` reports `relink` and tightens the mode.  Moving a
directory or deleting a file changes or removes targets: `apply` links the
new ones, and the old links in `$HOME` are left dangling because they are
no longer targets.  `dots prune -n` lists them, `dots prune` removes them;
only broken links into the source tree qualify.

## In scripts

`apply` exits 1 while conflicts remain, so `dots apply && exec bash` stops
on a half-applied home; `status` exits 1 when anything is not `ok`, which
makes it a cheap check in a login script or a cron job:

```sh
dots status >/dev/null || echo "dotfiles out of date on $(hostname)"
```

## Troubleshooting

Each of these is a case in `tests/examples/failures/`, with the exact text.

| You see | Cause | Do |
|---------|-------|----|
| `conflict  .bashrc  (use --force to back it up and replace)`, exit 1 | a real file or a foreign symlink at the target | `dots apply --force`; the original goes to `~/.dotfiles-backup/<ts>/` |
| `skip      /x/y: not under /home/you` | `add` of a path outside `$HOME` (including via `..`) | only files under `$HOME` can be managed |
| `skip      .config/app: not a regular file (add files, not directories)` | `add` of a directory | name the files: `find DIR -type f \| xargs dots add` |
| `skip      .bashrc: already a symlink` | `add` of something already linked | nothing to do, or `forget` first if it is a foreign link |
| `skip      /home/you/.nothing: not managed`, exit 1 | `forget` of a path dots does not manage | check `dots managed` |
| `dots: source directory /x does not exist`, exit 2 | `-S` or `$DOTS_SOURCE` wrong, or `~/.dotfiles` missing | fix the path or clone the repository |
| `dots: ignoring dot_: maps to '.'` on stderr | a source file named only by a prefix | rename it; it would target `~` itself |
| `dots: error: the following arguments are required: cmd`, exit 2 | no subcommand | `dots --help` |
| `PermissionError: ... '.dotsignore'`, exit 1 | unreadable ignore file | `chmod 644 .dotsignore`; dots never guesses the ignore list |
| a `~/.config/app/x` link pointing nowhere | the source was moved or deleted | `dots prune` |
