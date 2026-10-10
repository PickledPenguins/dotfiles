#!/bin/sh
# The test suites and their gates.
#
#   ./run-tests.sh            fast: unit, interface, safety -- the pre-push gate (~2 s)
#   ./run-tests.sh long       integration with the real programs + the example catalog
#   ./run-tests.sh all        both
#   ./run-tests.sh cov        fast with coverage of dots; fails below the floor in tests/coveragerc
#   ./run-tests.sh mutate     every mutant in tests/mutants.txt must make the fast suite fail
#   ./run-tests.sh hook       install tests/hooks/pre-push into .git/hooks, switched off
#
# Anything after the name is passed to pytest.  Generated files go to .build/.
set -e
cd "$(dirname "$0")"
mkdir -p .build
export PYTHONDONTWRITEBYTECODE=1
PYTEST="python3 -m pytest -q -p no:cacheprovider -p no:benchmark"

command=${1:-fast}
[ $# -gt 0 ] && shift

# pytest comes from python3 on PATH; where that one lacks it, from the
# pytesting conda environment through in-env (the skills tools) when on PATH.
if [ "$command" != hook ] && ! python3 -c 'import pytest' 2>/dev/null; then
    if command -v in-env >/dev/null 2>&1 && in-env python3 -c 'import pytest' 2>/dev/null; then
        exec in-env ./run-tests.sh "$command" "$@"
    fi
    echo "run-tests.sh: python3 ($(command -v python3)) has no pytest: install it, or put in-env on PATH" >&2
    exit 2
fi

case "$command" in
    fast) exec $PYTEST -m "not long" "$@" ;;
    long) exec $PYTEST -m long "$@" ;;
    all)  exec $PYTEST "$@" ;;
    cov)
        python3 -m coverage run --rcfile tests/coveragerc -m pytest -q -p no:cacheprovider -m "not long" "$@"
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
    hook)
        ln -sf ../../tests/hooks/pre-push .git/hooks/pre-push.off
        echo "installed .git/hooks/pre-push.off -> tests/hooks/pre-push, switched off (git hooks on pre-push)"
        ;;
    *)
        echo "usage: $0 [fast|long|all|cov|mutate|hook] [pytest arguments]" >&2
        exit 2
        ;;
esac
