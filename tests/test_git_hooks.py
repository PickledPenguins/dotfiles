"""`git hooks`, the packaged hooks in ~/.local/share/git-hooks, their
dispatcher, the template that installs them all, and `git ctags` on top.

Every test runs real git in a repository under a HOME that dots applied this
checkout to, so the hooks run from where `dots apply` links them.
"""

import pytest

from conftest import REPO
from test_config_integration import fake_ctags, git_script

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


# ── git hooks ─────────────────────────────────────────────────────────────


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
        f"on  post-commit        post-commit   {r}/.git/hooks/post-commit\n"
        f"off pre-push           pre-push      {r}/tests/pre-push\n"
        "pre-push: the hook that was there moved to pre-push.d/pre-push.off\nprotect installed, off\n"
        "test-push installed, off\nprotect is already installed\npre-push on\nprotect on\n"
        f"on  post-commit        post-commit   {r}/.git/hooks/post-commit\n"
        f"on  pre-push           pre-push      {r}/tests/pre-push\n"
        f"on  pre-push           protect       {cat}/executable_protect\n"
        f"off pre-push           test-push     {cat}/executable_test-push\n"
        "post-commit off\npre-push off\nprotect off\n"
        "protect removed\ntest-push removed\nprotect is not installed\n"
        "../../tests/pre-push\npost-commit.off\npre-push.off\n", "")


def test_install_without_names_installs_every_packaged_hook_off(linked):
    proc = hooks(linked, "git hooks install >/dev/null && git hooks | awk '{print $1, $3}' | sort -u -k2")
    assert proc.stdout == "".join(f"off {name}\n" for name in packaged())


def test_on_needs_the_required_setting_and_off_alone_leaves_dispatchers(linked):
    proc = hooks(linked, "git hooks install lint >/dev/null && git hooks on lint whitespace; echo $?; "
                         "git hooks available | grep '^... lint '; git config hooks.lint true && "
                         "git hooks on lint && git hooks off && test -L .git/hooks/pre-commit && echo kept")
    assert proc.stdout == ("1\noff lint          run this repository's linter on the staged files before a commit.\n"
                           "lint on\nlint off\nkept\n")
    assert proc.stderr == "git hooks: lint needs git config hooks.lint; set it first (git hooks show lint)\n"


def test_refusals_and_usage(linked):
    proc = hooks(linked, "git hooks on; echo $?; git hooks install nope; echo $?; git hooks off nope; echo $?; "
                         "git hooks show; echo $?; git hooks of; echo $?; "
                         "ln -s x .git/hooks/pre-push && ln -s x .git/hooks/pre-push.off && "
                         "git hooks install protect; echo $?; ls .git/hooks | grep -v sample")
    assert proc.stdout == "2\n1\n1\n2\n2\n1\npre-push\npre-push.off\n"
    assert proc.stderr.replace(str(linked), "H") == (
        "usage: git hooks on NAME... (git hooks available lists them)\n"
        "git hooks: no packaged hook nope (git hooks available)\n"
        "git hooks: no hook nope in H/r/.git/hooks (git hooks install nope)\n"
        "usage: git hooks show NAME\n"
        "usage: git hooks [available | show NAME | install [NAME...] | remove [NAME...] | on NAME... "
        "| off [NAME...] | -h]\n"
        "git hooks: both pre-push and pre-push.off exist in H/r/.git/hooks; remove one\n")


def test_available_and_show_work_outside_a_repository(linked):
    proc = git_script(linked, f'export PATH="{linked}/.local/bin:$PATH"; '
                              "git hooks available | awk '{print $1, $2}' && git hooks show test-push | tail -3")
    assert proc.stdout == "".join(f"- {name}\n" for name in packaged()) + (
        "\nhooks.test = (unset)\nhere: not in a git repository\n")


def test_show_prints_the_header_and_each_setting_here(linked):
    proc = hooks(linked, "git config hooks.protect trunk && git hooks show protect")
    assert proc.stdout == (
        "protect -- refuse a push that deletes or rewrites a protected branch.\n"
        "events: pre-push\nconfig: hooks.protect\n\n"
        "hooks.protect is the list of protected branches, separated by spaces;\n"
        "the default is \"main master\".  A push deleting one, or one that is not a\n"
        "fast-forward of what the remote has (a force push), is refused.  A remote\n"
        "commit this repository has not fetched counts as a rewrite: fetch first.\n\n"
        "hooks.protect = trunk\nhere: not installed\n")


def test_help_is_the_header(linked):
    proc = hooks(linked, "git hooks -h | head -2")
    assert proc.stdout == ("git-hooks -- install the packaged git hooks in a repository, switch them on and off.\n\n")


# ── the dispatcher ────────────────────────────────────────────────────────


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


# ── the packaged hooks ────────────────────────────────────────────────────


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
    proc = hooks(linked, "use secrets && echo 'key = AKIAABCDEFGHIJKLMNOP' >a && "
                         "echo 'PASSWORD = \"hunter22\"' >b && touch id_rsa && git add a b id_rsa && "
                         "git commit -qm f; echo $?; git reset -q && rm id_rsa && "
                         "echo 'PASSWORD = \"x1234567\"  # hooks:allow-secret' >b && "
                         "git add b && git commit -qm f && echo committed")
    assert proc.stdout == "1\ncommitted\n"
    assert proc.stderr == ("secrets: a: key = AKIAABCDEFGHIJKLMNOP\nsecrets: b: PASSWORD = \"hunter22\"\n"
                           "secrets: id_rsa is a file that usually holds a secret\n"
                           "secrets: remove them, or commit with --no-verify\n")


def test_debug_left_refuses_a_debugger_call(linked):
    proc = hooks(linked, "use debug-left && printf 'x = 1\\nbreakpoint()\\n' >a.py && git add a.py && "
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


def test_test_push_message(linked):
    proc = hooks(linked, with_origin("git config hooks.test false && use test-push && "
                                     "git commit -q --allow-empty -m two && git push -q 2>&1 | grep test-push | "
                                     "sed 's/at [0-9a-f]*/at SHA/'"))
    assert proc.stdout == "test-push: tests fail at SHA; push stopped\n"


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
    proc = hooks(linked, with_origin("use wip-guard && git commit -q --allow-empty -m wip && "
                                     "git push -q origin HEAD:feat && git push -q 2>&1 | sed 's/^wip-guard: [0-9a-f]* /wip-guard: SHA /'"))
    assert proc.stdout == ("wip-guard: SHA wip\n"
                           "wip-guard: not pushing these to main; squash them, or push with --no-verify\n"
                           "error: failed to push some refs to '../origin.git'\n")


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


def test_template_holds_what_install_leaves(linked):
    proc = hooks(linked, "tree() { (cd \"$1\" && find . ! -name '*.sample' | sort | "
                         "while read -r p; do echo \"$p $(test -L \"$p\" && realpath \"$p\")\"; done); }; "
                         "git hooks install >/dev/null && tree .git/hooks >../installed && "
                         f"git init -q --template={linked}/.config/git/template ../t && cd ../t && "
                         "tree .git/hooks >../templated && diff ../installed ../templated && grep -c . ../templated && "
                         "git hooks on whitespace && echo 'x ' >f && git add f && git commit -qm f 2>/dev/null; echo $?")
    assert (proc.stdout, proc.stderr) == (f"{1 + 10 * 2 + 26}\nwhitespace on\n1\n", "")


# ── git ctags ─────────────────────────────────────────────────────────────


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
