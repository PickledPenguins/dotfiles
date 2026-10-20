"""The git tools in ~/.local/bin (docs/git-tools.md)

Every test runs real git in throwaway repositories under a HOME that dots
applied this checkout to, so each tool runs as `git NAME` from where `dots
apply` links it, with the git configuration this checkout ships.
"""

import re
import shutil

import pytest

from test_config_integration import bash, git_script

pytestmark = pytest.mark.long


def sh(home, script):
    """Run script in HOME with ~/.local/bin first on PATH"""
    return git_script(home, f'export PATH="{home}/.local/bin:$PATH"; ' + script)


# ----------------------------------------------------------------------
# git scrub
# ----------------------------------------------------------------------

# A pushed main with a secret file and two trailers, an annotated tag, a
# side branch, and words to replace.
SCRUB_REPO = (
    "git init -q --bare -b main origin.git && git init -q -b main r && cd r && "
    "git remote add origin ../origin.git && "
    "echo a >a && git add a && git commit -q -m 'Add a widget file' -m 'Signed-off-by: X <x@example.com>' && "
    "mkdir secrets && echo key >secrets/k && echo b >>a && git add -A && "
    "git commit -q -m 'Add the WIDGET and Widget' && git tag -a v1 -m v1 && "
    "git push -q -u origin main 2>/dev/null && git branch side && "
    "echo c >>a && git commit -q -a -m Third -m 'Signed-off-by: Y <y@example.com>' && "
    "printf 'widget gadget  # renamed\\n' >../words && "
)
SCRUB = "git scrub --path '^secrets/' --trailer '^Signed-off-by:' --words ../words"


def scrubbed_history_is_clean(home, extra=""):
    proc = sh(home, SCRUB_REPO + "old=$(git rev-parse origin/main) && "
                    f"{SCRUB} --backup ../backup {extra}; echo exit $?; "
                    "echo; for r in side main v1; do git log --format=%B $r; done | grep -v '^$'; "
                    "git log --branches --tags --name-only --format= | sort -u; "
                    "git status --short; cat secrets/k; git for-each-ref refs/original; "
                    "git bundle verify -q ../backup/all-refs.bundle 2>&1; cat ../backup/remote-refs.txt | cut -d' ' -f2; "
                    "echo lease $old")
    out, _, after = proc.stdout.partition("\nexit ")
    status, _, after = after.partition("\n\n")
    assert status == "0", proc.stderr
    assert after.split("lease")[0] == (
        "Add the WIDGET and Gadget\nAdd a gadget file\nThird\nAdd the WIDGET and Gadget\nAdd a gadget file\n"
        "Add the WIDGET and Gadget\nAdd a gadget file\n"
        "a\n?? secrets/k\nkey\n../backup/all-refs.bundle is okay\nrefs/remotes/origin/main\n")
    old = after.split("lease ")[1].strip()
    assert out.startswith(f"backup: {home}/r/../backup\nkept untracked: secrets/k\n")
    assert "refs/heads/main  " in out and "refs/heads/side  " in out and "refs/tags/v1  " in out
    assert f"  git push --force-with-lease=refs/heads/main:{old} origin refs/heads/main:refs/heads/main\n" in out
    assert "git push --force-with-lease=refs/heads/side" not in out           # no remote has it
    assert out.endswith("git reflog expire --expire=now --all && git gc --prune=now")


def test_scrub_with_filter_branch_drops_paths_trailers_and_words_everywhere(linked):
    scrubbed_history_is_clean(linked, "--filter-branch")


@pytest.mark.skipif(not shutil.which("git-filter-repo"), reason="git filter-repo not on PATH")
def test_scrub_with_filter_repo_drops_paths_trailers_and_words_everywhere(linked):
    scrubbed_history_is_clean(linked)


def test_scrub_dry_run_reports_and_changes_nothing(linked):
    proc = sh(linked, SCRUB_REPO + "before=$(git for-each-ref) && "
                      f"{SCRUB} --filter-branch --dry-run && test \"$(git for-each-ref)\" = \"$before\" && "
                      "test ! -e ../r.scrub && echo same")
    lines = proc.stdout.splitlines()
    assert lines[0] == "3 of 3 commits would change; every commit after one of them gets a new hash"
    assert lines[1] == "drop secrets/k  (1 commit)"
    assert "    - Signed-off-by: Y <y@example.com>" in lines
    assert "    + Add a gadget file" in lines and "    - Add a widget file" in lines
    assert lines[-2:] == ["backend: git filter-branch", "same"]


