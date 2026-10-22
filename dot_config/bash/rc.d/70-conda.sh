# 70-conda.sh: conda, found rather than hard-coded, silent when absent.
#
# Sources <root>/etc/profile.d/conda.sh, which is what `conda init` would
# paste into ~/.bashrc minus its `conda shell.bash hook`, a process that
# costs about a second per shell. Base is not activated at start (that is
# ~/.condarc); `conda activate NAME` as usual.
#
# Fast mode (05-fast.sh): the activation of DOTFILES_CONDA_ENV at start is
# kept from the last start and replayed, while conda, the environment and
# PATH stay as they were, instead of running conda (a python start).
#
# Each setting has its description in the comment above it. A setting with
# "#" directly in front of it is off: delete that "#" to turn it on, or add
# one to turn a setting off. `dots options WORD` searches every file.
# For one machine only, put the line in ~/.bashrc.local instead.
#
# Knobs (set in ~/.bashrc.before):
#   DOTFILES_CONDA_ROOT   explicit install root       default: first found of the list below
#   DOTFILES_CONDA_ENV    environment to activate     default: none

# In fast mode, activate DOTFILES_CONDA_ENV from what `conda activate`
# printed at an earlier start (dots_eval_cached, 00-env.sh), kept while
# conda and the environment's conda-meta/history (every install and
# removal writes it) keep their times, and PATH and PS1 are the same.
# Only from a shell with no environment active, and only for an
# environment found under the root's envs/ or ~/.conda/envs (or given as
# a path); otherwise conda activate as usual. When conda fails, its error
# shows and nothing is kept.
_conda_activate_kept() {
    local env=$DOTFILES_CONDA_ENV prefix="" p
    if [[ $env == */* ]]; then
        prefix=$env
    elif [[ $env == base ]]; then
        prefix=$_conda_root
    else
        for p in "$_conda_root/envs/$env" "$HOME/.conda/envs/$env"; do
            [[ -f $p/conda-meta/history ]] && { prefix=$p; break; }
        done
    fi
    if [[ -z ${CONDA_PREFIX-} && ${CONDA_SHLVL:-0} == 0 && -f $prefix/conda-meta/history && -n ${CONDA_EXE-} ]]; then
        dots_eval_cached -f "$CONDA_EXE" -f "$prefix/conda-meta/history" -k "conda.${env//\//_}" \
            env "PATH=$PATH" "PS1=${PS1-}" "$CONDA_EXE" shell.posix activate "$env" || return 0
        source "$REPLY"
        hash -r
    else
        conda activate "$env"
    fi
}

# Find conda: the knob's root, else the usual install places. mamba's
# shell functions too, when installed. The knob's environment is
# activated here, before 80-tools.sh: Homebrew, mise, asdf or pyenv set up
# there come before it on PATH.
for _conda_root in "${DOTFILES_CONDA_ROOT-}" \
                   "$HOME/miniconda3" "$HOME/anaconda3" "$HOME/miniforge3" "$HOME/mambaforge" \
                   /opt/anaconda3 /opt/miniconda3 /opt/miniforge3 /opt/conda; do
    [[ -n "$_conda_root" && -x "$_conda_root/bin/conda" ]] || continue
    if [[ -r "$_conda_root/etc/profile.d/conda.sh" ]]; then
        source "$_conda_root/etc/profile.d/conda.sh"
    else
        eval "$("$_conda_root/bin/conda" shell.bash hook 2>/dev/null)"
    fi
    [[ -r "$_conda_root/etc/profile.d/mamba.sh" ]] && source "$_conda_root/etc/profile.d/mamba.sh"
    if [[ -n "${DOTFILES_CONDA_ENV-}" ]]; then
        if [[ ${DOTS_FAST_ACTIVE-} == 1 ]]; then _conda_activate_kept; else conda activate "$DOTFILES_CONDA_ENV"; fi
    fi
    break
done
unset _conda_root

# ca NAME: conda activate; cda: conda deactivate; cel: list environments.
if declare -F conda >/dev/null; then
    alias ca='conda activate' cda='conda deactivate' cel='conda env list'
fi
