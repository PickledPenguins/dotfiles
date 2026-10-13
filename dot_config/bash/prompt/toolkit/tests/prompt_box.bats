load test_helper

setup() {
    load_prompt_lib
    _solo() { printf 'X'; }
    prompt_segment solo _solo
    COLUMNS=40
}

@test "single-row OPEN box: cursor follows content, no stray top-right corner" {
    prompt_row r1 '@solo \$ '
    prompt_layout --box rounded r1
    prompt_build
    [[ "$PS1" == *'\$'* ]]
    [[ "$PS1" != *"╮"* ]]   # no top-right corner should leak in for an open single row
}

@test "single-row CLOSED box: seals with bottom-right corner and a real prompt escape" {
    prompt_row r1 '@solo'
    prompt_layout --box rounded --closed r1
    prompt_build
    [[ "$PS1" == *'\$'* ]]
    [[ "$PS1" == *"╯"* ]]
}

@test "multi-row OPEN box: last row still has no right corner (unchanged convention)" {
    prompt_row r1 '@solo'
    prompt_row r2 '@solo \$ '
    prompt_layout --box rounded r1 r2
    prompt_build
    [[ "$PS1" == *'\$'* ]]
}

@test "multi-row CLOSED box: still seals correctly (regression check)" {
    prompt_row r1 '@solo'
    prompt_row r2 '@solo'
    prompt_layout --box rounded --closed r1 r2
    prompt_build
    [[ "$PS1" == *"╯"* ]]
    [[ "$PS1" == *'\$'* ]]
}

@test "box with @fill correctly pads between two segments" {
    prompt_row r1 '[@solo]@fill[@solo]'
    prompt_layout --box rounded --closed r1
    prompt_build
    plain_ps1="$(strip_ansi "$PS1")"
    [[ "$plain_ps1" == *"[X]"*"[X]"* ]]
}

@test "prompt_layout is idempotent: calling it twice does not double-prepend prompt_build" {
    prompt_row r1 '@solo'
    prompt_layout --box rounded r1
    prompt_layout --box rounded r1
    count=$(grep -o "prompt_build" <<< "$PROMPT_COMMAND" | wc -l)
    [[ "$count" -eq 1 ]]
}

@test "prompt_layout finds prompt_build behind a bare ';' or a newline, not in prompt_buildx" {
    prompt_row r1 '@solo'
    PROMPT_COMMAND="foo"
    prompt_layout r1
    PROMPT_COMMAND="foo;$PROMPT_COMMAND"
    prompt_layout r1
    [[ "$PROMPT_COMMAND" == "foo;prompt_build; foo" ]]
    PROMPT_COMMAND=$'foo\nprompt_build'
    prompt_layout r1
    [[ "$PROMPT_COMMAND" == $'foo\nprompt_build' ]]
    PROMPT_COMMAND="prompt_buildx"
    prompt_layout r1
    [[ "$PROMPT_COMMAND" == "prompt_build; prompt_buildx" ]]
}

@test "no-box layout joins rows with real newlines, not box borders" {
    prompt_row r1 '@solo'
    prompt_row r2 '@solo'
    prompt_layout r1 r2
    prompt_build
    [[ "$PS1" != *"╭"* ]]
    [[ "$PS1" != *"│"* ]]
}

@test "prompt_layout --box takes the next word as the style only when it names one" {
    prompt_layout --box r1 r2
    [[ "$_PS_STYLE" == "rounded" ]]
    [[ "${_PS_ORDER[*]}" == "r1 r2" ]]
    prompt_layout --box sharp r1
    [[ "$_PS_STYLE" == "sharp" ]]
    [[ "${_PS_ORDER[*]}" == "r1" ]]
}

# ── v0.1.8: a row whose segments all print nothing is left out ────────────

@test "box: a row whose segments all print nothing is left out, not drawn blank" {
    _none() { :; }
    prompt_segment none _none
    prompt_row r1 '@solo'
    prompt_row r2 ' -> @none  @none'
    prompt_row r3 '@solo \$ '
    prompt_layout --box rounded r1 r2 r3
    prompt_build
    [[ "$PS1" != *'->'* ]]
    [[ "$PS1" == "╭X"*"╮\\n╰X \\\$ " ]]
}

@test "box: the top corners move to the first row left" {
    _none() { :; }
    prompt_segment none _none
    prompt_row r1 '[ @none ]'
    prompt_row r2 '@solo'
    prompt_row r3 '@solo \$ '
    prompt_layout --box rounded r1 r2 r3
    prompt_build
    [[ "$PS1" != *'['* ]]
    [[ "$PS1" == "╭X"*"╮\\n╰X \\\$ " ]]
}

@test "box: a row with one segment showing, or no segment at all, is kept" {
    _none() { :; }
    prompt_segment none _none
    prompt_row r1 '@none|@solo'
    prompt_row r2 '----'
    prompt_row r3 '@solo \$ '
    prompt_layout --box rounded r1 r2 r3
    prompt_build
    [[ "$PS1" == *'|X'* ]]
    [[ "$PS1" == *'│----'* ]]
}

@test "the last row is kept when its segments print nothing: it holds the prompt" {
    _none() { :; }
    prompt_segment none _none
    prompt_row r1 '@solo'
    prompt_row r2 '@none \$ '
    prompt_layout --box rounded r1 r2
    prompt_build
    [[ "$PS1" == *'╰ \$ ' ]]
}

@test "no box: a row whose segments all print nothing is left out" {
    _none() { :; }
    prompt_segment none _none
    prompt_row r1 '@solo'
    prompt_row r2 '<@none>'
    prompt_row r3 '@solo \$ '
    prompt_layout r1 r2 r3
    prompt_build
    [[ "$PS1" == 'X\nX \$ ' ]]
}

