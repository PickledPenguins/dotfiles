"""`git hooks`, the packaged hooks in ~/.local/share/git-hooks, their
dispatcher, the template that installs them all, and `git ctags` on top.

Every test runs real git in a repository under a HOME that dots applied this
checkout to, so the hooks run from where `dots apply` links them.
"""

import pytest

from conftest import REPO
from test_config_integration import fake_ctags, git_script
from test_runner import RUNNER

pytestmark = pytest.mark.long

CATALOG = REPO / "dot_local" / "share" / "git-hooks"


def hooks(home, script):
    """Run script in a new repository r with one commit, git hooks on PATH and
    use NAME... to install and switch on packaged hooks."""
    return git_script(home, f'export PATH="{home}/.local/bin:$PATH"; '
                            'use() { git hooks install "$@" >/dev/null && git hooks on "$@" >/dev/null; }; '
                            "git init -q -b main r && cd r && git commit -q --allow-empty -m one && " + script)


def with_origin(script):
    """A bare origin.git that r pushes main to first."""
    return ("git init -q --bare -b main ../origin.git && git remote add origin ../origin.git && "
            "git push -q -u origin main 2>/dev/null && " + script)


def packaged():
    return sorted(p.name[len("executable_"):] for p in CATALOG.iterdir() if p.name != "executable_dispatch")


# ----------------------------------------------------------------------
# git hooks
# ----------------------------------------------------------------------


@pytest.mark.parametrize("before", ["", "use protect && "], ids=["alone", "beside-a-dispatcher"])
def test_run_tests_hook_installs_test_push_and_perf_push_off_and_drops_the_old_copy(linked, before):
    proc = hooks(linked, f"mkdir -p tests && cp {REPO}/tests/run-tests.sh tests/ && "
                         "git config hooks.protect main && "
                         "ln -s ../../tests/hooks/pre-push .git/hooks/pre-push.off && "
                         f"{before}tests/run-tests.sh hook && git config hooks.test && git config hooks.perf && "
                         "git hooks on test-push perf-push && ls .git/hooks/pre-push.d && "
                         "ls .git/hooks | grep -v sample")
    assert (proc.stdout, proc.stderr) == (
        "test-push installed, off\nperf-push installed, off\n"
        "switch them on with: git hooks on test-push perf-push\n"
        f"{RUNNER} fast\n{RUNNER} perf\n"
        "test-push on\nperf-push on\nperf-push\n" + ("protect\n" if before else "")
        + "test-push\npre-push\npre-push.d\n", "")


def test_install_moves_the_existing_hook_aside_lists_switches_and_remove_puts_it_back(linked):
    proc = hooks(linked, "mkdir -p tests && printf '#!/bin/sh\\necho project\\n' >tests/pre-push && "
                         "chmod +x tests/pre-push && ln -s ../../tests/pre-push .git/hooks/pre-push.off && "
                         "printf '#!/bin/sh\\n' >.git/hooks/post-commit && chmod +x .git/hooks/post-commit && "
                         "git worktree add -q --detach ../w 2>/dev/null && "
                         "git hooks && git hooks install protect test-push && git hooks install protect && "
                         "git hooks on pre-push protect && (cd ../w && git hooks) && git hooks off && "
                         "git hooks remove protect test-push && git hooks remove protect && "
                         "readlink .git/hooks/pre-push.off && ls .git/hooks | grep -v sample")
    r, cat = linked.resolve() / "r", CATALOG
    assert (proc.stdout, proc.stderr) == (
        f"on  post-commit        post-commit          {r}/.git/hooks/post-commit\n"
        f"off pre-push           pre-push             {r}/tests/pre-push\n"
        "pre-push: the hook that was there moved to pre-push.d/pre-push.off\nprotect installed, off\n"
        "test-push installed, off\nprotect is already installed\npre-push on\nprotect on\n"
        f"on  post-commit        post-commit          {r}/.git/hooks/post-commit\n"
        f"on  pre-push           pre-push             {r}/tests/pre-push\n"
        f"on  pre-push           protect              {cat}/executable_protect\n"
        f"off pre-push           test-push            {cat}/executable_test-push\n"
        "post-commit off\npre-push off\nprotect off\n"
        "protect removed\ntest-push removed\nprotect is not installed\n"
        "../../tests/pre-push\npost-commit.off\npre-push.off\n", "")


# perf-push sorts before the moved pre-push and test-push after it: the old
# hook is the last entry in pre-push.d with the one and not with the other.
@pytest.mark.parametrize("other", ["test-push", "perf-push"])
def test_remove_keeps_the_dispatcher_while_another_hook_is_installed(linked, other):
    proc = hooks(linked, "printf '#!/bin/sh\\n' >.git/hooks/pre-push && chmod +x .git/hooks/pre-push && "
                         f"git hooks install protect {other} >/dev/null && git hooks remove protect && "
                         "ls .git/hooks/pre-push.d && git hooks | awk '{print $1, $3}'")
    entries = sorted([("pre-push", "on pre-push"), (f"{other}.off", f"off {other}")])
    assert (proc.stdout, proc.stderr) == (
        "protect removed\n" + "".join(f"{e}\n" for e, _ in entries) + "".join(f"{s}\n" for _, s in entries), "")


def test_remove_puts_back_an_existing_hook_that_sorts_last_in_the_event_directory(linked):
    proc = hooks(linked, "printf '#!/bin/sh\\n' >.git/hooks/pre-push && chmod +x .git/hooks/pre-push && "
                         "git hooks install perf-push && ls .git/hooks/pre-push.d && git hooks remove perf-push; "
                         "echo $?; git hooks install perf-push >/dev/null && git hooks remove; echo $?; "
                         "ls .git/hooks | grep -v sample")
    assert (proc.stdout, proc.stderr) == (
        "pre-push: the hook that was there moved to pre-push.d/pre-push\nperf-push installed, off\n"
        "perf-push.off\npre-push\nperf-push removed\n0\nperf-push removed\n0\npre-push\n", "")