def test_scrub_replaces_whole_messages_named_by_old_commit(linked):
    proc = sh(linked, "git init -q -b main r && cd r && git commit -q --allow-empty -m one && "
                      "git commit -q --allow-empty -m two && git commit -q --allow-empty -m three && "
                      "printf 'Second\\n\\nRewritten.\\n' >../m2 && "
                      "printf '%s\\tm2\\n' $(git rev-parse --short HEAD~) >../messages && "
                      "git scrub --filter-branch --messages ../messages >/dev/null && git log --format=%B")
    assert proc.stdout == "three\n\nSecond\n\nRewritten.\n\none\n\n", proc.stderr


@pytest.mark.parametrize("setup, args, status, message", [
    ("echo x >>a && ", "--path x", 1, "git scrub: tracked changes here: commit or stash them first"),
    ("git worktree add -q ../w && ", "--path x", 1, "git scrub: other worktrees share this repository"),
    ("", "", 2, "git scrub: error: nothing to remove"),
    ("", "--path '('", 2, "git scrub: error: argument --path: '(':"),
    ("printf 'zz\\tm\\n' >../m && ", "--messages ../m", 1, "git scrub: ../m:1: expected COMMIT<TAB>MESSAGE-FILE"),
    ("printf 'widget\\n' >../w && ", "--words ../w", 1, "git scrub: ../w:1: expected OLD NEW, OLD one word"),
], ids=["dirty", "worktree", "nothing", "bad-regex", "bad-messages", "bad-words"])
def test_scrub_refusals_change_nothing(linked, setup, args, status, message):
    proc = sh(linked, "git init -q -b main r && cd r && echo a >a && git add a && git commit -q -m one && "
                      f"{setup}git scrub {args}; echo $?; git log --format=%s; ls ..")
    assert message in proc.stderr
    assert proc.stdout.startswith(f"{status}\none\n")
    assert "r.scrub" not in proc.stdout


def test_scrub_help_and_range_diff_aliases(linked):
    proc = sh(linked, "git scrub -h | head -1; git init -q -b main r && cd r && git commit -q --allow-empty -m one && "
                      "seq 20 >f && git add f && git commit -q -m two && git branch old && "
                      "sed -i s/7/seven/ f && git commit -q -a --amend -m two && "
                      "git rd old~..old HEAD~..HEAD | cut -c1-30")
    assert proc.stdout.splitlines()[0] == "usage: git scrub [--path RE]... [--trailer RE]... [--messages FILE] " \
                                          "[--words FILE] [--backup DIR] [--filter-branch] [--dry-run]"
    assert "1:  " in proc.stdout and " ! 1:  " in proc.stdout, proc.stderr


# ----------------------------------------------------------------------
# git each, git wt
# ----------------------------------------------------------------------

def test_each_and_wt_complete_in_an_interactive_shell(linked):
    proc = bash(linked, "export GIT_AUTHOR_NAME=T GIT_AUTHOR_EMAIL=t@example.com GIT_COMMITTER_NAME=T "
                        "GIT_COMMITTER_EMAIL=t@example.com; git init -q r && cd r && git commit -q --allow-empty -m a && "
                        "git branch other && git wt new side >/dev/null && __load_completion git; "
                        'c() { COMP_WORDS=("$@"); COMP_CWORD=$(($# - 1)); COMP_LINE="$*"; COMP_POINT=${#COMP_LINE}; '
                        'COMPREPLY=(); __git_wrap__git_main; echo "${COMPREPLY[*]}"; }; '
                        'c git wt ""; c git wt rm ""; c git wt rm -; c git wt new o; c git each -')
    assert [line.split() for line in proc.stdout.splitlines()] == [
        ["new", "ls", "rm", "cd"], ["main", "side"], ["-f"], ["other"], ["-k"]], proc.stderr


# A pushed base, then three commits that set n to 2, 3 and 4
EACH_REPO = (
    "git init -q --bare origin.git && git init -q -b main r && cd r && git remote add origin ../origin.git && "
    "mkdir sub && echo 1 >sub/n && git add . && git commit -q -m base && git push -q -u origin main 2>/dev/null && "
    "for i in 2 3 4; do echo $i >sub/n && git commit -q -a -m \"set $i\"; done && "
    "echo dirty >sub/n && touch new && cd sub && "
)


def test_each_runs_at_every_commit_stops_at_a_failure_and_leaves_the_work_tree(linked):
    check = "-- sh -c 'cat n; pwd; test $(cat n) != 3'"
    proc = sh(linked, EACH_REPO + f"git each {check}; echo exit $?; git each -k {check}; echo exit $?; "
                                  "cd .. && git status --short && git worktree list | wc -l")
    lines = [re.sub(r"^[0-9a-f]{7,}  ", "", line) for line in proc.stdout.splitlines()]
    assert lines[:3] == ["PASS  set 2", "FAIL  set 3", "    3"], proc.stderr
    assert lines[3].endswith("/wt/sub") and lines[4] == "exit 1"
    assert lines[5:8] == ["PASS  set 2", "FAIL  set 3", "    3"]
    assert lines[9:] == ["PASS  set 4", "exit 1", " M sub/n", "?? new", "1"]


