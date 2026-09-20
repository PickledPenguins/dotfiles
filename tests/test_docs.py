"""The documentation against the code, both directions.

Every surface is enumerated from the code or the tree at run time -- the
argument parser, the exit codes, the knobs the modules read, the module
files, the hook files the loaders name, the top-level targets -- and each
kind names the document that owns it, so a failure says where the missing
entry goes.  The README's examples are the recorded output of catalog cases.
"""

import re
from pathlib import Path

import pytest

from conftest import REPO

DOCS = REPO / "docs"
README = REPO / "README.md"
CONFIG = DOCS / "configuration.md"
CLI = DOCS / "cli.md"

README_MAX_LINES = 150

#: Surface deliberately left undocumented, each with its reason.
UNDOCUMENTED_ON_PURPOSE = {
    "DOTFILES_BASH_DIR",     # loader-internal; listed in the read-only table but not a knob
}


def text(path):
    return path.read_text()


def all_docs_text():
    return "\n".join(text(p) for p in [README, *sorted(DOCS.glob("*.md"))])


# ── dots: commands, flags, exit codes, environment ────────────────────────


def subparsers(parser):
    for action in parser._actions:
        if action.__class__.__name__ == "_SubParsersAction":
            return action.choices
    return {}


def test_every_subcommand_has_a_section_in_the_cli_reference(dots):
    parser = build_parser(dots)
    cli = text(CLI)
    for name in subparsers(parser):
        assert f"### `dots {name}" in cli, f"docs/cli.md lacks a section for `dots {name}`"


def build_parser(dots):
    """main() builds its parser inline; rebuild it by calling main with a
    sentinel argv and capturing the parser through parse_args."""
    import argparse

    captured = {}
    original = argparse.ArgumentParser.parse_args

    def capture(self, argv=None, namespace=None):
        captured["parser"] = self
        raise SystemExit(0)

    argparse.ArgumentParser.parse_args = capture
    try:
        with pytest.raises(SystemExit):
            dots.main(["managed"])
    finally:
        argparse.ArgumentParser.parse_args = original
    return captured["parser"]


def test_every_flag_of_every_subcommand_is_in_the_cli_reference(dots):
    parser = build_parser(dots)
    cli = text(CLI)
    for name, sub in subparsers(parser).items():
        section = cli.split(f"### `dots {name}")[1].split("\n### ")[0]
        for action in sub._actions:
            for flag in action.option_strings:
                if flag in ("-h", "--help"):
                    continue
                assert f"`{flag}`" in section, f"docs/cli.md: `dots {name}` section lacks `{flag}`"
            if not action.option_strings:
                assert action.dest in section, f"docs/cli.md: `dots {name}` lacks positional `{action.dest}`"
    for action in parser._actions:
        for flag in action.option_strings:
            if flag not in ("-h", "--help"):
                assert f"`{flag}`" in cli, f"docs/cli.md lacks global flag `{flag}`"


def test_every_exit_code_in_dots_is_documented(dots):
    source = Path(dots.__file__).read_text()
    codes = set(re.findall(r"^\s+return (\d)\b", source, re.M))
    codes |= set(re.findall(r"return (\d) if ", source))
    codes |= {"2"}                                  # argparse usage errors
    section = text(CLI).split("## Exit status")[1].split("\n## ")[0]
    for code in sorted(codes):
        assert re.search(rf"^\| {code} \|", section, re.M), f"docs/cli.md exit status table lacks {code}"


def test_every_environment_variable_dots_reads_is_documented(dots):
    source = Path(dots.__file__).read_text()
    names = set(re.findall(r'os\.environ(?:\.get)?\[?\(?"([A-Z_]+)"', source))
    section = text(CLI).split("## Environment")[1].split("\n## ")[0]
    for name in sorted(names):
        assert f"`{name}`" in section, f"docs/cli.md environment table lacks `{name}`"


def test_dots_docstring_naming_rules_match_the_concepts_doc(dots):
    for prefix in ("dot_", "private_", "executable_"):
        assert prefix in dots.__doc__
        assert f"`{prefix}`" in text(DOCS / "concepts.md")


# ── knobs, modules, hook files, targets ───────────────────────────────────


def bash_module_files():
    return sorted((REPO / "dot_config" / "bash" / "rc.d").iterdir())


def test_every_bash_knob_read_by_a_module_is_in_the_configuration_doc():
    files = [*bash_module_files(), REPO / "dot_bashrc", REPO / "dot_config" / "bash" / "prompt" / "layout.sh"]
    knobs = set()
    for f in files:
        knobs |= set(re.findall(r"\$\{(DOTFILES_[A-Z_]+)[:-]", f.read_text()))
        knobs |= set(re.findall(r'"\$\{(DOTFILES_[A-Z_]+)-\}"', f.read_text()))
    knobs -= {"DOTFILES_DIR"} | UNDOCUMENTED_ON_PURPOSE
    config = text(CONFIG)
    for knob in sorted(knobs):
        assert f"`{knob}`" in config, f"docs/configuration.md lacks knob `{knob}`"


def test_every_bash_knob_is_declared_in_its_module_header():
    """The module's own header lists what it reads, so the code is self-documenting."""
    for f in bash_module_files():
        body = f.read_text()
        header = body.split("\n\n")[0]
        read = set(re.findall(r"\$\{(DOTFILES_[A-Z_]+)[:-]", body)) - {"DOTFILES_DIR", "DOTFILES_BASH_DIR", "DOTFILES_DEBUG"}
        for knob in sorted(read):
            assert knob in header, f"{f.name} reads {knob} but its header does not list it"