def test_install_without_names_installs_every_packaged_hook_off(linked):
    proc = hooks(linked, "git hooks install >/dev/null && git hooks | awk '{print $1, $3}' | LC_ALL=C sort -u -k2")
    assert proc.stdout == "".join(f"off {name}\n" for name in packaged())


def test_on_needs_the_required_setting_and_off_alone_leaves_dispatchers(linked):
    proc = hooks(linked, "git hooks install lint >/dev/null && git hooks on lint whitespace; echo $?; "
                         "git hooks available | grep '^... lint '; git config hooks.lint true && "
                         "git hooks on lint && git hooks off && test -L .git/hooks/pre-commit && echo kept")
    assert proc.stdout == ("1\noff lint                 run this repository's linter on the staged files before a commit.\n"
                           "lint on\nlint off\nkept\n")
    assert proc.stderr == "git hooks: lint needs git config hooks.lint; set it first (git hooks show lint)\n"


def test_refusals_and_usage(linked):
    proc = hooks(linked, "git hooks on; echo $?; git hooks install nope; echo $?; git hooks off nope; echo $?; "
                         "git hooks show; echo $?; git hooks of; echo $?; git hooks update x; echo $?; "
                         "ln -s x .git/hooks/pre-push && ln -s x .git/hooks/pre-push.off && "
                         "git hooks install protect; echo $?; ls .git/hooks | grep -v sample")
    assert proc.stdout == "2\n1\n1\n2\n2\n2\n1\npre-push\npre-push.off\n"
    assert proc.stderr.replace(str(linked), "H") == (
        "usage: git hooks on NAME... (git hooks available lists them)\n"
        "git hooks: no packaged hook nope (git hooks available)\n"
        "git hooks: no hook nope in H/r/.git/hooks (git hooks install nope)\n"
        "usage: git hooks show NAME\n"
        "usage: git hooks [available | show NAME | install [NAME...] | remove [NAME...] | on NAME... "
        "| off [NAME...] | update | template | -h]\n"
        "usage: git hooks update\n"
        "git hooks: both pre-push and pre-push.off exist in H/r/.git/hooks; remove one\n")


def test_update_removes_dropped_hooks_and_events_and_adds_gained_events_in_the_hooks_state(linked):
    proc = hooks(linked, "C=$HOME/.local/share/git-hooks; "
                         "git hooks install protect lint >/dev/null && git hooks on protect >/dev/null && "
                         'cp --remove-destination "$(realpath $C/protect)" $C/protect && '
                         "sed -i 's/^# events: pre-push$/# events: pre-push pre-commit/' $C/protect && rm $C/lint && "
                         "git hooks update && git hooks | awk '{print $1, $2, $3}' && "
                         "sed -i 's/^# events: pre-push pre-commit$/# events: pre-commit/' $C/protect && "
                         "git hooks update && git hooks update && git hooks remove && ls .git/hooks | grep -v sample; "
                         "echo $?")
    assert (proc.stdout, proc.stderr) == (
        "lint removed from pre-commit: no longer packaged\nprotect added to pre-commit, on\n"
        "on pre-commit protect\non pre-push protect\n"
        "protect removed from pre-push: no longer one of its events\nprotect removed\n1\n", "")


def test_remove_takes_a_hook_no_longer_packaged(linked):
    proc = hooks(linked, "git hooks install lint >/dev/null && rm $HOME/.local/share/git-hooks/lint && "
                         "git hooks remove lint && git hooks remove lint; echo $?")
    assert (proc.stdout, proc.stderr) == ("lint removed\n1\n", "git hooks: no packaged hook lint (git hooks available)\n")


def test_update_refuses_while_the_catalog_has_a_broken_link(linked):
    proc = hooks(linked, "git hooks install protect >/dev/null && ln -sfn /nowhere $HOME/.local/share/git-hooks/protect && "
                         "git hooks update; echo $?; git hooks | awk '{print $3}'")
    assert (proc.stdout, proc.stderr) == (
        "1\nprotect\n", f"git hooks: {linked}/.local/share/git-hooks/protect is a broken link; run dots apply first\n")


def test_available_and_show_work_outside_a_repository(linked):
    proc = git_script(linked, f'export PATH="{linked}/.local/bin:$PATH"; '
                              "git hooks available | awk '{print $1, $2}' | LC_ALL=C sort && "
                              "git hooks show test-push | tail -3")
    assert proc.stdout == "".join(f"- {name}\n" for name in packaged()) + (
        "\nhooks.test = (unset)\nhere: not in a git repository\n")


def test_show_prints_the_header_and_each_setting_here(linked):
    proc = hooks(linked, "git config hooks.protect trunk && git hooks show protect")
    assert proc.stdout == (
        "protect: refuse a push that deletes or rewrites a protected branch.\n"
        "events: pre-push\nconfig: hooks.protect\n\n"
        "hooks.protect is the list of protected branches, separated by spaces;\n"
        "the default is \"main master\". A push deleting one, or one that is not a\n"
        "fast-forward of what the remote has (a force push), is refused. A remote\n"
        "commit this repository has not fetched counts as a rewrite: fetch first.\n\n"
        "hooks.protect = trunk\nhere: not installed\n")


def test_help_is_the_header(linked):
    proc = hooks(linked, "git hooks -h | head -2")
    assert proc.stdout == ("git-hooks: install the packaged git hooks in a repository, switch them on and off.\n\n")


# ----------------------------------------------------------------------
# the dispatcher
# ----------------------------------------------------------------------


