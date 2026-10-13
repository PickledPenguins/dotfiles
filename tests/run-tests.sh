#!/bin/sh
# The test suites and their gates.
#
#   tests/run-tests.sh            fast: unit, interface, safety -- the pre-push gate (~2 s)
#   tests/run-tests.sh long       integration with the real programs + the example catalog
#   tests/run-tests.sh all        both
#   tests/run-tests.sh cov        fast with coverage of dots; fails below the floor in tests/coveragerc
#   tests/run-tests.sh mutate     every mutant in tests/mutants.txt must make the fast suite fail
#   tests/run-tests.sh mutate-shell  every mutant in tests/shell-mutants.txt must make its long tests or bats file fail
#   tests/run-tests.sh perf       shell startup and the prompt against this machine's baseline (tests/perf.py)
#   tests/run-tests.sh hook       install the packaged test-push and perf-push hooks running fast and perf, switched off
#
# Anything after the name is passed to pytest (to tests/perf.py for perf).
# Generated files go to .build/.
set -e
cd "$(dirname "$0")/.."
mkdir -p .build
export PYTHONDONTWRITEBYTECODE=1
PYTEST="python3 -m pytest -q -p no:cacheprovider -p no:benchmark"

command=${1:-fast}
[ $# -gt 0 ] && shift

# pytest comes from python3 on PATH; where that one lacks it, from the
# pytesting conda environment through in-env (the skills tools) when on PATH.
# hook and perf need none.
if [ "$command" != hook ] && [ "$command" != perf ] && ! python3 -c 'import pytest' 2>/dev/null; then
    if command -v in-env >/dev/null 2>&1 && in-env python3 -c 'import pytest' 2>/dev/null; then
        exec in-env tests/run-tests.sh "$command" "$@"
    fi
    echo "run-tests.sh: python3 ($(command -v python3)) has no pytest: install it, or put in-env on PATH" >&2
    exit 2
fi

case "$command" in
    fast) exec $PYTEST -m "not long" "$@" ;;
    long) exec $PYTEST -m long "$@" ;;
    all)  exec $PYTEST "$@" ;;
    cov)
        python3 -m coverage run --rcfile tests/coveragerc -m pytest -q -p no:cacheprovider -p no:benchmark -m "not long" "$@"
        python3 -m coverage report --rcfile tests/coveragerc
        ;;
    mutate)
        breaks_it=$(command -v breaks-it || echo "$HOME/work/ai/skills/bin/breaks-it")
        [ -x "$breaks_it" ] || { echo "run-tests.sh: breaks-it not found" >&2; exit 2; }
        # Mutate a copy: this checkout is ~/.dotfiles, so a dots run (or a
        # suite) during the pass would otherwise execute a mutant.
        rm -rf .build/mutate
        mkdir .build/mutate
        tar -c --exclude=./.git --exclude=./.build . | tar -x -C .build/mutate
        cd .build/mutate
        failed=0; total=0
        while IFS= read -r line; do
            case "$line" in ''|'#'*) continue ;; esac
            find=${line%% ||| *}; with=${line##* ||| }
            total=$((total + 1))
            if "$breaks_it" dots --find "$find" --with "$with" -- $PYTEST -m "not long" -x >/dev/null 2>&1; then
                echo "caught    $find"
            else
                echo "SURVIVED  $find  ->  $with"; failed=$((failed + 1))
            fi
        done < tests/mutants.txt
        echo "$((total - failed))/$total mutants caught"
        [ "$failed" -eq 0 ]
        ;;
    mutate-shell)
        breaks_it=$(command -v breaks-it || echo "$HOME/work/ai/skills/bin/breaks-it")
        [ -x "$breaks_it" ] || { echo "run-tests.sh: breaks-it not found" >&2; exit 2; }
        rm -rf .build/mutate-shell
        mkdir .build/mutate-shell
        tar -c --exclude=./.git --exclude=./.build . | tar -x -C .build/mutate-shell
        cd .build/mutate-shell
        # with_tests TESTS CMD...: run CMD followed by the test command TESTS names
        with_tests() {
            t=$1; shift
            case "$t" in
                *.bats) "$@" bats "$t" ;;
                *) "$@" $PYTEST -m long -x -k "$t" ;;
            esac
        }
        # A mutant counts as caught when its tests fail, so each TESTS must
        # pass unmutated first: a -k selecting nothing, a missing bats or a
        # test already failing would read as every mutant caught.
        sed -n 's/^[^#].* ||| //p' tests/shell-mutants.txt | sort -u | while IFS= read -r tests; do
            with_tests "$tests" command </dev/null >/dev/null 2>&1 ||
                { echo "run-tests.sh: '$tests' fails with no mutant (exit $?)" >&2; exit 2; }
        done
        survived=0; stale=0; total=0
        while IFS= read -r line; do
            case "$line" in ''|'#'*) continue ;; esac
            file=${line%% ||| *}; rest=${line#* ||| }
            find=${rest%% ||| *}; rest=${rest#* ||| }
            with=${rest%% ||| *}; tests=${rest#* ||| }
            total=$((total + 1))
            with_tests "$tests" "$breaks_it" "$file" --find "$find" --with "$with" -- </dev/null >/dev/null 2>&1 && rc=0 || rc=$?
            case $rc in
                0) echo "caught    $file: $find" ;;
                1) echo "SURVIVED  $file: $find  ->  $with"; survived=$((survived + 1)) ;;
                *) echo "STALE     $file: $find  (not in the file)"; stale=$((stale + 1)) ;;
            esac
        done < tests/shell-mutants.txt
        echo "$((total - survived - stale))/$total mutants caught, $survived survived, $stale stale"
        [ "$survived" -eq 0 ] && [ "$stale" -eq 0 ]
        ;;
    perf) exec python3 tests/perf.py "$@" ;;
    hook)
        # The pre-push gates are the packaged test-push and perf-push hooks
        # (git hooks, from ~/.local/share/git-hooks) running the fast suite
        # and perf. A link to the repository's former copy of test-push,
        # tests/hooks/pre-push, goes first.
        hooks=$(git rev-parse --git-path hooks)
        for old in "$hooks/pre-push" "$hooks/pre-push.off" "$hooks/pre-push.d/pre-push" "$hooks/pre-push.d/pre-push.off"; do
            case $(readlink "$old" || :) in */tests/hooks/pre-push) rm -f "$old" ;; esac
        done
        # Each pushed commit is tested in a checkout of its own, and commits
        # from before 2026-10-13 have the runner in the root. sh expands $r
        # when the hook runs.
        # shellcheck disable=SC2016
        runner='r=tests/run-tests.sh; [ -e "$r" ] || r=./run-tests.sh; "$r"'
        git config hooks.test "$runner fast"
        git config hooks.perf "$runner perf"
        git hooks install test-push perf-push
        echo "switch them on with: git hooks on test-push perf-push"
        ;;
    *)
        echo "usage: $0 [fast|long|all|cov|mutate|mutate-shell|perf|hook] [arguments]" >&2
        exit 2
        ;;
esac
