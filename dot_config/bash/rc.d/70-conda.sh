# 70-conda.sh -- conda, found rather than hard-coded, silent when absent.
#
# Sources <root>/etc/profile.d/conda.sh, which is what `conda init` would
# paste into ~/.bashrc, minus the ~1 s `conda shell.bash hook` fork.  Base is
# not auto-activated (that is in ~/.condarc); `conda activate NAME` as usual.
#
# Knobs (set in ~/.bashrc.before):
#   DOTFILES_CONDA_ROOT   explicit install root       default: first found of the list below
#   DOTFILES_CONDA_ENV    environment to activate     default: none

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
