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
| [`git each`](#git-each-run-a-command-at-each-commit) | run a command at each commit of a range, in a temporary worktree |
| [`git wt`](#git-wt-a-worktree-per-branch) | one worktree per branch beside the repository; `cdw` goes there |
| [`git resolve`](#git-resolve-one-conflict-at-a-time) | list, show and resolve merge conflicts a file or a conflict at a time |
| [`git absorb`](#git-absorb-staged-fixes-into-fixup-commits) | staged fixes into `fixup!` commits for the commits they fix |
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

## `git each`: run a command at each commit

```sh
git each -- make test                     # each commit not yet pushed
git each -k main..topic -- sh -c 'make && make check'
```

Checks out each commit of the range (default `@{upstream}..HEAD`), oldest
first, in a worktree of its own under `$TMPDIR`, cleans it with
`git clean -ffdx`, and runs the command there, in the subdirectory you
started from when that commit has it. One line per commit; a failed
commit's output follows its line, indented:

```
3f2a1c9  PASS  Add the parser
8d01b7e  FAIL  Use the parser
    test_parser.py::test_empty FAILED
```

It stops at the first failure unless `-k`. The command is a program and
its arguments; shell code goes through `sh -c`. Your work tree, index and
stash are not touched, hooks do not run in the temporary worktree, and the
worktree is removed at the end, also when interrupted. Exit 1 when the
command failed at any commit, or when the range is empty or bad.

## `git wt`: a worktree per branch

| Command | Does |
|---------|------|
| `git wt new BRANCH [BASE]` | a worktree on `BRANCH` at `REPO.wt/BRANCH`, its path printed; a new `BRANCH` starts at `BASE`, or else at the one remote branch of that name (tracking it), or else at `HEAD` |
| `git wt ls` | each worktree: branch, `clean` or `N changed` (untracked files count), `+ahead -behind` its upstream (`-` without one), path |
| `git wt rm [-f] BRANCH` | remove `BRANCH`'s worktree, then `git worktree prune` and the directories left empty; git refuses changed or untracked files unless `-f`; the branch stays |
| `git wt cd [BRANCH]` | print the path of `BRANCH`'s worktree, or of the main one |

`REPO` is the main worktree's directory: the worktrees of `~/src/app` are
under `~/src/app.wt/`, beside it, so tools that search upward from a
worktree do not find the main repository around it. A program cannot
change its caller's directory, so the shell function `cdw [BRANCH]`
(`40-functions.sh`) does `cd "$(git wt cd BRANCH)"`. Tab completes
branch names after `new`, and the branches in a worktree after `rm` and
`cd`.

## `git resolve`: one conflict at a time

During a merge, rebase, cherry-pick or revert that stopped on conflicts:

| Command | Does |
|---------|------|
| `git resolve list` | each conflicted file, its state (`both modified`, `deleted by us` ...) and how many conflicts it has |
| `git resolve show FILE[:N,...]...` | each conflict with ours, base and theirs side by side, cut to the terminal's width |
| `git resolve ours FILE[:N,...]...` | take our side: stage 2, `HEAD` (during a rebase, the branch being rebased onto) |
| `git resolve theirs FILE[:N,...]...` | take their side: stage 3 |
| `git resolve base FILE[:N,...]...` | take the merge base's version: stage 1 |
| `git resolve both FILE[:N,...]...` | take ours, then theirs |

Conflicts are numbered from 1 in the order of the file; `FILE:2,3` picks
two, `FILE` all of them. Only the conflict blocks change, so edits made
around them stay. A file with no conflict left is staged with `git add`;
`git checkout --conflict=diff3 FILE` brings every conflict back.

It reads the markers whatever `merge.conflictStyle` is. The base comes
from the `|||||||` section of `diff3` and `zdiff3` markers; with plain
`merge` markers, from the index stages through `git merge-file --diff3`.
There a `merge` conflict may be a `diff3` one with the lines both sides
share at its ends moved out of it, and `base` replaces those lines too;
when no `diff3` conflict matches, it refuses and names
`git checkout --conflict=diff3 FILE`. A file without markers, deleted on
one side or binary, takes a whole side, and a side without the file
removes it (`git rm`).

## `git absorb`: staged fixes into fixup commits

```sh
git add -p                     # stage the fixes
git absorb --dry-run           # the plan
git absorb                     # the fixup! commits
git rebase -i --autosquash @{upstream}
```

For each staged hunk, `git blame` on `HEAD` names the commit that last
changed the lines it changes; a hunk that only adds lines goes by the
lines around it. When that is one commit in `@{upstream}..HEAD`
(`--base REV` for `REV..HEAD`), the hunk goes into a `fixup! SUBJECT`
commit for it, one per commit, on top of `HEAD`. It prints the plan and
the `git rebase -i --autosquash` command, which it does not run:

```
3f2a1c9d0e4b Add the parser
    parser.py:12-14, parser.py: after line 40
stays staged: parser.py:88 (lines from 2 commits)
stays staged: notes.txt (new file)
to fold them in: git rebase -i --autosquash @{upstream}
```

Hunks with lines from several commits or from before the range stay
staged, and so do new, deleted and binary files, mode changes and
submodules; renames count as a deletion and a new file. The work tree is
not touched. Exit 1 when no hunk can be absorbed.

## `git rd` and `git rdu`: compare two versions of a series

`git rd A B` is `git range-diff A B`: each commit of one version paired
with its counterpart in the other, and how they differ, as after a
rebase, an amend or a `git scrub`. `git rdu` compares the commits here
with the upstream's since they forked (`@{upstream}...HEAD`).
