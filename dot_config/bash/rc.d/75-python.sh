# 75-python.sh -- python conveniences.  $PYTHONSTARTUP is set in 00-env.sh.
#
#   venv [DIR]     create DIR (default .venv) if missing, then activate it
#   deactivate     as provided by the venv itself
#   py             python3
#   pipup          upgrade every outdated package in the active environment
#
# Knobs (set in ~/.bashrc.before):
#   DOTFILES_VENV_DIR    default venv directory name                     default: .venv
#   DOTFILES_VENV_AUTO   1 = activate/deactivate .venv on cd (one stat per prompt)  default: 0

command -v python3 >/dev/null || return 0

alias py='python3'
alias pyv='python3 --version'
alias pipup='python3 -m pip list --outdated --format=freeze | cut -d= -f1 | xargs -r -n1 python3 -m pip install -U'
alias pyclean='find . -type d -name __pycache__ -prune -exec rm -rf {} + ; find . -name "*.pyc" -delete'
alias json='python3 -m json.tool'               # pretty-print:  curl ... | json

venv() {
    local dir="${1:-${DOTFILES_VENV_DIR:-.venv}}"
    [[ -d "$dir" ]] || python3 -m venv "$dir" || return
    # shellcheck disable=SC1091
    source "$dir/bin/activate"
}

# Auto-activate a .venv when entering a directory that has one (and leave it
# when leaving).  Off unless DOTFILES_VENV_AUTO=1: it adds a stat per prompt.
if [[ "${DOTFILES_VENV_AUTO:-0}" == 1 ]]; then
    _venv_auto() {
        local dir="${DOTFILES_VENV_DIR:-.venv}"
        if [[ -f "$dir/bin/activate" && "$VIRTUAL_ENV" != "$PWD/$dir" ]]; then
            source "$dir/bin/activate"
        elif [[ -n "${VIRTUAL_ENV-}" && "$PWD" != "${VIRTUAL_ENV%/*}"* ]]; then
            deactivate
        fi
    }
    PROMPT_COMMAND="_venv_auto${PROMPT_COMMAND:+;$PROMPT_COMMAND}"
fi
