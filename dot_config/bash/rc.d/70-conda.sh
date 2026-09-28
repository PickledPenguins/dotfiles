# 70-conda.sh -- conda, found rather than hard-coded, silent when absent.
#
# Sources <root>/etc/profile.d/conda.sh, which is what `conda init` would
# paste into ~/.bashrc minus its `conda shell.bash hook`, a process that
# costs about a second per shell.  Base is not activated at start (that is
# ~/.condarc); `conda activate NAME` as usual.
#
# Each setting has its description in the comment above it.  A setting with
# "#" directly in front of it is off: delete that "#" to turn it on, or add
# one to turn a setting off.  `dots options WORD` searches every file.
# For one machine only, put the line in ~/.bashrc.local instead.
#
# Knobs (set in ~/.bashrc.before):
#   DOTFILES_CONDA_ROOT   explicit install root       default: first found of the list below
#   DOTFILES_CONDA_ENV    environment to activate     default: none

# Find conda: the knob's root, else the usual install places.  mamba's
# shell functions too, when installed.  The knob's environment is
# activated.
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
    [[ -n "${DOTFILES_CONDA_ENV-}" ]] && conda activate "$DOTFILES_CONDA_ENV"
    break
done
unset _conda_root

# ca NAME: conda activate; cda: conda deactivate; cel: list environments.
if declare -F conda >/dev/null; then
    alias ca='conda activate' cda='conda deactivate' cel='conda env list'
fi