def test_dispatch_runs_in_name_order_stops_a_pre_event_at_the_first_failure_and_honors_hooks_skip(linked):
    proc = hooks(linked, "git hooks install whitespace >/dev/null && d=.git/hooks/pre-commit.d && "
                         "printf '#!/bin/sh\\necho \"a $GIT_HOOK_EVENT\"\\n' >$d/a && "
                         "printf '#!/bin/sh\\necho b; exit 3\\n' >$d/b && printf '#!/bin/sh\\necho c\\n' >$d/c && "
                         "printf '#!/bin/sh\\necho off\\n' >$d/d.off && chmod +x $d/* && "
                         "git commit -q --allow-empty -m two 2>&1; echo $?; HOOKS_SKIP='x b' git commit -q --allow-empty -m three 2>&1")
    assert proc.stdout == "a pre-commit\nb\n1\na pre-commit\nc\n"


def test_dispatch_runs_every_post_hook_and_gives_each_the_whole_stdin(linked):
    proc = hooks(linked, "git hooks install ctags >/dev/null && d=.git/hooks/post-rewrite.d && "
                         "printf '#!/bin/sh\\nwc -l; exit 1\\n' >$d/a && printf '#!/bin/sh\\nwc -l\\n' >$d/b && "
                         "chmod +x $d/a $d/b && git commit -q --allow-empty -m two && "
                         "git commit -q --allow-empty --amend -m two-b 2>&1; echo $?")
    assert proc.stdout == "1\n1\n0\n"


def test_dispatch_runs_the_private_hooks_after_the_shipped_ones(linked):
    proc = hooks(linked, "git hooks install whitespace >/dev/null && "
                         "printf '#!/bin/sh\\necho shipped\\n' >.git/hooks/pre-commit.d/z && "
                         "p=$HOME/.config/git/hooks.private/pre-commit.d && mkdir -p $p ../mine/pre-commit.d && "
                         "printf '#!/bin/sh\\necho \"private $GIT_HOOK_EVENT\"; exit 4\\n' >$p/a && "
                         "printf '#!/bin/sh\\necho after\\n' >$p/b && printf '#!/bin/sh\\necho off\\n' >$p/c.off && "
                         "printf '#!/bin/sh\\necho mine\\n' >../mine/pre-commit.d/m && "
                         "chmod +x .git/hooks/pre-commit.d/z $p/* ../mine/pre-commit.d/m && "
                         "git commit -q --allow-empty -m two 2>&1; echo $?; "
                         "HOOKS_SKIP=a git commit -q --allow-empty -m three 2>&1; "
                         "git config hooks.privateDir ../mine && git commit -q --allow-empty -m four 2>&1; "
                         "rm -r .git/hooks/pre-commit.d && git commit -q --allow-empty -m five 2>&1")
    assert proc.stdout.splitlines() == ["shipped", "private pre-commit", "1", "shipped", "after",
                                        "shipped", "mine", "mine"]
# ----------------------------------------------------------------------
# the packaged hooks
# ----------------------------------------------------------------------


def test_whitespace_refuses_trailing_spaces(linked):
    proc = hooks(linked, "use whitespace && echo 'x ' >f && git add f && git commit -qm f; echo $?; "
                         "echo x >f && git add f && git commit -qm f && echo committed")
    assert proc.stdout == "1\ncommitted\n"
    assert proc.stderr == ("f:1: trailing whitespace.\n+x \n"
                           "whitespace: fix the lines above, or commit with --no-verify\n")


def test_big_file_refuses_a_file_over_the_limit(linked):
    proc = hooks(linked, "use big-file && git config hooks.maxFileSize 10 && printf '%020d' 0 >big && "
                         "echo small >s && git add big s && git commit -qm f; echo $?; "
                         "git config hooks.maxFileSize 100 && git commit -qm f && echo committed")
    assert proc.stdout == "1\ncommitted\n"
    assert proc.stderr == ("big-file: big is 20 bytes, over hooks.maxFileSize (10)\n"
                           "big-file: unstage it, or commit with --no-verify\n")


def test_secrets_refuses_tokens_assignments_and_key_files_unless_allowed(linked):
    # diff.noprefix drops the b/ the file names are read after
    proc = hooks(linked, "git config diff.noprefix true && use secrets && echo 'key = AKIAABCDEFGHIJKLMNOP' >a && "
                         "echo 'PASSWORD = \"hunter22\"' >b && touch id_rsa && git add a b id_rsa && "
                         "git commit -qm f; echo $?; git reset -q && rm id_rsa && "
                         "echo 'PASSWORD = \"x1234567\"  # hooks:allow-secret' >b && "
                         "git add b && git commit -qm f && echo committed")
    assert proc.stdout == "1\ncommitted\n"
    assert proc.stderr == ("secrets: a: key = AKIAABCDEFGHIJKLMNOP\nsecrets: b: PASSWORD = \"hunter22\"\n"
                           "secrets: id_rsa is a file that usually holds a secret\n"
                           "secrets: remove them, or commit with --no-verify\n")


def test_debug_left_refuses_a_debugger_call(linked):
    proc = hooks(linked, "git config diff.noprefix true && use debug-left && printf 'x = 1\\nbreakpoint()\\n' >a.py && "
                         "git add a.py && "
                         "git commit -qm f; echo $?; printf 'import pdb  # hooks:allow-debug\\n' >a.py && "
                         "git add a.py && git commit -qm f && echo committed")
    assert proc.stdout == "1\ncommitted\n"
    assert proc.stderr == "debug-left: a.py: breakpoint()\ndebug-left: remove them, or commit with --no-verify\n"


