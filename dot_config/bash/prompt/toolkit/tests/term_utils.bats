load test_helper

setup() {
    source "$DOTFILES_ROOT/lib/term_utils.sh"
}

@test "strip_ansi removes SGR color codes" {
    [[ "$(strip_ansi $'\033[31mred\033[0m')" == "red" ]]
}

@test "strip_ansi removes readline \\001..\\002 markers" {
    [[ "$(strip_ansi $'\001\033[31m\002red\001\033[0m\002')" == "red" ]]
}

@test "strip_ansi removes cursor-movement CSI sequences (not just SGR/erase-line)" {
    [[ "$(strip_ansi $'a\033[10;20Hb')" == "ab" ]]
}

@test "strip_ansi removes OSC/BEL sequences (e.g. terminal title)" {
    [[ "$(strip_ansi $'before\033]0;title\007after')" == "beforeafter" ]]
}

@test "strip_ansi: plain text with no codes passes through unchanged" {
    [ "$(strip_ansi "plain text, no codes")" = "plain text, no codes" ]
}

@test "str_width counts ASCII length correctly" {
    [[ "$(str_width 'hello')" == "5" ]]
}

@test "str_width counts multi-byte UTF-8 as code points, not bytes" {
    [[ "$(str_width 'café')" == "4" ]]
}

@test "str_repeat produces the requested count" {
    [[ "$(str_repeat '-' 5)" == "-----" ]]
}

@test "str_repeat with a multi-byte character repeats the character, not its bytes" {
    [[ "$(str_repeat '─' 3)" == "───" ]]
}

@test "str_repeat with count 0 or below produces empty output" {
    [[ "$(str_repeat '-' 0)" == "" ]]
    [[ "$(str_repeat '-' -3)" == "" ]]
}

@test "str_repeat: ampersand repeats literally, not as spaces" {
    [ "$(str_repeat '&' 4)" = "&&&&" ]
}

@test "str_width counts code points without wc or a UTF-8 locale (RHEL 7 has no C.UTF-8)" {
    (
        PATH=/nonexistent LC_ALL=C
        [[ "$(str_width '─╭⎇é')" == "4" ]]
    )
}

@test "strip_ansi and str_repeat fork no sed or awk" {
    # A PATH with no sed/awk on it — the old implementations would fail
    # outright; the fork-free versions don't touch PATH at all.
    run bash -c "
        source '$DOTFILES_ROOT/lib/term_utils.sh'
        export PATH=/nonexistent
        strip_ansi \$'\033[31mred\033[0m' && str_repeat '=' 3
    "
    [ "$status" -eq 0 ]
    [ "$output" = "red===" ]
}
