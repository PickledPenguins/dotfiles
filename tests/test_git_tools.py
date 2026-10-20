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
