# Git tools

The `git` subcommands `dots apply` links into `~/.local/bin`, beside
`git hooks` and `git ctags` ([configuration.md](configuration.md#packaged-git-hooks-localsharegit-hooks)).
git runs `~/.local/bin/git-NAME` for `git NAME`. Back to the
[README](../README.md).

Each one prints its help with `git NAME -h` (git turns `git NAME --help`
into `git help NAME`, which looks for a manual page), exits 2 on a usage
error with a one-line message, and 1 when it refuses or what it runs
fails. None of them changes the work tree unless that is what it is for,
and none discards work: what they replace is first kept somewhere they
name. Tab completes their subcommands and options (`50-completion.sh`).
They need git 2.30 or newer; `git scrub`, `git resolve` and
`git absorb` are python3 (stdlib only), the rest bash.

| Command | Does |
|---------|------|
| [`git scrub`](#git-scrub-rewrite-history) | rewrite every branch and tag to drop paths, message lines and words |
| [`git rd`, `git rdu`](#git-rd-and-git-rdu-compare-two-versions-of-a-series) | aliases for `range-diff` |

## `git scrub`: rewrite history

```sh
git scrub --path '^secrets/' --trailer '^Signed-off-by:' --dry-run
git scrub --path '^secrets/' --path '\.pem$' --trailer '^Signed-off-by:'
git scrub --words words.txt --messages messages.txt
```

Rewrites every branch and tag (`--branches --tags`) in one pass, dropping
commits left empty:

| Option | Removes |
|--------|---------|
| `--path RE` | every path the Python regular expression matches, searched in the path from the top of the repository; repeatable |
| `--trailer RE` | every message line it matches (trailing blank lines go too); repeatable |
| `--messages FILE` | whole messages: lines `COMMIT<TAB>MESSAGE-FILE`, `COMMIT` a hash or prefix as `git log --oneline` shows it before the rewrite, on a branch or tag; `MESSAGE-FILE`, relative to `FILE`'s directory, holds the new message |
| `--words FILE` | words in messages: lines `OLD NEW` (`#` starts a comment); `OLD` is one word, matched whole in any case, `NEW` the rest of the line, in the case of the match (`widget` to `gadget`, `Widget` to `Gadget`). A match in capitals (`WIDGET`) stays, as an acronym or constant |
| `--dry-run` | nothing: prints how many commits change, each dropped path with the commits that touch it, and each message line removed or added |

Replacements apply first, then trailers, then words. Before rewriting it
refuses tracked changes, other worktrees and a leftover `refs/original`,
then writes a backup to `--backup DIR` (a new directory; default
`REPO.scrub/TIMESTAMP` beside the repository): `all-refs.bundle` with
every ref, `refs.txt`, and `remote-refs.txt`, the remote-tracking refs.

It rewrites with `git filter-repo` when that is on `PATH`, otherwise with
`git filter-branch` (index filter, message filter, `--prune-empty`, tags
moved); `--filter-branch` forces the second. One difference: with
`--path`, `git filter-branch` also drops commits that were empty before
the rewrite; `git filter-repo` keeps them. Branches and tags are
repointed, the checked-out branch too, and the work tree follows; a
dropped file that was in the work tree stays there, untracked. Then it
checks each rewritten tip against the old one: their trees may differ
only in dropped paths, and no dropped path or deleted line may be left
anywhere. It prints `old -> new` for each ref that moved and the commands
to run yourself:

```
refs/heads/main  3a55feabdedd -> 6a49fa1cf6db
to publish the rewrite (run these yourself):
  git push --force-with-lease=refs/heads/main:3a55feabdedd... origin refs/heads/main:refs/heads/main
old objects stay here until: git reflog expire --expire=now --all && git gc --prune=now
```

A branch is pushed with a lease on its remote-tracking ref, so the push
fails if the remote moved since the last fetch; a tag with a lease on its
old value, on every remote. Annotated tag messages, the stash and the
remote-tracking refs are not rewritten. If a check fails, `git scrub`
exits 1 and prints the command that restores every ref from the bundle.

## `git rd` and `git rdu`: compare two versions of a series

`git rd A B` is `git range-diff A B`: each commit of one version paired
with its counterpart in the other, and how they differ, as after a
rebase, an amend or a `git scrub`. `git rdu` compares the commits here
with the upstream's since they forked (`@{upstream}...HEAD`).