def test_each_takes_a_range_and_refuses_bad_ones(linked):
    proc = sh(linked, EACH_REPO + "git each HEAD~.. -- true | cut -c10-; git each HEAD..HEAD -- true; echo $?; "
                                  "git each nope -- true; echo $?; git each; echo $?; git each -x -- true; echo $?")
    assert proc.stdout == "PASS  set 4\n1\n1\n2\n2\n"
    assert proc.stderr == ("git each: no commits in HEAD..HEAD\nfatal: bad revision 'nope'\n"
                           "usage: git each [-k] [RANGE] -- CMD...\nusage: git each [-k] [RANGE] -- CMD...\n")


def test_wt_new_ls_rm_and_cd_with_the_cdw_function(linked):
    proc = sh(linked, "git init -q --bare origin.git && git init -q -b main app && cd app && "
                      "git remote add origin ../origin.git && git commit -q --allow-empty -m one && "
                      "git push -q -u origin main 2>/dev/null && git branch remote && git push -q origin remote 2>/dev/null && "
                      "git branch -q -D remote && git commit -q --allow-empty -m two && "
                      "git wt new feat/x && git wt new remote >/dev/null && git wt new side HEAD~ >/dev/null && "
                      "git wt new side main; echo $?; touch ../app.wt/feat/x/u && git wt ls | sed \"s|$HOME|~|\"; "
                      "git rev-parse --abbrev-ref remote@{upstream} side; git wt rm feat/x; echo $?; "
                      "git wt rm -f feat/x && ls ../app.wt; git wt rm main; echo $?; git wt cd nope; echo $?; "
                      "git wt cd side; git wt cd; git wt x; echo $?")
    assert proc.stdout == (
        f"{linked}/app.wt/feat/x\n1\n"
        "main    clean       +1 -0     ~/app\n"
        "feat/x  1 changed   -         ~/app.wt/feat/x\n"
        "remote  clean       +0 -0     ~/app.wt/remote\n"
        "side    clean       -         ~/app.wt/side\n"
        "origin/remote\nside\n1\nremote\nside\n1\n1\n"
        f"{linked}/app.wt/side\n{linked}/app\n2\n"), proc.stderr
    assert "git wt: side exists; BASE is only for a new branch\n" in proc.stderr
    assert "contains modified or untracked files, use --force to delete it" in proc.stderr
    assert "git wt: main is checked out in the main worktree\ngit wt: no worktree on nope\n" in proc.stderr
    cdw = bash(linked, "export GIT_AUTHOR_NAME=T GIT_AUTHOR_EMAIL=t@example.com GIT_COMMITTER_NAME=T "
                       "GIT_COMMITTER_EMAIL=t@example.com; cd app.wt/side/ && cdw remote && pwd && cdw && pwd; "
                       "cdw nope; echo $?; pwd")
    assert cdw.stdout == f"{linked}/app.wt/remote\n{linked}/app\n1\n{linked}/app\n", cdw.stderr


# ----------------------------------------------------------------------
# git resolve, git absorb
# ----------------------------------------------------------------------

# A merge with two conflicts in f (lines b and i) and g deleted by us
RESOLVE_REPO = (
    "git init -q -b main r && cd r && git config merge.conflictStyle {style} && "
    "printf 'a\\nb\\nc\\nd\\ne\\nf\\ng\\nh\\ni\\nj\\n' >f && echo g >g && git add . && git commit -q -m base && "
    "git checkout -q -b other && sed -i -e 's/^b$/B-theirs/' -e 's/^i$/I-theirs/' f && echo x >>g && "
    "git commit -q -a -m theirs && git checkout -q main && sed -i -e 's/^b$/B-ours/' -e 's/^i$/I-ours/' f && "
    "git rm -q g && git commit -q -a -m ours && git merge -q other >/dev/null 2>&1; "
)


@pytest.mark.parametrize("style", ["merge", "diff3", "zdiff3"])
def test_resolve_lists_shows_and_takes_sides_per_conflict_in_every_style(linked, style):
    proc = sh(linked, RESOLVE_REPO.format(style=style) +
                      "echo edit >>f; git resolve list; COLUMNS=60 git resolve show f:1; "
                      "git resolve base f:2 && git resolve list && git resolve both f && tr '\\n' ' ' <f; echo; "
                      "git resolve ours g; git status --short")
    assert proc.stdout == (
        "f  both modified  2 conflicts\ng  deleted by us  0 conflicts\n"
        "f:1  lines 2-" + ("6" if style == "merge" else "8") + "\n"
        "ours HEAD          | base               | theirs other\n"
        "------------------ | ------------------ | ------------------\n"
        "B-ours             | b                  | B-theirs\n\n"
        "f: 1 conflict left\n"
        "f  both modified  1 conflict\ng  deleted by us  0 conflicts\n"
        "f: resolved, staged\n"
        "a B-ours B-theirs c d e f g h i j edit \n"
        "g: removed (ours has no such file)\n"
        "M  f\n"), proc.stderr