def test_content_hooks_check_a_renamed_file(linked):
    # git pairs a moved file with its old name (status R), so it is neither added nor modified
    proc = hooks(linked, "seq 40 >old.py && echo x=1 >env.txt && git add . && git commit -qm f && "
                         "use big-file debug-left secrets && git config hooks.maxFileSize 100 && "
                         "git mv old.py new.py && git mv env.txt .env && "
                         "printf 'token = \"hunter2hunter2\"\\nbreakpoint()\\n' >>new.py && git add new.py && "
                         "HOOKS_SKIP='debug-left secrets' git commit -qm mv; echo $?; "
                         "HOOKS_SKIP='big-file secrets' git commit -qm mv; echo $?; "
                         "HOOKS_SKIP='big-file debug-left' git commit -qm mv; echo $?")
    assert proc.stdout == "1\n1\n1\n"
    assert proc.stderr == ("big-file: new.py is 149 bytes, over hooks.maxFileSize (100)\n"
                           "big-file: unstage it, or commit with --no-verify\n"
                           "debug-left: new.py: breakpoint()\n"
                           "debug-left: remove them, or commit with --no-verify\n"
                           "secrets: new.py: token = \"hunter2hunter2\"\n"
                           "secrets: .env is a file that usually holds a secret\n"
                           "secrets: remove them, or commit with --no-verify\n")


def test_lint_runs_the_command_on_the_matching_staged_files(linked):
    proc = hooks(linked, "git config hooks.lint 'echo linted' && git config hooks.lintFiles '*.py' && use lint && "
                         "touch a.py b.txt && git add a.py b.txt && git commit -qm f && "
                         "git config hooks.lint false && touch c.py && git add c.py && git commit -qm g; echo $?; "
                         "git reset -q && touch d.txt && git add d.txt && git commit -qm h && echo committed")
    assert proc.stdout == "1\ncommitted\n"
    assert proc.stderr == "linted a.py\nlint: false failed; fix the files, or commit with --no-verify\n"


def test_no_commit_on_refuses_a_protected_branch(linked):
    proc = hooks(linked, "use no-commit-on && git commit -q --allow-empty -m two; echo $?; "
                         "git switch -q -c feat && git commit -q --allow-empty -m two && echo committed")
    assert proc.stdout == "1\ncommitted\n"
    assert proc.stderr == "no-commit-on: main is protected (hooks.protect); commit on a branch, or with --no-verify\n"


def test_branch_tag_prefixes_the_ticket_once(linked):
    proc = hooks(linked, "use branch-tag && git switch -q -c ABC-12-login && git commit -q --allow-empty -m fix && "
                         "git commit -q --allow-empty -m 'ABC-12 again' && git switch -q -c plain && "
                         "git commit -q --allow-empty -m plain && git log --format=%s -3")
    assert proc.stdout == "plain\nABC-12 again\nABC-12: fix\n"


def test_branch_tag_prefixes_a_message_written_in_the_editor(linked):
    # the file git hands the hook already says "# On branch ABC-12-login"
    proc = hooks(linked, "use branch-tag && git switch -q -c ABC-12-login && "
                         "GIT_EDITOR='sed -i 1s/\\$/fix/' git commit -q --allow-empty && git log --format=%s -1")
    assert proc.stdout == "ABC-12: fix\n"


def test_msg_format_checks_the_subject_and_the_blank_line(linked):
    long = "x" * 73
    proc = hooks(linked, f"use msg-format && git commit -q --allow-empty -m 'Ends.' -m body; echo $?; "
                         f"git commit -q --allow-empty -m {long}; echo $?; "
                         "git commit -q --allow-empty -F - <<<$'subject\\nbody'; echo $?; "
                         "git commit -q --allow-empty -m 'fixup! Ends.' && git commit -q --allow-empty -m 'Good' && "
                         "echo committed")
    assert proc.stdout == "1\n1\n1\ncommitted\n"
    note = "msg-format: the message is kept in .git/COMMIT_EDITMSG; fix it, or commit with --no-verify\n"
    assert proc.stderr == ("msg-format: the subject ends in a period\n" + note +
                           "msg-format: the subject is 73 characters, over hooks.subjectMax (72)\n" + note +
                           "msg-format: line 2 is not blank\n" + note)


def test_test_merge_stops_a_merge_whose_tests_fail(linked):
    proc = hooks(linked, "git config hooks.test 'test ! -e bad' && use test-merge && "
                         "git switch -q -c a && touch bad && git add bad && git commit -qm a && "
                         "git switch -q main && git commit -q --allow-empty -m two && "
                         "git merge -q --no-edit a; echo $?; git merge --abort && "
                         "git switch -q -c b main && touch good && git add good && git commit -qm b && "
                         "git switch -q main && git merge -q --no-ff --no-edit b && git log --format=%s -1")
    assert proc.stdout == "1\nMerge branch 'b'\n"
    assert proc.stderr == ("test-merge: tests fail; git merge --abort undoes the merge\n"
                           "Not committing merge; use 'git commit' to complete the merge.\n")


def test_test_push_tests_the_pushed_commit_not_the_work_tree(linked):
    proc = hooks(linked, with_origin("git config hooks.test 'test ! -e bad' && use test-push && "
                                     "touch bad && git add bad && git commit -qm bad && git push -q 2>/dev/null; "
                                     "echo $?; git rm -q bad && git commit -qm fixed && touch bad && "
                                     "git push -q 2>/dev/null && echo pushed && git worktree list | wc -l"))
    assert proc.stdout == "1\npushed\n1\n"


def test_test_push_tests_every_branch_pushed_though_the_tests_read_stdin(linked):
    # The hook's stdin, the pushed refs, must not be the tests' stdin
    proc = hooks(linked, with_origin('git config hooks.test "cat >/dev/null; echo run >>$PWD/../runs" && '
                                     "use test-push && git commit -q --allow-empty -m two && "
                                     "git branch a && git branch b && git push -q origin a b 2>/dev/null && cat ../runs"))
    assert proc.stdout == "run\nrun\n"


