# 75-python.sh: python conveniences. $PYTHONSTARTUP and the bytecode
# settings are in 00-env.sh. Nothing here when python3 is missing.
#
#   venv [DIR]   create DIR (default .venv) if missing, then activate it
#   deactivate   leave it (defined by the venv itself)
#
# Each setting has its description in the comment above it. A setting with
# "#" directly in front of it is off: delete that "#" to turn it on, or add
# one to turn a setting off. `dots options WORD` searches every file.
# For one machine only, put the line in ~/.bashrc.local instead.
#
# Knobs (set in ~/.bashrc.before):
#   DOTFILES_VENV_DIR    default venv directory name   default: .venv

# Nothing to do without python3.
command -v python3 >/dev/null || return 0

# py: python3; pyv: its version.
alias py='python3'
alias pyv='python3 --version'



# json: pretty-print JSON from stdin or a file:  curl -s URL | json
alias json='python3 -m json.tool'

# pt: pytest through the active python, quiet.
alias pt='python3 -m pytest -q'

# venv [DIR]: create DIR (default .venv, or the knob) if missing, then activate it.
venv() {
    local dir="${1:-${DOTFILES_VENV_DIR:-.venv}}"
    [[ -d "$dir" ]] || python3 -m venv "$dir" || return
    # shellcheck disable=SC1091
    source "$dir/bin/activate"
}

# The function for the setting below: activate ./.venv when there is one,
# deactivate after leaving its project. A venv activated by hand is left
# alone. Hands the exit status on for the prompt.
_venv_auto() {
    local status=$? dir="${DOTFILES_VENV_DIR:-.venv}"
    if [[ -f "$dir/bin/activate" && "${VIRTUAL_ENV-}" != "$PWD/$dir"
            && ( -z "${VIRTUAL_ENV-}" || "$VIRTUAL_ENV" == "${_venv_auto_env-}" ) ]]; then
        source "$dir/bin/activate"
        _venv_auto_env=$VIRTUAL_ENV
    elif [[ -n "${VIRTUAL_ENV-}" && "$VIRTUAL_ENV" == "${_venv_auto_env-}"
            && "$PWD/" != "${VIRTUAL_ENV%/*}/"* ]]; then
        deactivate
        unset _venv_auto_env
    fi
    return "$status"
}

# Activate a project's .venv on entering it and deactivate on leaving,
# checked at every prompt (one file test each).
#[[ "${PROMPT_COMMAND-}" == *_venv_auto* ]] || PROMPT_COMMAND="_venv_auto${PROMPT_COMMAND:+; $PROMPT_COMMAND}"

# pip refuses to install anything outside a virtual environment, so
# nothing lands in the system or user site by mistake. A conda environment
# does not count: pip refuses there too. Once, anywhere:
# PIP_REQUIRE_VIRTUALENV=0 pip install ...
#export PIP_REQUIRE_VIRTUALENV=true

# breakpoint() opens ipdb (IPython's debugger: colors, Tab completion)
# instead of pdb. Needs the ipdb package in the environment that runs.
#export PYTHONBREAKPOINT=ipdb.set_trace

# The plain REPL of python 3.12 and older in 3.13+: the new one ignores
# readline, so ~/.inputrc and pythonrc.py's completion setup do nothing there.
#export PYTHON_BASIC_REPL=1

# ipy: IPython, when installed.
#command -v ipython >/dev/null && alias ipy='ipython'

# jl / jn: Jupyter Lab / Notebook in this directory, when installed.
#command -v jupyter >/dev/null && alias jl='jupyter lab' jn='jupyter notebook'

# uv's own Tab completion, when uv is installed (a few ms per shell).
#command -v uv >/dev/null && eval "$(uv generate-shell-completion bash)"
