"""Every option in the configuration files: described, and working when switched on.

The configuration files are written in the options format that `dots
options` reads (docs/configuration.md#the-options-format).  For every
managed file that declares it, two promises are checked:

- fast: every setting has a description above it -- off ones always, on
  ones unless the line is structure (a `[section]` header, a `Host` line) --
  so a file can be read, and a setting switched, without looking anything up;
- long: switching a setting on, by deleting the comment character in front
  of each of its lines, leaves a file its program still loads without an
  error.  The real program reads a copy of the file with that one option
  switched on, inside a temporary HOME that holds the applied tree.  Slow
  programs read one copy with every option on, and one copy per option only
  when that fails, to say which.

A program that is not installed skips its files by name.  An option whose
description has a `Needs: NAME, ...` line is skipped while any NAME is
absent: a program on PATH, or a path when it starts with ~ or /.
"""

import fnmatch
import importlib.util
import os
import pty
import re
import select
import shutil
import subprocess
import sys
import time
from pathlib import Path

import pytest

from conftest import REPO, load_dots, run_subprocess

dots = load_dots()

#: Managed files that are not written in the options format, and why.
NOT_IN_THE_FORMAT = {
    ".dircolors": "dircolors -p output: a table of file types and colors, not options",
    ".config/bash/prompt/toolkit/*": "bash-prompt-toolkit subtree; a library, not a configuration file",
    ".ssh/sockets/.keep": "empty placeholder that makes git keep the directory",
}

#: Code lines that are structure rather than a setting, so need no description.
STRUCTURE = re.compile(r"""^(
      \[.*\]                                   # [section] in git, ini, editorconfig, pip
    | (Host|Match)\s.*                         # ssh blocks
    | augroup\s.* | autocmd! | endif | endfor | endfunction | else | finish
    | fi | done | esac | \} | ;;
    | \$if\s.* | \$else | \$endif                # readline conditionals
    | [a-z_]+:                                 # a YAML key whose value is the list below it
)$""", re.X)

MIN_DESCRIPTION = 15            # characters in the first description line


def catalog():
    """(target, source path) for every managed file in the options format."""
    files = []
    for entry in dots.managed_entries(REPO, Path("/nonexistent-home")):
        if not any(fnmatch.fnmatch(entry.rel, p) for p in NOT_IN_THE_FORMAT):
            files.append((entry.rel, entry.source))
    return files


CATALOG = catalog()
IDS = [rel for rel, _ in CATALOG]


def parse(rel, source):
    return dots.parse_options(source.read_text(), dots.comment_marker(rel))


# ── the format itself (fast) ──────────────────────────────────────────────


@pytest.mark.parametrize("rel, source", CATALOG, ids=IDS)
def test_file_declares_the_options_format(rel, source):
    assert dots.OPTIONS_TAG in source.read_text(), (
        f"~/{rel} does not mention `{dots.OPTIONS_TAG}` in its header; add the standard"
        " two lines, or list it in NOT_IN_THE_FORMAT with the reason")


@pytest.mark.parametrize("rel, source", CATALOG, ids=IDS)
def test_every_setting_has_a_description(rel, source):
    problems = []
    for option in parse(rel, source):
        if option.state == "off" and len(option.summary) < MIN_DESCRIPTION:
            problems.append(f"line {option.line}: switched-off setting without a description")
        elif option.state == "on" and not option.summary:
            code = [line.strip() for line in option.code]
            if not all(STRUCTURE.match(line) for line in code):
                problems.append(f"line {option.line}: setting without a description: {code[0]}")
    assert not problems, f"~/{rel}\n" + "\n".join(problems)


def test_the_exemptions_still_exist():
    rels = [e.rel for e in dots.managed_entries(REPO, Path("/nonexistent-home"))]
    for pattern in NOT_IN_THE_FORMAT:
        assert any(fnmatch.fnmatch(rel, pattern) for rel in rels), f"{pattern} is exempt but not managed"


def switch_on(text, option):
    """The file's text with one option switched on: its marker deleted on each line."""
    lines = text.splitlines(True)
    for i in range(option.line - 1, option.line - 1 + len(option.code)):
        indent = len(lines[i]) - len(lines[i].lstrip())
        lines[i] = lines[i][:indent] + lines[i][indent + 1:]
    return "".join(lines)