def test_test_push_message(linked):
    proc = hooks(linked, with_origin("git config hooks.test false && use test-push && "
                                     "git commit -q --allow-empty -m two && git push -q 2>&1 | grep test-push | "
                                     "sed 's/at [0-9a-f]*/at SHA/'"))
    assert proc.stdout == "test-push: tests fail at SHA; push stopped\n"


def test_perf_push_times_the_pushed_commit_and_stops_a_slower_one(linked):
    proc = hooks(linked, with_origin("git config hooks.perf 'test ! -e slow' && use perf-push && "
                                     "touch slow && git add slow && git commit -qm slow && git push -q 2>&1 | "
                                     "sed 's/at [0-9a-f]*/at SHA/'; git rm -q slow && git commit -qm fixed && "
                                     "touch slow && git push -q 2>/dev/null && echo pushed && git worktree list | wc -l"))
    assert proc.stdout == ("perf-push: slower at SHA; push stopped\n"
                           "error: failed to push some refs to '../origin.git'\npushed\n1\n")


def test_protect_refuses_a_force_push_and_a_delete_of_a_protected_branch(linked):
    proc = hooks(linked, with_origin("use protect && git commit -q --allow-empty -m two && git push -q && "
                                     "git reset -q --hard HEAD~ && git commit -q --allow-empty -m other && "
                                     "git push -q -f 2>&1 | grep protect; git push -q origin :main 2>&1 | grep protect; "
                                     "git push -q origin HEAD:feat && git push -q -f origin HEAD~:feat && echo feat"))
    assert proc.stdout == ("protect: main on origin would be rewritten, not fast-forwarded (hooks.protect)\n"
                           "protect: push with --no-verify to do it anyway\n"
                           "protect: deleting main on origin refused (hooks.protect)\n"
                           "protect: push with --no-verify to do it anyway\nfeat\n")


def test_wip_guard_refuses_wip_commits_to_a_protected_branch(linked):
    proc = hooks(linked, with_origin("use wip-guard && git commit -q --allow-empty -m 'wipe the cache' && "
                                     "git commit -q --allow-empty -m wip && "
                                     "git push -q origin HEAD:feat && git push -q 2>&1 | sed 's/^wip-guard: [0-9a-f]* /wip-guard: SHA /'"))
    assert proc.stdout == ("wip-guard: SHA wip\n"
                           "wip-guard: not pushing these to main; squash them, or push with --no-verify\n"
                           "error: failed to push some refs to '../origin.git'\n")


def test_wip_guard_checks_every_commit_pushed_to_a_url(linked):
    # The wip commit is on origin, but the push names a URL, not origin
    proc = hooks(linked, with_origin("git commit -q --allow-empty -m wip && git push -q && "
                                     "git commit -q --allow-empty -m two && use wip-guard && "
                                     "git init -q --bare ../new.git && git push -q ../new.git HEAD:main 2>&1 | "
                                     "sed 's/^wip-guard: [0-9a-f]* /wip-guard: SHA /'"))
    assert proc.stdout == ("wip-guard: SHA wip\n"
                           "wip-guard: not pushing these to main; squash them, or push with --no-verify\n"
                           "error: failed to push some refs to '../new.git'\n")


def test_published_refuses_to_rebase_pushed_commits(linked):
    proc = hooks(linked, with_origin("use published && git commit -q --allow-empty -m two && git push -q && "
                                     "git commit -q --allow-empty -m three && git rebase -q -f HEAD~2 2>&1; "
                                     "git rebase -q -f HEAD~1 && echo rebased"))
    assert proc.stdout == ("published: 1 of the 2 commits to rebase are on a remote; "
                           "rebase with --no-verify to do it anyway\n"
                           "error: The pre-rebase hook refused to rebase.\nrebased\n")


def test_deps_changed_names_the_files_after_a_switch_and_a_merge(linked):
    proc = hooks(linked, "use deps-changed && git switch -q -c a && mkdir sub && touch sub/requirements-dev.txt x && "
                         "git add . && git commit -qm a && git switch -q main 2>&1 && git checkout -q a -- x 2>&1 && "
                         "git reset -q --hard && git merge -q --ff-only a 2>&1")
    assert proc.stdout == ("deps-changed: sub/requirements-dev.txt changed; update the environment\n"
                           "deps-changed: sub/requirements-dev.txt changed; update the environment\n")


def test_pyc_clean_removes_caches_outside_hidden_directories(linked):
    proc = hooks(linked, "use pyc-clean && mkdir -p pkg/__pycache__ .venv/lib/__pycache__ && "
                         "git switch -q -c a && git commit -q --allow-empty -m two && git switch -q main && "
                         "find . -name __pycache__ | sort")
    assert proc.stdout == "./.venv/lib/__pycache__\n"


def test_submodules_follow_a_switch(linked):
    env = "export GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=protocol.file.allow GIT_CONFIG_VALUE_0=always; "
    proc = hooks(linked, env + "git init -q -b main ../lib && git -C ../lib commit -q --allow-empty -m l1 && "
                         "git submodule -q add ../lib lib 2>/dev/null && git commit -qm sub && "
                         "git -C ../lib commit -q --allow-empty -m l2 && git switch -q -c new && "
                         "git -C lib pull -q && git commit -qam l2 && use submodules && git switch -q main && "
                         "git -C lib log --format=%s -1")
    assert proc.stdout == "l1\n"


def stub(name, then="exit 0"):
    """Script that puts first on PATH a NAME logging its arguments to ~/NAME.log, then running then."""
    return (f"mkdir -p ~/stubs && cat >~/stubs/{name} <<'STUB'\n"
            f'#!/bin/sh\necho "$*" >>"$HOME/{name}.log"\n{then}\nSTUB\n'
            f'chmod +x ~/stubs/{name} && export PATH="$HOME/stubs:$PATH" && ')


