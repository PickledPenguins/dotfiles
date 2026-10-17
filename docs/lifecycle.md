# Lifecycle

What happens in what order. Back to the [README](../README.md).

## `dots apply`

1. **Resolve the source tree**: `-S DIR`, else `$DOTS_SOURCE`, else the
   directory holding the `dots` script when it has a `.dotsignore`, else
   `~/.dotfiles` (symlinks resolved), else the script's directory. A source
   that does not exist stops here with exit 2.
2. **Read `.dotsignore`** from the source root. Unreadable is a hard error
   (a traceback), not a silent apply of everything.
3. **Walk the source tree**, skipping directories whose name starts with
   `.` at every depth and such files in the root only (a deeper one, like
   `private_dot_ssh/sockets/.keep`, is managed), dropping ignored targets,
   and refusing any entry whose target would
   have an empty, `.` or `..` component (a file named just `dot_` would map
   to `~` itself) with a warning on stderr. Entries are sorted by target.
4. **Restrict to the paths given**, if any: only targets equal to or below
   them.
5. For each entry, **classify the target** (`ok`, `missing`, `stale-link`,
   `conflict`) and act:
   - `ok`: re-assert the modes (`private_`, `executable_`); nothing printed.
   - `missing`: create the parent directories, symlink, set modes; `link`.
   - `stale-link`: remove the old link, symlink; `relink`.
   - `conflict` without `--force`: print `conflict` and count it.
   - `conflict` with `--force`: move the target into
     `~/.dotfiles-backup/<timestamp>/<home-relative path>` (`backup`), then
     symlink; `replace`.
   With `-n`/`--dry-run` the verbs are printed and nothing is written.
6. **Summarize**: `N change(s)`, plus `, M conflict(s) left` when any were
   refused -- and then the exit status is 1.

Nothing is deleted at any step: a conflict is moved, never removed; a
stale link is replaced by a link to the same source tree; `unlink` removes
only links whose state is `ok`.

## `dots add`, `dots forget`

- `add FILE`: the path is made absolute lexically (`..` collapsed, symlinks
  not followed) and must be a regular file under `$HOME` that is not a
  symlink and whose source name is free. The file is **moved** into the
  source tree under its attribute name (`private_` when it has no
  permission bits for others or `--private` was given, `executable_` when
  the owner can execute it) and a symlink is left behind. Order of the
  arguments is the order of the moves.
- `forget FILE`: if the target is our link, a stale link or missing, a
  **copy** of the source file is put there (private directories made with
  mode 700); then the source file is removed. A target in conflict is left
  alone and the source file is **moved** into the backup tree, so neither
  file is lost. A target reached through a directory link into the
  source is the source file itself and is refused. Unmanaged and refused
  paths are reported and give exit 1.

## `dots prune`

Collects the symlinks directly in `$HOME` plus every symlink under each
top-level directory that contains a managed target (walking without
following links), and removes those whose link text starts with the
source tree path and whose referent does not exist. Everything else --
valid links, broken links elsewhere, files -- is untouched.

## A bash shell

1. bash reads `~/.bash_profile` (login) or `~/.bashrc` (interactive
   non-login). `~/.bash_profile` sources `~/.profile` (PATH and locale, in
   POSIX sh), then `~/.config/bash/profile.d/*.sh` if the directory exists,
   then `~/.bashrc`; last, when `95-override.sh` found a read-only variable
   listed in `DOTFILES_OVERRIDE`, the shell swap it deferred to here.
2. `~/.bashrc` returns immediately for a non-interactive shell.
3. It sets `DOTFILES_BASH_DIR` (`~/.config/bash`) and exports `DOTFILES_DIR`
   (the source tree, found by resolving `~/.bashrc` itself).
4. It sources **`~/.bashrc.before`** if present -- this is where knobs go.
5. It sources `rc.d/*.sh` in name order, skipping any whose module name is
   in **`~/.config/bash/disabled`** (`.off` files are not matched by the
   glob at all). With `DOTFILES_DEBUG=1` each module's name and load time
   go to stderr.
6. `90-local.sh` sources **`~/.bashrc.local`** if present; then
   `95-override.sh`, the last module, sets and unsets the variables listed
   in `DOTFILES_OVERRIDE` (replacing the shell when one is read-only, or
   in a login shell leaving that to `~/.bash_profile`).
7. On each prompt, `PROMPT_COMMAND` runs. Each module prepends its entry,
   so the later module runs earlier:
   `_title_prompt;prompt_build;_prompt_gap;history -a` by default, with
   `_venv_auto` (`75-python`, when enabled) first of all. `_prompt_gap`
   (`prompt/layout.sh`) goes in right after `prompt_build` and puts a blank
   line above the prompt it built.
   Anything ahead of `prompt_build` must return the `$?` it found, since
   the prompt shows that status.

## vim

`~/.vimrc`: `set nocompatible`, source `~/.vimrc.before` if present, source
`~/.vim/rc/*.vim` in sorted order (recording each in `g:dotfiles_modules`),
source `~/.vimrc.local` if present, define `:DotfilesModules`.
`40-files.vim` creates `~/.vim/tmp/{swap,backup,undo}` on first load.

## tmux

`~/.tmux.conf`: `source-file -q ~/.config/tmux/conf.d/*.conf` (glob, sorted
by tmux), then `source-file -q ~/.tmux.conf.local`. `-q` means a missing
file is not an error. `prefix r` re-reads the whole chain.

## git

`~/.gitconfig` is only `[include]` lines, read in order: `core`, `color`,
`aliases`, `diff`, `url`, (`signing`, commented out), then
`~/.gitconfig.local`. Later files override earlier keys, so identity and
per-machine overrides in the local file win. `~/.config/git/ignore` and
`~/.config/git/attributes` are read by git without any setting.

## ssh

`~/.ssh/config` starts with `Include ~/.ssh/config.local` and
`Include ~/.ssh/config.d/*`, then `Host *` defaults. ssh takes the first
value it finds for each option, so a `Host` block in the local file wins.

`IdentitiesOnly yes` offers a host only the keys its `IdentityFile` lines
name, or the default files (`~/.ssh/id_ed25519`, `~/.ssh/id_rsa` ...) when
there are none, never any other key the agent holds. A host that worked
with such a key fails with `Permission denied (publickey)`.
`ssh -v HOST` lists each key offered, `ssh-add -l` what the agent holds and
`ssh -G HOST | grep identityfile` the files ssh will try. The fixes, in
`~/.ssh/config.local`:

```
# One host: name its key.
Host work
    IdentityFile ~/.ssh/id_ed25519_work

# A key only in the agent (forwarded, gpg-agent, a hardware token):
# save its public half once, then name that.
#   ssh-add -L | grep COMMENT > ~/.ssh/agent_key.pub
Host work
    IdentityFile ~/.ssh/agent_key.pub

# Every agent key for every host, on this machine.
Host *
    IdentitiesOnly no
```