def test_switch_on_deletes_only_the_marker_after_the_indentation():
    text = "# f\n#f() {\n    #echo hi\n#}\n"
    option = dots.parse_options(text, "#")[0]
    assert switch_on(text, option) == "# f\nf() {\n    echo hi\n}\n"


# ── switching every option on (long) ──────────────────────────────────────


def missing_needs(option):
    """What an option's Needs: lines name that this machine lacks."""
    missing = []
    for line in option.doc:
        if not line.startswith("Needs:"):
            continue
        for item in line[len("Needs:"):].split(","):
            name = item.split()[0] if item.split() else ""
            if not name:
                continue
            present = (os.path.exists(os.path.expanduser(name)) if name[0] in "~/"
                       else shutil.which(name) is not None)
            if not present:
                missing.append(name)
    return missing


def run(argv, home, env=None, **kwargs):
    environment = dict(os.environ, HOME=str(home), TERM="xterm-256color")
    for var in ("DOTFILES_DIR", "DOTFILES_BASH_DIR", "XDG_CONFIG_HOME", "PROMPT_COMMAND", "TMUX",
                "SSH_AUTH_SOCK", "SSH_AGENT_PID",
                "GIT_CONFIG_GLOBAL", "WGETRC", "CONDARC", "PIP_CONFIG_FILE", "IPYTHONDIR", "MPLCONFIGDIR"):
        environment.pop(var, None)
    environment.update(env or {})
    kwargs.setdefault("timeout", 120)
    return subprocess.run(argv, env=environment, capture_output=True, text=True, errors="replace",
                          cwd=str(home), stdin=subprocess.DEVNULL, **kwargs)


def problems(proc, *words):
    """stderr (and stdout, for programs that warn there) when it holds any of words, else ''."""
    text = (proc.stderr + proc.stdout) if words else proc.stderr
    noise = ("job control", "process group", "Pseudo-terminal will not be allocated")
    lines = [l for l in text.splitlines() if l.strip() and not any(n in l for n in noise)]
    if words:
        lines = [l for l in lines if any(w.lower() in l.lower() for w in words)]
    return "\n".join(lines)


def each(check):
    """A loader that runs `check(home, path) -> error text` on every copy separately."""
    def load(home, copies):
        return [check(home, path) for path in copies]
    return load


def batched(check):
    """A loader for slow programs: all options on at once, then one by one only on failure."""
    def load(home, copies, all_on=None):
        if all_on is not None and not check(home, all_on):
            return [""] * len(copies)
        return [check(home, path) for path in copies]
    load.batched = True
    return load


def bash_modules(home, copies):
    """One interactive shell with the whole configuration; each copy sourced in a subshell."""
    listing = home.parent / "copies.list"
    listing.write_text("".join(f"{p}\0" for p in copies))
    script = r'''
agent=${SSH_AGENT_PID-}
while IFS= read -r -d '' copy; do
    err=$( { source "$copy"; eval "${PROMPT_COMMAND-}"; } 2>&1 >/dev/null
           [[ ${SSH_AGENT_PID-} != "$agent" ]] && kill "$SSH_AGENT_PID" 2>/dev/null )
    printf '%s\0%s\0' "$copy" "$err"
done < "$LISTING"
'''
    proc = run(["bash", "--rcfile", str(home / ".bashrc"), "-i", "-c", script], home,
               env={"LISTING": str(listing)})
    fields = proc.stdout.split("\0")
    errors = dict(zip(fields[0::2], fields[1::2]))
    return [errors.get(str(p), f"never reported (shell stderr: {problems(proc)})") for p in copies]


def bash_syntax(home, path):
    return problems(run(["bash", "-n", str(path)], home))


def posix_syntax(home, path):
    return problems(run([shutil.which("dash") or "sh", "-n", str(path)], home))


def vim_files(home, copies):
    """One vim with the whole configuration; each copy sourced inside a try."""
    listing, out, script = (home.parent / n for n in ("copies.list", "vim.errors", "check.vim"))
    listing.write_text("".join(f"{p}\n" for p in copies))
    script.write_text(
        "let s:errors = {}\n"
        f"for s:f in readfile('{listing}')\n"
        "  try\n    execute 'source' fnameescape(s:f)\n"
        "  catch\n    let s:errors[s:f] = v:exception\n  endtry\n"
        "endfor\n"
        f"call writefile([json_encode(s:errors)], '{out}')\n")
    run(["vim", "-es", "-N", "-u", str(home / ".vimrc"), "-S", str(script), "-c", "qall!"], home)
    import json
    errors = json.loads(out.read_text()) if out.exists() else {}
    return [errors.get(str(p), "") for p in copies]