# Only what the hooks and git need, so a tool is missing whether or not this machine has it
BARE_PATH = ('mkdir -p ~/bare && for t in bash git mktemp cat rm sort; do ln -sf "$(command -v $t)" ~/bare/; done && '
             'bare=$HOME/bare && ')

REFUSES_BAD = 'for f; do [ -f "$f" ] && grep -q bad "$f" && exit 1; done; exit 0'


def test_identity_checks_the_email_against_the_rule_for_the_remote_host(linked):
    proc = hooks(linked, "unset GIT_AUTHOR_EMAIL && git config user.email t@example.com && use identity && "
                         "git config --add hooks.email 'github.com @good\\.org$' && "
                         "git config --add hooks.email 'gitlab.com @other\\.org$' && "
                         "git commit -q --allow-empty -m local && echo local && "
                         "git remote add origin git@github.com:o/r.git && git commit -q --allow-empty -m gh; echo $?; "
                         "git config user.email me@good.org && git commit -q --allow-empty -m good && echo good && "
                         "git remote set-url origin https://u@GitHub.com/o/r && git config user.email x@bad.org && "
                         "git commit -q --allow-empty -m bad; echo $?; git config user.email me@good.org && "
                         "git config url.git@gitlab.com:.insteadOf gl: && git remote add gl gl:o/r && "
                         "git commit -q --allow-empty -m gl; echo $?")
    assert proc.stdout == "local\n1\ngood\n1\n1\n"
    assert proc.stderr == (
        "identity: t@example.com does not match @good\\.org$, which hooks.email asks for on github.com\n"
        "identity: x@bad.org does not match @good\\.org$, which hooks.email asks for on github.com\n"
        "identity: me@good.org does not match @other\\.org$, which hooks.email asks for on gitlab.com\n")


def test_nocommit_refuses_a_marked_line_and_takes_a_pattern(linked):
    proc = hooks(linked, "git config diff.noprefix true && use nocommit && printf 'x = 1  # NOCOMMIT\\n' >a.py && "
                         "git add a.py && git commit -qm f; echo $?; git config hooks.nocommitPattern '^XXX' && "
                         "git commit -qm f && echo committed && printf 'a XXX\\nXXX here\\n' >b && git add b && "
                         "git commit -qm g; echo $?")
    assert proc.stdout == "1\ncommitted\n1\n"
    note = "nocommit: remove them, or commit with --no-verify\n"
    assert proc.stderr == "nocommit: a.py: x = 1  # NOCOMMIT\n" + note + "nocommit: b: XXX here\n" + note


def test_exec_bit_refuses_a_script_staged_without_it(linked):
    proc = hooks(linked, "use exec-bit && printf '#!/bin/sh\\n' >s && printf '#!/bin/sh\\n' >x && chmod +x x && "
                         "printf 'ELF' >p && chmod +x p && git add s x p && git commit -qm f; echo $?; "
                         "git add --chmod=+x s && git commit -qm f && echo committed")
    assert proc.stdout == "1\ncommitted\n"
    assert proc.stderr == ("exec-bit: s starts with #! but is not executable (git add --chmod=+x s)\n"
                           "exec-bit: fix them, or commit with --no-verify\n")


def test_portable_names_refuses_paths_other_systems_cannot_check_out(linked):
    proc = hooks(linked, "mkdir Docs docs dir. && touch Readme Docs/a && git add . && git commit -qm f && "
                         "use portable-names && touch README a:b con.txt docs/b dir./x $'\\303\\251' && git add . && "
                         "git commit -qm g; echo $?; git reset -q && touch ok && git add ok && "
                         "git commit -qm ok && echo committed")
    assert proc.stdout == "1\ncommitted\n"
    assert proc.stderr == (
        'portable-names: a:b: holds one of < > : " \\ | ? *\n'
        "portable-names: con.txt: con.txt is a reserved name on Windows\n"
        "portable-names: dir./x: dir. ends in a space or a period\n"
        "portable-names: $'\\303\\251': holds a character outside printable ASCII\n"
        "portable-names: README and Readme differ only in case\n"
        "portable-names: docs and Docs differ only in case\n"
        "portable-names: rename them, or commit with --no-verify\n")


def test_notebook_refuses_staged_outputs(linked):
    run = '{"cells": [{"cell_type": "code", "execution_count": 1, "outputs": []}, {"cell_type": "markdown"}]}'
    clear = '{"cells": [{"cell_type": "code", "execution_count": null, "outputs": []}]}'
    proc = hooks(linked, f"use notebook && echo '{run}' >a.ipynb && echo '{clear}' >b.ipynb && echo '[]' >c.ipynb && "
                         f"git add . && echo '{clear}' >a.ipynb && git commit -qm f; echo $?; "
                         "git add . && git rm -q --cached c.ipynb && git commit -qm f && echo committed")
    assert proc.stdout == "1\ncommitted\n"
    assert proc.stderr == ("notebook: a.ipynb: 1 of 2 cells hold outputs or an execution count\n"
                           "notebook: c.ipynb is not a notebook (not a JSON object)\n"
                           "notebook: clear them, or commit with --no-verify\n")


def test_eol_refuses_crlf_and_a_missing_final_newline_in_text_files(linked):
    proc = hooks(linked, "use eol && printf 'a\\r\\nb\\r\\n' >crlf.txt && printf x >nonl.txt && "
                         "printf '\\0\\r\\nx' >bin && git -c core.autocrlf=false add . && git commit -qm f; echo $?; "
                         "printf 'a\\nb\\n' >crlf.txt && printf 'x\\n' >nonl.txt && git add . && "
                         "git commit -qm f && echo committed")
    assert proc.stdout == "1\ncommitted\n"
    assert proc.stderr == ("eol: crlf.txt: 2 added lines end in CRLF\neol: nonl.txt: no newline at the end\n"
                           "eol: fix them, or commit with --no-verify\n")


