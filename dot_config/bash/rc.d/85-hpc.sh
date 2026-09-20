# 85-hpc.sh -- PBS Pro, Slurm and Environment Modules shortcuts.  Every
# block is guarded on the scheduler's commands, so on a workstation this
# file defines nothing.
#
#   PBS      qs   my queued/running jobs     qw   watch them
#            qi   qstat -f JOBID             qd   qdel
#   Slurm    sq   my jobs                    sw   watch them
#            si   scontrol show job          sc   scancel
#            sn   node/partition summary     sacct-today
#   modules  ml   module load/list           mla  module avail
#
# Knobs (set in ~/.bashrc.before):
#   DOTFILES_HPC_WATCH   refresh seconds for qw/sw   default: 10

_hpc_watch="${DOTFILES_HPC_WATCH:-10}"

if command -v qstat >/dev/null; then
    alias qs='qstat -u "$USER"'
    alias qsa='qstat -a'
    alias qw="watch -n $_hpc_watch qstat -u \"\$USER\""
    alias qi='qstat -f'
    alias qd='qdel'
    alias qn='pbsnodes -aS 2>/dev/null || pbsnodes -a'
    # qtail JOBID -- follow the stdout of a running PBS job (needs job_dir in the job env)
    qtail() { tail -f "$(qstat -f "$1" | sed -n 's/.*Output_Path = [^:]*:\(.*\)/\1/p')"; }
fi

if command -v squeue >/dev/null; then
    alias sq='squeue -u "$USER" -o "%.10i %.9P %.20j %.8T %.10M %.10l %.6D %R"'
    alias sqa='squeue -o "%.10i %.9P %.20j %.8u %.8T %.10M %.6D %R"'
    alias sw="watch -n $_hpc_watch squeue -u \"\$USER\""
    alias si='scontrol show job'
    alias sc='scancel'
    alias sn='sinfo -o "%.12P %.5a %.10l %.6D %.6t %N"'
    alias sacct-today='sacct -u "$USER" -S today -o JobID,JobName%20,State,Elapsed,MaxRSS,ExitCode'
    # srun-i [ARGS] -- an interactive shell on a compute node
    srun-i() { srun --pty "$@" "${SHELL:-bash}" -l; }
fi

if command -v module >/dev/null 2>&1 || declare -F module >/dev/null; then
    alias ml='module'
    alias mla='module avail'
    alias mll='module list'
    alias mlp='module purge'
fi

unset _hpc_watch
