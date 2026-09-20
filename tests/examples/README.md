# Example catalog

End-to-end cases for `dots`, each a directory with:

- `README.md` -- what the case shows, its level, and what to expect
- `case.sh` -- the script; runs from a fresh `HOME` with `dots` on `PATH` and
  `$SRC` as the source directory (empty, or a copy of this repository when
  the first line says `# source: repo`)
- `expected.txt` -- the exact stdout+stderr, with the temporary paths
  written as `SRC`, `HOME`, `TMP` and backup timestamps as `TS`

Levels:

- `simple/` -- one command or one naming rule on the smallest input
- `moderate/` -- a few commands interacting, or the real repository with one
  per-machine hook
- `complex/` -- whole workflows: bootstrapping a used machine, importing a
  home into a new repository, reorganizing the source, every local hook at
  once, a hostile source tree, a home in every state
- `failures/` -- the mistakes a user makes, with the exact message and exit code

Run them:

```sh
./run-tests.sh long                         # all cases through pytest
python3 tests/test_examples.py simple/04-dry-run   # print one case's output
python3 tests/test_examples.py --write NAME # re-record expected.txt after an intended change
```

A new case needs all three files; `test_every_case_documents_itself` checks
the README shape and `test_catalog_has_enough_variety` the counts.
