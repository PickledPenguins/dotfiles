# Conda -- equivalent of the block `conda init` writes, but finds the
# install instead of hard-coding it, and stays silent when there is none.

for _conda_root in "$HOME/miniconda3" "$HOME/anaconda3" "$HOME/miniforge3" \
                   /opt/anaconda3 /opt/miniconda3 /opt/conda; do
    [[ -x "$_conda_root/bin/conda" ]] || continue
    # conda.sh is what `conda shell.bash hook` prints; sourcing it directly
    # skips a ~1 s python start-up on every new shell.
    if [[ -r "$_conda_root/etc/profile.d/conda.sh" ]]; then
        source "$_conda_root/etc/profile.d/conda.sh"
    else
        eval "$("$_conda_root/bin/conda" shell.bash hook 2>/dev/null)"
    fi
    break
done
unset _conda_root