def test_signoff_needs_the_committers_trailer(linked):
    proc = hooks(linked, "use signoff && git commit -q --allow-empty -m one; echo $?; "
                         "git commit -q --allow-empty -m one -m 'Signed-off-by: X <x@example.com>'; echo $?; "
                         "git commit -q --allow-empty -s -m one && git commit -q --allow-empty -m 'fixup! one' && "
                         "echo committed")
    assert proc.stdout == "1\n1\ncommitted\n"
    message = ("signoff: the message lacks Signed-off-by: T <t@example.com>; commit with -s, or with --no-verify\n"
               "signoff: the message is kept in .git/COMMIT_EDITMSG\n")
    assert proc.stderr == message * 2


def test_branch_tag_adds_a_trailer_or_a_formatted_prefix(linked):
    # A GitLab issue branch: the number first, a trailer GitLab links to the issue
    proc = hooks(linked, "use branch-tag && git switch -q -c 123-fix-login && git config hooks.tagPattern '^[0-9]+' && "
                         "git config hooks.tagTrailer 'Refs: #%s' && git commit -q --allow-empty -m fix && "
                         "git commit -q --allow-empty -m again -m $'Refs: #123\\nSigned-off-by: X <x@example.com>' && "
                         "GIT_EDITOR='sed -i 1s/\\$/edited/' git commit -q --allow-empty && "
                         "git config --unset hooks.tagTrailer && git config hooks.tagFormat '[%s] ' && "
                         "git commit -q --allow-empty -m pre && git log --format='%B--' -4")
    assert proc.stdout == ("[123] pre\n--\nedited\n\nRefs: #123\n--\n"
                           "again\n\nRefs: #123\nSigned-off-by: X <x@example.com>\n--\n"
                           "fix\n\nRefs: #123\n--\n")


@pytest.mark.parametrize("hook,tool,files,args", [
    ("shell-lint", "shellcheck", {"a.sh": "", "b.bash": "", "run": "#!/usr/bin/env bash", "z": "#!/bin/zsh",
                                  "d.txt": ""}, "-- a.sh b.bash run"),
    ("ruff", "ruff", {"a.py": "", "b.pyi": "", "c.txt": ""}, "check --no-fix -- a.py b.pyi"),
    ("yamllint", "yamllint", {"a.yml": "", "b.yaml": "", "c.txt": ""}, "-- a.yml b.yaml"),
    ("hadolint", "hadolint", {"Dockerfile": "", "sub/Dockerfile": "", "x.Dockerfile": "", "Containerfile": "",
                              "Dockerfile.txt": ""}, "-- Containerfile Dockerfile sub/Dockerfile x.Dockerfile"),
    ("actionlint", "actionlint", {".github/workflows/ci.yml": "", ".github/workflows/b.yaml": "",
                                  ".github/other.yml": ""}, "-- .github/workflows/b.yaml .github/workflows/ci.yml"),
])
def test_linter_hooks_run_their_tool_on_their_staged_files(linked, hook, tool, files, args):
    make = " && ".join(f"mkdir -p ./$(dirname {f}) && echo '{body}' >{f}" for f, body in files.items())
    first = args.split()[-1]
    proc = hooks(linked, stub(tool, REFUSES_BAD) + f"use {hook} && {make} && git add . && git commit -qm f && "
                         f"cat ~/{tool}.log && echo bad >>{first} && git add {first} && git commit -qm g; echo $?")
    assert proc.stdout == f"{args}\n1\n"
    assert proc.stderr == f"{hook}: fix the files above, or commit with --no-verify\n"


def test_syntax_names_the_file_and_line_of_a_parse_error(linked):
    proc = hooks(linked, "use syntax && printf '{\"a\": 1,\\n \"b\": }\\n' >a.json && printf 'a = 1\\nb =\\n' >b.toml && "
                         "printf '<a>\\n<b></a>\\n' >c.xml && echo '{}' >ok.json && git add . && git commit -qm f; echo $?; "
                         "echo '{}' >a.json && echo 'b = 1' >b.toml && echo '<a/>' >c.xml && git add . && "
                         "git commit -qm f && echo committed")
    assert proc.stdout == "1\ncommitted\n"
    assert proc.stderr == ("syntax: a.json:2: Expecting value\nsyntax: b.toml:2: Invalid value\n"
                           "syntax: c.xml:2: mismatched tag\nsyntax: fix the files above, or commit with --no-verify\n")


def test_pre_commit_framework_runs_where_the_project_configures_it(linked):
    proc = hooks(linked, stub("pre-commit", "exit 1") + "use pre-commit-framework && git commit -q --allow-empty -m a && "
                         "touch .pre-commit-config.yaml && git add . && git commit -qm b; echo $?; cat ~/pre-commit.log")
    assert proc.stdout == "1\nrun\n"
    assert proc.stderr == "pre-commit-framework: pre-commit run failed; fix the files, or commit with --no-verify\n"


def test_lfs_runs_git_lfs_with_the_arguments_and_the_pushed_refs(linked):
    proc = hooks(linked, with_origin(stub("git-lfs", 'cat >>"$HOME/git-lfs.log"') +
                                     "use lfs && git commit -q --allow-empty -m none && git push -q && "
                                     "echo '*.bin filter=lfs' >.gitattributes && git add . && git commit -qm lfs && "
                                     "git push -q && sed \"s/$(git rev-parse HEAD)/SHA/; s/$(git rev-parse HEAD~)/OLD/\" "
                                     "~/git-lfs.log"))
    assert proc.stdout == ("post-commit\npre-push origin ../origin.git\n"
                           "refs/heads/main SHA refs/heads/main OLD\n")