@test "_ps_expand_into flags a row only when it names segments and none showed" {
    _none() { :; }
    prompt_segment none _none
    _ps_expand_into '<@none>' 40;  [ "$_PS_EXPANDED" = '<>' ];   [ "$_PS_EXPANDED_EMPTY" -eq 1 ]
    _ps_expand_into '@none@solo' 40;                              [ "$_PS_EXPANDED_EMPTY" -eq 0 ]
    _ps_expand_into 'plain' 40;                                   [ "$_PS_EXPANDED_EMPTY" -eq 0 ]
    # Color codes around no text show nothing either.
    _bare() { printf '%s%s' "$PS_GREEN" "$PS_R"; }
    prompt_segment bare _bare
    _ps_expand_into '<@bare>' 40;                                 [ "$_PS_EXPANDED_EMPTY" -eq 1 ]
}

# ── v0.1.10: --sides draws only the edges named ───────────────────────────
# COLUMNS=10. A rail takes one column; rows fill out only where an edge
# needs it, so a left rail alone leaves no trailing spaces.

_three_rows() {
    prompt_row r1 '@solo'
    prompt_row r2 '@solo'
    prompt_row r3 '@solo \$ '
    COLUMNS=10
}

@test "--box and --closed draw exactly what they drew before --sides" {
    _three_rows
    prompt_layout --box r1 r2 r3;           prompt_build
    [ "$PS1" = '╭X───────╮\n│X       │\n╰X \$ ' ]
    prompt_layout --box --closed r1 r2 r3;  prompt_build
    [ "$PS1" = '╭X───────╮\n│X       │\n╰X \$ ───╯'$'\n''\$ ' ]
    prompt_layout --box --closed r1;        prompt_build
    [ "$PS1" = '╭X───────╯'$'\n''\$ ' ]
}

@test "--sides l: a left rail with its corners, no fill" {
    _three_rows
    prompt_layout --sides l r1 r2 r3
    prompt_build
    [ "$PS1" = '╭X\n│X\n╰X \$ ' ]
}

@test "--sides l,b: the last row filled with ─, the cursor on a new line" {
    _three_rows
    prompt_layout --sides l,b r1 r2 r3
    prompt_build
    [ "$PS1" = '╭X\n│X\n╰X \$ ────'$'\n''\$ ' ]
}

@test "--sides tl: the first row filled with ─ to full width" {
    _three_rows
    prompt_layout --sides tl r1 r2 r3
    prompt_build
    [ "$PS1" = '╭X────────\n│X\n╰X \$ ' ]
}

@test "--sides r: rows filled with spaces up to the right rail" {
    _three_rows
    prompt_layout --sides r r1 r2 r3
    prompt_build
    [ "$PS1" = 'X        ╮\nX        │\nX \$ ' ]
}

@test "--sides b alone: no rail, no corner, the last row filled" {
    _three_rows
    prompt_layout --sides b r1 r3
    prompt_build
    [ "$PS1" = 'X\nX \$ ─────'$'\n''\$ ' ]
}

@test "--sides on a single row takes the top-left corner" {
    _three_rows
    prompt_layout --sides lb r3
    prompt_build
    [ "$PS1" = '╭X \$ ────'$'\n''\$ ' ]
    prompt_layout --sides l r3
    prompt_build
    [ "$PS1" = '╭X \$ ' ]
}

@test "--box is --sides trl, --closed adds b, and the order does not matter" {
    _three_rows
    prompt_layout --sides trl r1 r2 r3;  prompt_build;  local sides=$PS1
    prompt_layout --box r1 r2 r3;        prompt_build
    [ "$PS1" = "$sides" ]
    prompt_layout --closed --box r1 r3;  prompt_build;  local closed=$PS1
    prompt_layout --sides r,l,t,b r1 r3; prompt_build
    [ "$PS1" = "$closed" ]
    [ "$_PS_SIDES" = trbl ]
    prompt_layout --sides l --closed r1;  [ "$_PS_SIDES" = bl ]
}

@test "--box STYLE with --sides draws those edges in that style" {
    _three_rows
    prompt_layout --box sharp --sides l r1 r3
    prompt_build
    [ "$PS1" = '┌X\n└X \$ ' ]
}

@test "--no-box after --sides turns the box off" {
    _three_rows
    prompt_layout --sides l --no-box r1 r3
    prompt_build
    [ "$PS1" = 'X\nX \$ ' ]
    [ "$_PS_SIDES" = "" ]
    # and forgets them: a --box after it draws the --box edges
    prompt_layout --sides l --no-box --box r1 r3
    [ "$_PS_SIDES" = "trl" ]
}

@test "--sides with a bad letter, a row name or nothing: an error, layout kept" {
    _three_rows
    prompt_layout --sides lb r1 r3
    run prompt_layout --sides lx r1
    [ "$status" -eq 1 ]
    [ "$output" = "prompt_layout: --sides 'lx': use the letters t, r, b and l" ]
    run prompt_layout --sides r1
    [ "$output" = "prompt_layout: --sides 'r1': use the letters t, r, b and l" ]
    run prompt_layout --sides
    [ "$status" -eq 1 ]
    prompt_layout --sides l,x r2 || true
    [ "$_PS_SIDES" = bl ]
    [ "${_PS_ORDER[*]}" = "r1 r3" ]
}

@test "prompt_debug shows the edges drawn" {
    _three_rows
    prompt_layout --sides l,b r1 r3
    run prompt_debug
    [[ "${lines[0]}" == "=== prompt.sh  box=1  sides=bl  style=rounded ===" ]]
    prompt_layout r1 r3
    run prompt_debug
    [[ "${lines[0]}" == "=== prompt.sh  box=0  sides=-  style=rounded ===" ]]
}
