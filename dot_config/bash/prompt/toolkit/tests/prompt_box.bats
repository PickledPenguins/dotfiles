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
