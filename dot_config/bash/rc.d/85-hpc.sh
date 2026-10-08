# 85-hpc.sh -- PBS Pro, Slurm and Environment Modules shortcuts.  Every
# block checks for its scheduler's commands first, so on a workstation this
# file defines nothing.
#
#   PBS      qs   my queued/running jobs     qw   watch them
#            qi   qstat -f JOBID             qd   qdel
#   Slurm    sq   my jobs                    sw   watch them
#            si   scontrol show job          sc   scancel
#            sn   node/partition summary     sacct-today
#   modules  ml   module                     mla  module avail
#
# Each setting has its description in the comment above it.  A setting with
# "#" directly in front of it is off: delete that "#" to turn it on, or add
# one to turn a setting off.  `dots options WORD` searches every file.
# For one machine only, put the line in ~/.bashrc.local instead.
#
# Knobs (set in ~/.bashrc.before):
#   DOTFILES_HPC_WATCH   refresh seconds for qw/sw   default: 10

# Seconds between refreshes for qw and sw (the knob).
_hpc_watch="${DOTFILES_HPC_WATCH:-10}"

# ── PBS Pro ───────────────────────────────────────────────────────────────

# qs my jobs, qsa every job, qw watch mine, qi JOBID full details, qd JOBID
# delete, qn node states, qh my finished jobs too (PBS Pro's -x).
if command -v qstat >/dev/null; then
    alias qs='qstat -u "$USER"'
    alias qsa='qstat -a'
    alias qw="watch -n $_hpc_watch qstat -u \"\$USER\""
    alias qi='qstat -f'
    alias qd='qdel'
    alias qn='pbsnodes -aS 2>/dev/null || pbsnodes -a'
    alias qh='qstat -x -u "$USER"'
fi

# qtail JOBID -- follow the output file of a running PBS job.  qstat wraps a
# long path onto tab-indented lines, joined here first.  The file fills as
# the job runs only when the job writes it in place (qsub -k oed, or a site
# with direct write); otherwise PBS keeps the output on the execution host
# and copies it there when the job ends.
command -v qstat >/dev/null && qtail() { tail -f "$(qstat -f "$1" | sed -e ':a;N;$!ba;s/\n\t//g' | sed -n 's/.*Output_Path = [^:]*:\(.*\)/\1/p')"; }

# qint: an interactive job with X forwarding.  The resources are an example;
# every site's queues and limits differ.
#command -v qsub >/dev/null && alias qint='qsub -I -X -l select=1:ncpus=4:mem=8gb -l walltime=01:00:00'

# ── Slurm ─────────────────────────────────────────────────────────────────

# sq my jobs, sqa every job, sw watch mine, si JOBID details, sc JOBID
# cancel, sn partitions and node states, sacct-today what ran today,
# sstart when pending jobs are expected to start.
if command -v squeue >/dev/null; then
    alias sq='squeue -u "$USER" -o "%.10i %.9P %.20j %.8T %.10M %.10l %.6D %R"'
    alias sqa='squeue -o "%.10i %.9P %.20j %.8u %.8T %.10M %.6D %R"'
    alias sw="watch -n $_hpc_watch squeue -u \"\$USER\""
    alias si='scontrol show job'
    alias sc='scancel'
    alias sn='sinfo -o "%.12P %.5a %.10l %.6D %.6t %N"'
    alias sacct-today='sacct -u "$USER" -S today -o JobID,JobName%20,State,Elapsed,MaxRSS,ExitCode'
    alias sstart='squeue -u "$USER" --start'
fi

# srun-i [ARGS] -- an interactive login shell on a compute node.
command -v srun >/dev/null && srun-i() { srun --pty "$@" "${SHELL:-bash}" -l; }

# Plain squeue and sacct use these columns, as sq and sacct-today do.
#export SQUEUE_FORMAT="%.10i %.9P %.20j %.8u %.8T %.10M %.10l %.6D %R"
#export SACCT_FORMAT="JobID,JobName%20,Partition,State,Elapsed,MaxRSS,ExitCode"

# sint: an interactive allocation.  The resources are an example; every
# site's partitions and limits differ.
#command -v salloc >/dev/null && alias sint='salloc --nodes=1 --ntasks=1 --cpus-per-task=4 --time=01:00:00'

# ── Environment Modules / Lmod ────────────────────────────────────────────

# ml module, mla avail, mll list, mlp purge, mls spider (Lmod's search).
# Lmod's own ml function, which also loads (`ml gcc`), is left in place.
if command -v module >/dev/null 2>&1 || declare -F module >/dev/null; then
    declare -F ml >/dev/null || alias ml='module'
    alias mla='module avail'
    alias mll='module list'
    alias mlp='module purge'
    alias mls='module spider'
fi

# Lmod writes `module avail` and friends to stdout instead of stderr, so
# `module avail 2>&1 | grep` is not needed: `mla | grep gcc` works.
#export LMOD_REDIRECT=yes

# Lmod prints without a pager.
#export LMOD_PAGER=none

# ── Login-node etiquette ──────────────────────────────────────────────────

# One thread per program unless a job says otherwise, so a quick test on a
# shared login node does not take every core.  Slurm copies it into every
# job submitted from this shell (--export=ALL is its default), so a job
# that does not set its own runs one thread: sbatch --export=NONE.
#export OMP_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 MKL_NUM_THREADS=1

# Temporary files on scratch instead of a small /tmp, when that scratch
# directory exists.  The path is an example; use your site's.
#[[ -d "/scratch/$USER" ]] && export TMPDIR="/scratch/$USER/tmp" && command mkdir -p "$TMPDIR"

# Tidy up the helper variable.
unset _hpc_watch