def tmux_file(home, path):
    sock = f"dots-options-{os.getpid()}"
    proc = run(["tmux", "-L", sock, "-f", "/dev/null", "start-server", ";",
                "source-file", str(home / ".tmux.conf"), ";", "source-file", str(path), ";",
                "kill-server"], home)
    return problems(proc) or ("" if proc.returncode == 0 else f"exit {proc.returncode}")


def git_config(home, path):
    proc = run(["git", "config", "-f", str(path), "--list"], home)
    return problems(proc) or ("" if proc.returncode == 0 else f"exit {proc.returncode}")


def git_repo(home):
    repo = home.parent / "repo"
    if not repo.exists():
        repo.mkdir()
        run(["git", "init", "-q", str(repo)], home)
    return repo


def git_ignore(home, path):
    proc = run(["git", "-C", str(git_repo(home)), "-c", f"core.excludesFile={path}", "status", "--porcelain"], home)
    return problems(proc) or ("" if proc.returncode == 0 else f"exit {proc.returncode}")


def git_attributes(home, path):
    proc = run(["git", "-C", str(git_repo(home)), "-c", f"core.attributesFile={path}",
                "check-attr", "-a", "--", "x.py"], home)
    return problems(proc) or ("" if proc.returncode == 0 else f"exit {proc.returncode}")


def ssh_config(home, path):
    """ssh -G for a host no block names, and for every host an active Host line names."""
    hosts = re.findall(r"^\s*Host\s+(.+)$", path.read_text(), re.M)
    names = [h for line in hosts for h in line.split() if not any(c in h for c in "*?!")]
    for host in ["example.org", *names]:
        proc = run(["ssh", "-G", "-F", str(path), host], home)
        error = problems(proc) or ("" if proc.returncode == 0 else f"exit {proc.returncode}")
        if error:
            return f"ssh -G {host}: {error}"
    return ""


def inputrc(home, path):
    return problems(run(["bash", "--norc", "-i", "-c", f"bind -f {path}"], home))


def gdb(home, path):
    error = problems(run(["gdb", "-batch", "-nx", "-x", str(path)], home))
    # an optional feature this gdb was built without, not a bad setting
    return "" if "is not compiled into GDB" in error else error


def curl(home, path):
    proc = run(["curl", "-K", str(path), "--max-time", "1", "--retry", "0", "http://127.0.0.1:1/"], home)
    return problems(proc, "config file", "is unknown", "unknown option")


def wget(home, path):
    proc = run(["wget", "--tries=1", "--timeout=1", "-O", "/dev/null", "http://127.0.0.1:1/"], home,
               env={"WGETRC": str(path)})
    return problems(proc, str(path), "unknown", "wgetrc")


def pty_output(argv, home, seconds=1.0):
    """What a full-screen program printed on a terminal before it was killed."""
    pid, fd = pty.fork()
    if pid == 0:                                     # pragma: no cover -- the child
        os.chdir(str(home))
        os.environ.update(HOME=str(home), TERM="xterm-256color")
        os.execvp(argv[0], argv)
    out, deadline = b"", time.time() + seconds
    while time.time() < deadline:
        ready, _, _ = select.select([fd], [], [], 0.1)
        if ready:
            try:
                data = os.read(fd, 65536)
            except OSError:
                break
            if not data:
                break
            out += data
    os.kill(pid, 9)
    os.waitpid(pid, 0)
    os.close(fd)
    return re.sub(r"\x1b\[[0-9;?]*[A-Za-z]", "", out.decode(errors="replace"))


def nano(home, path):
    """nano shows rc-file errors in its status bar: "Error in FILE on line N:
    ...", or "Mistakes in FILE" when the path is too long for the bar."""
    screen = pty_output(["nano", "--rcfile", str(path), str(home / "new.txt")], home)
    return "\n".join(l.strip() for l in screen.replace("\r", "\n").splitlines()
                     if "Error in" in l or "Mistakes in" in l)


