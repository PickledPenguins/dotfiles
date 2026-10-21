"""The packaged `forbidden` hook: files and text refused at commit and push."""

import pytest

from test_git_hooks import hooks, with_origin

pytestmark = pytest.mark.long

SET = ("git config hooks.forbiddenPaths '(^|/)NOTES\\.md$' && git config hooks.forbiddenText 'zorblax' && "
       "use forbidden && ")
END = "forbidden: reword or remove them, or skip this hook with --no-verify\n"


def test_forbidden_refuses_files_lines_and_the_author_at_commit_unless_allowed(linked):
    proc = hooks(linked, SET + "echo zorblax >NOTES.md && echo 'has Zorblax' >a && "
                               "echo 'zorblax # hooks:allow-forbidden' >b && git add NOTES.md a b && "
                               "git commit -qm f; echo $?; git rm -q --cached NOTES.md && git add a && "
                               "GIT_AUTHOR_NAME=zorblax GIT_AUTHOR_EMAIL=z@example.com git commit -qm f; echo $?; "
                               "git rm -q --cached a && "
                               "git commit -qm f && echo committed")
    assert proc.stdout == "1\n1\ncommitted\n"
    assert proc.stderr == ("forbidden: file NOTES.md\nforbidden: a: has Zorblax\n" + END +
                           "forbidden: a: has Zorblax\nforbidden: author: zorblax <z@example.com>\n" + END)


def test_forbidden_refuses_a_message(linked):
    proc = hooks(linked, SET + "git commit -q --allow-empty -m 'add zorblax' -m 'body'; echo $?")
    assert (proc.stdout, proc.stderr) == ("1\n", "forbidden: message: add zorblax\n" + END)


def test_forbidden_checks_what_a_push_sends_and_the_name_it_gives_it(linked):
    proc = hooks(linked, with_origin(
        SET + "echo 'a zorblax line' >a && git add a && git commit -q --no-verify -m 'zorblax' && "
              "git push -q origin HEAD:feat 2>&1 | sed -E 's/^forbidden: [0-9a-f]+ /forbidden: SHA /'; "
              "git reset -q --hard HEAD~ && git push -q origin HEAD:zorblax-work 2>&1; "
              "git tag -a -m 'tagged zorblax' v1 && git push -q origin v1 2>&1; "
              # push.followTags would send v1 along again
              "git tag -d v1 >/dev/null && git push -q origin HEAD:clean && echo pushed"))
    assert proc.stdout == ("forbidden: a: a zorblax line\nforbidden: SHA message: zorblax\n" + END +
                           "error: failed to push some refs to '../origin.git'\n"
                           "forbidden: name: zorblax-work\n" + END +
                           "error: failed to push some refs to '../origin.git'\n"
                           "forbidden: tag v1: tagged zorblax\n" + END +
                           "error: failed to push some refs to '../origin.git'\npushed\n")


def test_forbidden_checks_nothing_while_unset(linked):
    proc = hooks(linked, "use forbidden && echo zorblax >NOTES.md && git add NOTES.md && "
                         "git commit -qm zorblax && echo committed")
    assert proc.stdout == "committed\n"
