#!/usr/bin/env python3
"""The startup-time gate: ./run-tests.sh perf

Applies this checkout into a temporary HOME and times two things a user
waits for: an interactive bash start (`bash -i -c exit`, every new terminal
and tmux pane) and a warm `prompt_build` at the top of this checkout (every
prompt, in a git repository). Each median is compared with this machine's
baseline, and the gate fails when one is more than SLACK over it.

The baselines are kept per host name in perf-baseline.json in the git
directory shared by every worktree, so the packaged perf-push hook, which
runs this in a temporary worktree of each pushed commit, finds them. The
first run on a host, or --rebaseline, records them instead of comparing.
"""

from __future__ import annotations

import argparse
import json
import os
import socket
import statistics
import subprocess
import sys
import tempfile
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SLACK = 0.25
# The login's own settings would otherwise reach into the temporary HOME
UNSET = ("XDG_CONFIG_HOME", "XDG_DATA_HOME", "XDG_STATE_HOME", "XDG_CACHE_HOME", "PROMPT_COMMAND",
         "PS1", "BASH_ENV", "ENV", "HISTFILE", "INPUTRC", "TMUX", "TMUX_PANE", "GIT_DIR",
         "GIT_WORK_TREE", "GIT_INDEX_FILE", "GIT_CONFIG_GLOBAL", "DOTFILES_DEBUG")
PROMPT_CALLS = 20
PROMPT_LOOP = (f'prompt_build; s=$EPOCHREALTIME; for _ in {{1..{PROMPT_CALLS}}}; do prompt_build; done; '
               'e=$EPOCHREALTIME; echo "$s $e"')


def environment(home: Path) -> dict[str, str]:
    env = {k: v for k, v in os.environ.items() if k not in UNSET}
    env.update(HOME=str(home), TERM="xterm-256color", DOTS_SOURCE=str(ROOT))
    return env


def startup_ms(env: dict[str, str]) -> float:
    start = time.perf_counter()
    subprocess.run(["bash", "-i", "-c", "exit"], env=env, cwd=ROOT, stdin=subprocess.DEVNULL,
                   capture_output=True, check=True)
    return (time.perf_counter() - start) * 1000


def prompt_ms(env: dict[str, str]) -> float:
    out = subprocess.run(["bash", "-i", "-c", PROMPT_LOOP], env=env, cwd=ROOT,
                         stdin=subprocess.DEVNULL, capture_output=True, text=True,
                         check=True).stdout.split()
    return (float(out[-1]) - float(out[-2])) * 1000 / PROMPT_CALLS


def measure(runs: int) -> dict[str, float]:
    with tempfile.TemporaryDirectory(prefix="dotfiles-perf.") as home:
        env = environment(Path(home))
        subprocess.run([str(ROOT / "dots"), "apply"], env=env, capture_output=True, check=True)
        return {"startup": statistics.median(startup_ms(env) for _ in range(runs)),
                "prompt": statistics.median(prompt_ms(env) for _ in range(max(runs // 3, 1)))}


def baseline_file(root: Path = ROOT) -> Path:
    common = subprocess.run(["git", "rev-parse", "--path-format=absolute", "--git-common-dir"],
                            cwd=root, capture_output=True, text=True, check=True).stdout.strip()
    return Path(common) / "perf-baseline.json"


def judge(now: dict[str, float], base: dict[str, float]) -> tuple[list[str], bool]:
    """One line per measure against its baseline, and whether any is over the limit"""
    lines, over = [], False
    for name, ms in now.items():
        limit = base[name] * (1 + SLACK)
        slow = ms > limit
        over |= slow
        lines.append(f"perf: {name} {ms:.1f} ms, baseline {base[name]:.1f}, limit {limit:.1f}"
                     + ("  SLOWER" if slow else ""))
    return lines, over


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Time shell startup and the prompt against "
                                                 "this machine's baseline.")
    parser.add_argument("--rebaseline", action="store_true", help="record the times as the baseline")
    parser.add_argument("--runs", type=int, default=15, metavar="N",
                        help="interactive starts to time (default 15)")
    parser.add_argument("--baseline", type=Path, metavar="FILE",
                        help="baseline file (default perf-baseline.json in the git directory)")
    args = parser.parse_args(argv)

    path = args.baseline or baseline_file()
    stored = json.loads(path.read_text()) if path.exists() else {}
    host = socket.gethostname()
    now = measure(args.runs)
    if args.rebaseline or host not in stored:
        stored[host] = {name: round(ms, 2) for name, ms in now.items()}
        path.write_text(json.dumps(stored, indent=2, sort_keys=True) + "\n")
        print(f"perf: baseline for {host} recorded in {path}: "
              + ", ".join(f"{name} {ms:.1f} ms" for name, ms in now.items()))
        return 0
    lines, over = judge(now, stored[host])
    print("\n".join(lines))
    if over:
        print(f"perf: more than {SLACK:.0%} over the baseline; DOTFILES_DEBUG=1 bash -i -c true "
              "times each module, ./run-tests.sh perf --rebaseline accepts the new times",
              file=sys.stderr)
    return int(over)


if __name__ == "__main__":
    raise SystemExit(main())
