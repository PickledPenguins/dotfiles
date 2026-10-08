# SECURITY: text the segments print must reach the screen as typed. A
# directory name, git branch, VIRTUAL_ENV path, tmux session name, $USER,
# or $HOSTNAME can hold $(...), backticks or backslash escapes; bash
# decodes backslash escapes in PS1 on every render, and with promptvars on
# (the bash default) it also runs command substitutions.
#
# v0.1.1 turned promptvars off for the whole shell. That closed $(...) but
# not \w, \[ or \D{...}, and it broke other users of the option: kitty's
# shell integration puts $(...) in PS0, which then printed literally.
# Since v0.1.6 promptvars stays on and _ps_expand escapes every segment's
# output (_ps_escape_into). These tests guard both halves.

load test_helper

setup() {
    load_prompt_lib
}

@test "promptvars stays on, so a PS0 holding \$(...) still expands (kitty's shell integration)" {
    PS0='$(printf ran)'
    [[ "${PS0@P}" == "ran" ]]
}

@test "[SECURITY] a segment's \$(...), backticks, \$ and backslash escapes render as typed" {
    marker="$BATS_TEST_TMPDIR/PWNED"
    hostile='a\wb \[x\] \n $HOME ${PATH} \$ $(touch '"$marker"') `touch '"$marker"'` z\'
    _test_hostile() { printf '%s' "$hostile"; }
    prompt_segment hostile _test_hostile
    PS1=$(_ps_expand '@hostile' 300)
    [[ "${PS1@P}" == "$hostile" ]]
    [[ ! -f "$marker" ]]
}

@test "[SECURITY] a \$ in a segment renders as \$ for root, not as the # prompt sign" {
    unshare -r true 2>/dev/null || skip "unshare -r (user namespaces) not available"
    run unshare -r bash -c '
        source "$DOTFILES_ROOT/prompt.sh"
        _test_cost() { printf "%s" "cost \$5"; }
        prompt_segment cost _test_cost
        PS1="$(_ps_expand "@cost \\$" 100)"
        printf "%s|%s" "$EUID" "${PS1@P}"'
    [ "$output" = '0|cost $5 #' ]
}

@test "a row without @fill is padded to the width of the text as shown, not as escaped" {
    _test_slashes() { printf '%s' 'a\b$c`d'; }
    prompt_segment slashes _test_slashes
    prompt_layout --box --closed one two
    prompt_row one '@slashes'
    prompt_row two 'x'
    COLUMNS=40 prompt_build
    rendered=$(plain "${PS1@P}")
    first=${rendered%%$'\n'*}
    [[ "$first" == *'a\b$c`d'* ]]
    [ "$(str_width "$first")" -eq 40 ]
}

@test "[SECURITY] a malicious directory name does not execute when the real prompt is rendered (end-to-end, requires 'script')" {
    command -v script >/dev/null || skip "'script' (util-linux) not available for a real PTY"

    marker="$BATS_TEST_TMPDIR/PWNED"
    evil_dir="$BATS_TEST_TMPDIR/proj_\$(touch\$IFS${marker})_x"
    mkdir -p "$evil_dir"

    probe="$BATS_TEST_TMPDIR/probe.sh"
    cat > "$probe" << PROBE
cd '$DOTFILES_ROOT'
source ./lib/colors.sh; source ./lib/term_utils.sh
source ./lib/git_info.sh; source ./prompt.sh
source ./prompt_example.sh
cd '$evil_dir'
PROMPT_COMMAND=prompt_build
PROBE

    typescript="$BATS_TEST_TMPDIR/typescript.log"
    script -qec "bash --rcfile '$probe' -i" "$typescript" << 'INPUT'
echo hi
exit
INPUT

    # poll briefly instead of a fixed sleep -- PTY teardown timing varies
    for _ in 1 2 3 4 5 6 7 8 9 10; do
        [[ -f "$marker" ]] && break
        sleep 0.2
    done

    [[ ! -f "$marker" ]]
}

@test "[SECURITY] a malicious VIRTUAL_ENV path does not execute via the venv segment (mechanism-level check)" {
    cd "$BATS_TEST_TMPDIR"   # so a slash-free marker filename resolves predictably
    export VIRTUAL_ENV='/tmp/venv_$(touch$IFSPWNED_VENV)_x'
    out="$(_ps_seg_venv)"
    # The segment prints the raw text; _ps_expand escapes it, for every
    # segment alike (tested above). Nothing here neutralizes the payload,
    # and calling the segment does not run it.
    [[ "$out" == *'$(touch'* ]]
    [[ ! -f "PWNED_VENV" ]]
}

@test "@fill in a segment's output renders as typed, not as the spacer" {
    _test_dirname() { printf '%s' 'x@filly'; }
    prompt_segment dirname _test_dirname
    PS1=$(_ps_expand '@dirname@fill|' 20)
    [[ "${PS1@P}" == "x@filly$(str_repeat '─' 12)|" ]]
}

@test "sourcing prompt.sh by a relative path ignores CDPATH" {
    mkdir -p "$BATS_TEST_TMPDIR/cdp/${DOTFILES_ROOT##*/}"
    cd "${DOTFILES_ROOT%/*}"
    run env CDPATH="$BATS_TEST_TMPDIR/cdp" PS_SKIP_DEBUG_TRAP=1 bash -c \
        'source "$1/prompt.sh" && printf "%s|%s" "$(type -t _ps_seg_pwd)" "$(type -t git_info_refresh)"' _ "${DOTFILES_ROOT##*/}"
    [ "$output" = "function|function" ]
}
