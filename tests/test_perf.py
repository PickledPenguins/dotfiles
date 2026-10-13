"""tests/perf.py, the startup-time gate: the baseline and the verdict with the
timing replaced (fast), and one real measurement (long)."""

import importlib.util
import json
import subprocess

import pytest

from conftest import REPO

spec = importlib.util.spec_from_file_location("perf", REPO / "tests" / "perf.py")
perf = importlib.util.module_from_spec(spec)
spec.loader.exec_module(perf)


@pytest.fixture
def timed(monkeypatch, tmp_path):
    """perf.main with fixed times on host h and the baseline in tmp_path"""
    now = {"startup": 70.0, "prompt": 40.0}
    monkeypatch.setattr(perf, "measure", lambda runs: dict(now))
    monkeypatch.setattr(perf.socket, "gethostname", lambda: "h")
    baseline = tmp_path / "perf-baseline.json"

    def main(*args):
        return perf.main(["--baseline", str(baseline), *args])
    return now, baseline, main


def test_the_first_run_on_a_host_records_its_baseline_beside_other_hosts(timed, capsys):
    now, baseline, main = timed
    baseline.write_text('{"other": {"prompt": 1.0, "startup": 2.0}}\n')
    assert main() == 0
    assert json.loads(baseline.read_text()) == {"other": {"prompt": 1.0, "startup": 2.0},
                                                "h": {"prompt": 40.0, "startup": 70.0}}
    assert capsys.readouterr().out == f"perf: baseline for h recorded in {baseline}: startup 70.0 ms, prompt 40.0 ms\n"


def test_within_the_slack_passes_and_over_it_fails_naming_the_slow_one(timed, capsys):
    now, baseline, main = timed
    main()
    capsys.readouterr()
    now["startup"] = 87.5
    assert main() == 0
    assert capsys.readouterr().out == ("perf: startup 87.5 ms, baseline 70.0, limit 87.5\n"
                                       "perf: prompt 40.0 ms, baseline 40.0, limit 50.0\n")
    now["prompt"] = 50.1
    assert main() == 1
    out, err = capsys.readouterr()
    assert out.splitlines()[1] == "perf: prompt 50.1 ms, baseline 40.0, limit 50.0  SLOWER"
    assert err == ("perf: more than 25% over the baseline; DOTFILES_DEBUG=1 bash -i -c true times each "
                   "module, ./run-tests.sh perf --rebaseline accepts the new times\n")


def test_rebaseline_replaces_the_hosts_times(timed, capsys):
    now, baseline, main = timed
    main()
    now["startup"] = 200.0
    assert main("--rebaseline") == 0
    assert json.loads(baseline.read_text())["h"]["startup"] == 200.0
    assert main() == 0


@pytest.mark.long
def test_a_real_run_records_both_times(tmp_path):
    baseline = tmp_path / "b.json"
    assert perf.main(["--runs", "1", "--baseline", str(baseline)]) == 0
    times = next(iter(json.loads(baseline.read_text()).values()))
    assert sorted(times) == ["prompt", "startup"]
    assert all(0 < ms < 5000 for ms in times.values())


def test_the_default_baseline_is_shared_by_every_worktree(tmp_path):
    def git(*args):
        subprocess.run(["git", "-C", str(tmp_path / "r"), *args], capture_output=True, check=True)
    (tmp_path / "r").mkdir()
    git("init", "-q")
    git("-c", "user.name=t", "-c", "user.email=t@t", "commit", "-q", "--allow-empty", "-m", "one")
    git("worktree", "add", "-q", "--detach", str(tmp_path / "w"))
    assert perf.baseline_file(tmp_path / "w") == (tmp_path / "r" / ".git" / "perf-baseline.json").resolve()