def test_gitlab_ci_lints_the_file_each_pushed_tip_holds(linked):
    proc = hooks(linked, with_origin(stub("glab", 'cat "$3" >>"$HOME/glab.log"; ! grep -q bad "$3"') +
                                     "use gitlab-ci && echo good >.gitlab-ci.yml && git add . && git commit -qm a && "
                                     "echo bad >.gitlab-ci.yml && git push -q && git commit -qam b && "
                                     "git push -q 2>&1 | sed 's/at [0-9a-f]*/at SHA/'; sed 's/ [^ ]*$/ FILE/' ~/glab.log"))
    assert proc.stdout == ("gitlab-ci: .gitlab-ci.yml at SHA fails glab ci lint; push stopped\n"
                           "error: failed to push some refs to '../origin.git'\n"
                           "ci lint FILE\ngood\nci lint FILE\nbad\n")


@pytest.mark.parametrize("hook,tool,make", [
    ("shell-lint", "shellcheck", "touch a.sh"),
    ("ruff", "ruff", "touch a.py"),
    ("yamllint", "yamllint", "touch a.yml"),
    ("hadolint", "hadolint", "touch Dockerfile"),
    ("actionlint", "actionlint", "mkdir -p .github/workflows && touch .github/workflows/a.yml"),
    ("syntax", "python3", "touch a.json"),
    ("notebook", "python3", "touch a.ipynb"),
    ("pre-commit-framework", "pre-commit", "touch .pre-commit-config.yaml"),
])
def test_a_commit_hook_fails_when_its_tool_is_missing(linked, hook, tool, make):
    proc = hooks(linked, BARE_PATH + f"use {hook} && {make} && git add . && PATH=$bare git commit -qm f; echo $?")
    assert (proc.stdout, proc.stderr) == ("1\n", f"{hook}: {tool} not on PATH\n")


@pytest.mark.parametrize("hook,tool,make", [
    ("lfs", "git-lfs", "echo '*.bin filter=lfs' >.gitattributes"),
    ("gitlab-ci", "glab", "touch .gitlab-ci.yml"),
])
def test_a_push_hook_fails_when_its_tool_is_missing(linked, hook, tool, make):
    proc = hooks(linked, with_origin(BARE_PATH + f"{make} && git add . && git commit -qm f && use {hook} && "
                                                 "PATH=$bare git push -q; echo $?"))
    assert (proc.stdout, proc.stderr) == ("1\n", f"{hook}: {tool} not on PATH\n"
                                                 "error: failed to push some refs to '../origin.git'\n")


def test_template_holds_what_install_leaves_linked_through_the_home(linked):
    proc = hooks(linked, "tree() { (cd \"$1\" && find . ! -name '*.sample' | sort | "
                         "while read -r p; do echo \"$p $(test -L \"$p\" && realpath \"$p\")\"; done); }; "
                         "git hooks install >/dev/null && tree .git/hooks >../installed && "
                         "git hooks template >/dev/null && git hooks template && "
                         "git init -q --template=$HOME/.local/share/git-template ../t && cd ../t && "
                         "tree .git/hooks >../templated && diff ../installed ../templated && grep -c . ../templated && "
                         "readlink .git/hooks/pre-push .git/hooks/pre-push.d/protect.off && "
                         "git hooks on whitespace && echo 'x ' >f && git add f && git commit -qm f 2>/dev/null; echo $?")
    catalog = f"{linked}/.local/share/git-hooks"
    assert (proc.stdout, proc.stderr) == (
        f"{1 + 10 * 2 + 46}\n{catalog}/dispatch\n{catalog}/protect\nwhitespace on\n1\n", "")


# ----------------------------------------------------------------------
# git ctags
# ----------------------------------------------------------------------


def test_git_ctags_builds_switches_its_hook_on_and_rebuilds_on_switch_and_worktree_add(linked):
    proc = git_script(linked, fake_ctags(linked) +
                      "git init -q u && (cd u && git ctags --hook && ls -A | grep -v '^.git$'); "
                      "git init -q -b main r && cd r && git commit -q --allow-empty -m one && "
                      "git ctags | sed \"s#$PWD#R#g\" && cat tags && git hooks | awk '{print $1, $2, $3}' && "
                      "git switch -q -c feat && wait_for tags feat && echo switched && "
                      "git worktree add -q -b other ../w 2>/dev/null && wait_for ../w/tags other && echo worktree")
    assert (proc.stdout, proc.stderr) == (
        "tags\ngit ctags: R/tags, rebuilt by the ctags hook\nmain\n"
        "on post-checkout ctags\non post-commit ctags\non post-merge ctags\non post-rewrite ctags\n"
        "switched\nworktree\n", "")


def test_git_ctags_keeps_a_hook_already_there_and_off_puts_it_back(linked):
    proc = git_script(linked, fake_ctags(linked) +
                      "git init -q -b main r && cd r && git commit -q --allow-empty -m one && "
                      "printf '#!/bin/sh\\necho mine\\n' >.git/hooks/post-merge && chmod +x .git/hooks/post-merge && "
                      "git ctags >/dev/null && git hooks | grep post-merge | awk '{print $1, $3}' && "
                      "git ctags off && ls .git/hooks | grep -v sample && ls tags 2>/dev/null; echo $?")
    assert (proc.stdout, proc.stderr) == ("on ctags\non post-merge\npost-merge\n2\n", "")


def test_git_ctags_refuses_a_ctags_that_is_not_universal(linked):
    proc = git_script(linked, fake_ctags(linked, "Exuberant Ctags 5.9") +
                      "git init -q r && cd r && git ctags; echo $?; ls .git/hooks | grep -vc sample")
    assert (proc.stdout, proc.stderr) == ("1\n0\n", "git ctags: needs universal-ctags on PATH\n")