def xresources(home, path):
    """xrdb runs the file through cpp: a quote in a comment is a cpp warning."""
    proc = run(["xrdb", "-n", str(path)], home)
    errors = [l for l in problems(proc).splitlines() if "overrides entry" not in l]
    return "\n".join(errors) or ("" if proc.returncode == 0 else f"exit {proc.returncode}")


def editorconfig(home, path):
    bad = [l for l in path.read_text().splitlines()
           if l.strip() and not l.lstrip().startswith(("#", ";"))
           and not re.match(r"^\s*(\[.+\]|[a-z_]+\s*=\s*\S.*)\s*$", l)]
    return "\n".join(f"not a section or key = value: {l}" for l in bad)


def condarc(home, path):
    """conda reads $CONDARC only when the file is named condarc (or *.yml)."""
    named = home.parent / "conda" / "condarc"
    named.parent.mkdir(exist_ok=True)
    shutil.copy(path, named)
    proc = run(["conda", "config", "--show"], home, env={"CONDARC": str(named)})
    error = problems(proc) or ("" if proc.returncode == 0 else f"exit {proc.returncode}")
    if error:
        return error
    described = run(["conda", "config", "--describe"], home, env={"CONDARC": str(named)}).stdout
    keys = re.findall(r"^(\w+):", path.read_text(), re.M)
    return "\n".join(f"not a conda setting: {k}" for k in keys
                     if not re.search(rf"^# # {k} \(|aliases:.*\b{k}\b", described, re.M))


def pip_conf(home, path):
    """pip ignores keys it does not know, so each key must be one of
    `pip install --help`'s long options."""
    proc = run([sys.executable, "-m", "pip", "config", "list"], home, env={"PIP_CONFIG_FILE": str(path)})
    error = problems(proc) or ("" if proc.returncode == 0 else f"exit {proc.returncode}")
    if error:
        return error
    options = run([sys.executable, "-m", "pip", "install", "--help"], home).stdout
    keys = re.findall(r"^(?:global|install)\.([^=]+)=", proc.stdout, re.M)
    return "\n".join(f"not a pip option: {k}" for k in keys if not re.search(rf"--{re.escape(k)}\b", options))


def pythonrc(home, path):
    code = f"exec(compile(open({str(path)!r}).read(), {str(path)!r}, 'exec'), {{'__name__': '__main__'}})"
    proc = run([sys.executable, "-c", code], home)
    return problems(proc) or ("" if proc.returncode == 0 else f"exit {proc.returncode}")


def ipython(home, path):
    profile = home.parent / "ipython" / "profile_default"
    profile.mkdir(parents=True, exist_ok=True)
    shutil.copy(path, profile / "ipython_config.py")
    proc = run(["ipython", "--no-banner", "-c", "pass"], home, env={"IPYTHONDIR": str(profile.parent)})
    return problems(proc, "warning", "error", "traceback")


def matplotlibrc(home, path):
    if importlib.util.find_spec("matplotlib") is None:
        pytest.skip(f"matplotlib not installed for {sys.executable}")
    config = home.parent / "mplconfig"
    config.mkdir(exist_ok=True)
    shutil.copy(path, config / "matplotlibrc")
    proc = run([sys.executable, "-c", "import matplotlib"], home, env={"MPLCONFIGDIR": str(config)})
    return problems(proc, "bad key", "bad value", "traceback", "illegal")


def kitty(home, path):
    code = "import sys; from kitty.config import load_config; load_config(sys.argv[-1])"
    proc = run(["kitty", "+runpy", code, str(path)], home)
    return problems(proc, "ignoring", "error", "traceback", "invalid")


def sqliterc(home, path):
    return problems(run(["sqlite3", "-init", str(path), ":memory:", ".quit"], home))


def npmrc(home, path):
    proc = run(["npm", "config", "list"], home, env={"NPM_CONFIG_USERCONFIG": str(path)})
    return problems(proc, "warn", "error")


def ripgrep(home, path):
    proc = run(["rg", "-q", "no-such-text", str(path)], home, env={"RIPGREP_CONFIG_PATH": str(path)})
    return problems(proc) if proc.returncode > 1 else ""


def ctags(home, path):
    return problems(run(["ctags", f"--options={path}", "--version"], home))