def test_every_vim_knob_is_in_the_configuration_doc():
    knobs = set()
    for f in [REPO / "dot_vimrc", *(REPO / "dot_vim" / "rc").iterdir()]:
        knobs |= set(re.findall(r"g:(dotfiles_[a-z_]+)", f.read_text()))
    config = text(CONFIG)
    for knob in sorted(knobs):
        assert f"`g:{knob}`" in config, f"docs/configuration.md lacks vim knob `g:{knob}`"


@pytest.mark.parametrize("directory", [
    "dot_config/bash/rc.d", "dot_vim/rc", "dot_config/tmux/conf.d", "dot_config/git",
])
def test_every_module_file_has_a_row_in_the_configuration_doc(directory):
    config = text(CONFIG)
    for f in sorted((REPO / directory).iterdir()):
        if f.is_file():
            assert f"`{f.name}`" in config, f"docs/configuration.md lacks a row for {directory}/{f.name}"


def test_every_hook_file_a_loader_reads_is_in_the_configuration_doc():
    loaders = [REPO / n for n in ("dot_bashrc", "dot_bash_profile", "dot_vimrc", "dot_tmux.conf", "dot_gitconfig")]
    loaders += [REPO / "dot_config/bash/rc.d/90-local.sh", REPO / "dot_config/bash/rc.d/50-completion.sh",
                REPO / "private_dot_ssh/config"]
    hooks = set()
    for f in loaders:
        body = f.read_text()
        hooks |= set(re.findall(r"~/\.[a-z_]+\.(?:before|local)", body))
        hooks |= set(re.findall(r"~/\.config/bash/(?:disabled|profile\.d|completion\.d)", body))
        hooks |= set(re.findall(r"~/\.ssh/config\.(?:local|d)", body))
    section = text(CONFIG).split("## Hook files")[1].split("\n## ")[0]
    for hook in sorted(hooks):
        assert f"`{hook}" in section, f"docs/configuration.md hook table lacks `{hook}`"


def test_every_top_level_target_is_in_the_configuration_doc(dots, home):
    config = text(CONFIG)
    tops = {e.rel.split("/")[0] for e in dots.managed_entries(REPO, home)}
    for top in sorted(tops):
        if top == ".config":
            continue                                       # its subdirectories are covered by the module tables
        assert f"~/{top}" in config, f"docs/configuration.md lacks the target ~/{top}"


def test_bash_modules_named_in_integration_test_match_the_tree():
    from test_config_integration import BASH_MODULES, VIM_MODULES
    on_disk = [f.name[3:-3] for f in bash_module_files() if f.name.endswith(".sh")]
    assert on_disk == BASH_MODULES
    vim_on_disk = [f.name[:-4] for f in sorted((REPO / "dot_vim" / "rc").iterdir()) if f.name.endswith(".vim")]
    assert vim_on_disk == VIM_MODULES


# ── README ────────────────────────────────────────────────────────────────


def test_readme_is_short():
    assert len(text(README).splitlines()) <= README_MAX_LINES


def test_readme_examples_are_the_recorded_catalog_cases():
    readme = text(README)
    blocks = re.findall(r"<!-- example: ([\w/-]+) -->\n```sh\n(.*?)```\n```text\n(.*?)```", readme, re.S)
    assert blocks, "README has no <!-- example: --> blocks"
    for case_id, script, output in blocks:
        case = REPO / "tests" / "examples" / case_id
        assert case.is_dir(), f"README example {case_id} is not a catalog case"
        expected_script = "".join(l for l in (case / "case.sh").read_text().splitlines(True)
                                  if not l.startswith("# source:"))
        assert script == expected_script, f"README example {case_id}: commands differ from case.sh"
        assert output == (case / "expected.txt").read_text(), f"README example {case_id}: output differs from expected.txt"


def test_every_doc_is_linked_from_the_readme():
    readme = text(README)
    for doc in sorted(DOCS.glob("*.md")):
        assert f"(docs/{doc.name})" in readme, f"README does not link docs/{doc.name}"
    assert "(tests/examples/README.md)" in readme


def test_no_dead_internal_links():
    for md in [README, *DOCS.glob("*.md"), REPO / "tests" / "examples" / "README.md"]:
        for target in re.findall(r"\]\(([^)]+)\)", md.read_text()):
            if target.startswith(("http://", "https://")):
                continue
            path, _, anchor = target.partition("#")
            resolved = (md.parent / path).resolve() if path else md
            assert resolved.exists(), f"{md.relative_to(REPO)}: dead link {target}"
            if anchor and resolved.suffix == ".md":
                headings = re.findall(r"^#+ (.+)$", resolved.read_text(), re.M)
                slugs = {re.sub(r"[^a-z0-9 -]", "", h.lower()).replace(" ", "-") for h in headings}
                assert anchor in slugs, f"{md.relative_to(REPO)}: dead anchor {target}"


def test_readme_names_every_subcommand_or_points_to_the_reference(dots):
    readme = text(README)
    assert "(docs/cli.md)" in readme
    for name in subparsers(build_parser(dots)):
        assert name in all_docs_text()
