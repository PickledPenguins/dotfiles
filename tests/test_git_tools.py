"""The git tools in ~/.local/bin (docs/git-tools.md)

Every test runs real git in throwaway repositories under a HOME that dots
applied this checkout to, so each tool runs as `git NAME` from where `dots
apply` links it, with the git configuration this checkout ships.
"""

import shutil

import pytest

from test_config_integration import git_script

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