#: target pattern -> (program that must be installed, loader)
LOADERS = [
    (".config/bash/rc.d/*", "bash", bash_modules),
    (".config/bash/prompt/layout.sh", "bash", bash_modules),
    (".bashrc", "bash", each(bash_syntax)),
    (".bash_profile", "bash", each(bash_syntax)),
    (".bash_logout", "bash", each(bash_syntax)),
    (".profile", "sh", each(posix_syntax)),
    (".vimrc", "vim", vim_files),
    (".vim/rc/*", "vim", vim_files),
    (".tmux.conf", "tmux", each(tmux_file)),
    (".config/tmux/conf.d/*", "tmux", each(tmux_file)),
    (".gitconfig", "git", each(git_config)),
    (".config/git/*.gitconfig", "git", each(git_config)),
    (".config/git/ignore", "git", each(git_ignore)),
    (".config/git/attributes", "git", each(git_attributes)),
    (".ssh/config", "ssh", each(ssh_config)),
    (".inputrc", "bash", each(inputrc)),
    (".gdbinit", "gdb", each(gdb)),
    (".curlrc", "curl", each(curl)),
    (".wgetrc", "wget", each(wget)),
    (".nanorc", "nano", batched(nano)),
    (".Xresources", "xrdb", each(xresources)),
    (".editorconfig", "sh", each(editorconfig)),
    (".condarc", "conda", batched(condarc)),
    (".config/pip/pip.conf", "sh", batched(pip_conf)),
    (".config/python/pythonrc.py", "sh", batched(pythonrc)),
    (".ipython/profile_default/ipython_config.py", "ipython", batched(ipython)),
    (".config/matplotlib/matplotlibrc", "sh", batched(matplotlibrc)),
    (".config/kitty/kitty.conf", "kitty", batched(kitty)),
    (".sqliterc", "sqlite3", each(sqliterc)),
    (".npmrc", "npm", batched(npmrc)),
    (".config/ripgrep/config", "rg", each(ripgrep)),
    (".ctags.d/*", "ctags", each(ctags)),
]


def loader_for(rel):
    for pattern, program, load in LOADERS:
        if fnmatch.fnmatch(rel, pattern):
            return program, load
    return None, None


def test_every_file_in_the_format_has_a_loader_or_says_why_not():
    without = {rel for rel, _ in CATALOG if loader_for(rel)[1] is None}
    assert without == {".screenrc"}           # screen has no way to check a file without a terminal


@pytest.fixture
def linked(home):
    proc = run_subprocess(home, REPO, "apply")
    assert proc.returncode == 0, proc.stdout
    return home


@pytest.mark.long
@pytest.mark.parametrize("rel, source", CATALOG, ids=IDS)
def test_every_option_loads_when_switched_on(rel, source, linked, tmp_path):
    program, load = loader_for(rel)
    if load is None:
        pytest.skip(f"no loader for ~/{rel}")
    if shutil.which(program) is None:
        pytest.skip(f"{program} not installed")
    text = source.read_text()
    options, copies, skipped = [], [], []
    for option in parse(rel, source):
        if option.state != "off":
            continue
        missing = missing_needs(option)
        if missing:
            skipped.append(f"line {option.line} needs {', '.join(missing)}")
            continue
        copy = tmp_path / "copies" / f"{option.line}-{source.name}"
        copy.parent.mkdir(exist_ok=True)
        copy.write_text(switch_on(text, option))
        options.append(f"line {option.line} ({option.summary})")
        copies.append(copy)
    if source.name.endswith(".off"):                 # the module itself, renamed on
        copy = tmp_path / "copies" / f"0-{source.name}"
        copy.parent.mkdir(exist_ok=True)
        copy.write_text(text)
        options.append("the module itself, renamed on")
        copies.append(copy)
    if not copies:
        pytest.skip("; ".join(skipped) or f"no switched-off options in ~/{rel}")
    if getattr(load, "batched", False):
        all_on = tmp_path / "copies" / f"all-{source.name}"
        switched = text
        for option in parse(rel, source):
            if option.state == "off" and not missing_needs(option):
                switched = switch_on(switched, option)
        all_on.write_text(switched)
        errors = load(linked, copies, all_on)
    else:
        errors = load(linked, copies)
    failures = [f"{name}: {error}" for name, error in zip(options, errors) if error]
    assert not failures, f"~/{rel} with one option switched on:\n" + "\n".join(failures)