def test_resolve_base_of_a_merge_style_conflict_takes_the_lines_moved_out_of_it(linked):
    proc = sh(linked, "git init -q -b main r && cd r && git config merge.conflictStyle merge && "
                      "printf 'a\\nb\\nc\\n' >f && git add f && git commit -q -m base && git checkout -q -b other && "
                      "printf 'a\\nP\\nY\\nc\\n' >f && git commit -q -a -m theirs && git checkout -q main && "
                      "printf 'a\\nP\\nX\\nc\\n' >f && git commit -q -a -m ours && git merge -q other >/dev/null; "
                      "sed -n 2p f; git resolve base f && cat f")
    assert proc.stdout == "P\nf: resolved, staged\na\nb\nc\n", proc.stderr


@pytest.mark.parametrize("args, message, status", [
    ("ours f:3", "git resolve: f has 2 conflicts, no 3", 1),
    ("ours nope", "git resolve: nope is not conflicted", 1),
    ("both g", "git resolve: g has no conflict markers: take ours, theirs or base", 1),
    ("", "usage: git resolve list | show FILE[:N,...]... | ours|theirs|base|both FILE[:N,...]...", 2),
    ("list f", "usage: git resolve", 2),
])
def test_resolve_refusals_change_nothing(linked, args, message, status):
    proc = sh(linked, RESOLVE_REPO.format(style="merge") + f"git resolve {args}; echo $?; git status --short")
    assert proc.stdout == f"{status}\nUU f\nDU g\n"
    assert proc.stderr.startswith(message)


ABSORB_REPO = (
    "git init -q --bare origin.git && git init -q -b main r && cd r && git remote add origin ../origin.git && "
    "seq 1 30 >f && printf 'x\\ny\\n' >g && git add . && git commit -q -m base && "
    "git push -q -u origin main 2>/dev/null && "
    "sed -i 's/^5$/five/' f && git commit -q -a -m 'Name five' && "
    "sed -i 's/^20$/twenty/' f && printf 'x\\nY\\n' >g && git commit -q -a -m 'Name twenty' && "
    "sed -i -e 's/^five$/FIVE/' -e 's/^twenty$/TWENTY/' -e 's/^10$/ten/' f && printf 'x\\nY\\nz\\n' >g && "
    "echo new >n && git add f g n && echo unstaged >>f && "
)


def test_absorb_makes_one_fixup_per_owning_commit_and_keeps_the_rest_staged(linked):
    proc = sh(linked, ABSORB_REPO + "git absorb | sed 's/^[0-9a-f]\\{12\\} /SHA /'; "
                                    "git log --format=%s; git diff --cached --name-only; git diff --name-only; "
                                    "git show -U0 --format= HEAD~ | grep '^[-+][^-+]'; "
                                    "git -c sequence.editor=true rebase -q -i --autosquash --autostash @{upstream} "
                                    ">/dev/null 2>&1 && git log --format=%s && git show -U0 --format= HEAD~ | grep '^[-+][^-+]'")
    assert proc.stdout == (
        "SHA Name five\n    f:5\nSHA Name twenty\n    f:20, g: after line 2\n"
        "stays staged: f:10 (lines from before the range)\nstays staged: n (new file)\n"
        "to fold them in: git rebase -i --autosquash @{upstream}\n"
        "fixup! Name twenty\nfixup! Name five\nName twenty\nName five\nbase\n"
        "f\nn\nf\n-five\n+FIVE\n"
        "Name twenty\nName five\nbase\n-5\n+FIVE\n"), proc.stderr


def test_absorb_dry_run_and_refusals_change_nothing(linked):
    proc = sh(linked, ABSORB_REPO + "before=$(git rev-parse HEAD; git diff --cached) && "
                                    "git absorb --dry-run >/dev/null && echo $? && "
                                    "test \"$(git rev-parse HEAD; git diff --cached)\" = \"$before\" && "
                                    "git absorb --base HEAD >/dev/null; echo $?; git absorb --base nope; echo $?; "
                                    "git absorb -x; echo $?; git reset -q; git absorb; echo $?")
    assert proc.stdout == "0\n1\n1\n2\n1\n"
    assert proc.stderr == ("git absorb: no commits in HEAD..HEAD\nfatal: bad revision 'nope..HEAD'\n"
                           "usage: git absorb [--base REV] [--dry-run]\n"
                           "git absorb: error: unrecognized arguments: -x\ngit absorb: nothing staged\n")
