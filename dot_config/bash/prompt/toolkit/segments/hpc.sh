#!/usr/bin/env bash
# Toolkit version: 0.1.12
# ════════════════════════════════════════════════════════════════════════════
# segments/hpc.sh — cluster context: loaded environment modules, PBS and
# Slurm job details
#
# Sourced by prompt.sh; not usable on its own. No collected data: each
# segment reads the job's environment directly, and is silent outside a
# job or without a module system.
#
# Segments: _ps_seg_modules
#           _ps_seg_pbs_job    _ps_seg_pbs_queue    _ps_seg_pbs_nodes
#           _ps_seg_slurm_job  _ps_seg_slurm_queue  _ps_seg_slurm_nodes
# ════════════════════════════════════════════════════════════════════════════

# ⊞N count of loaded environment modules.
_ps_seg_modules() {
    [[ -z "${LOADEDMODULES-}" ]] && return
    # Some module systems emit a leading/trailing/doubled colon; squeeze and
    # trim first or a bare colon-count overcounts entries that aren't there.
    local mods; mods=$(tr -s ':' <<< "$LOADEDMODULES")
    mods="${mods#:}"; mods="${mods%:}"
    [[ -z "$mods" ]] && return
    local colons="${mods//[^:]}"
    printf '⊞ %d' $(( ${#colons} + 1 ))
}

# ── PBS / Torque ──────────────────────────────────────────────────────────
_ps_seg_pbs_job()   { [[ -n "${PBS_JOBID-}"   ]] && printf 'PBS %s'  "${PBS_JOBID%%.*}"; }
# PBS queue name for the current job.
_ps_seg_pbs_queue() { [[ -n "${PBS_QUEUE-}"   ]] && printf '%s'      "$PBS_QUEUE"; }
# Count unique nodes allocated to the current PBS job.
_ps_seg_pbs_nodes() {
    [[ -f "${PBS_NODEFILE:-}" ]] || return
    # sort -u | wc -l | tr -d ' ' replaced with a plain bash dedup: this
    # segment has no TTL cache of its own and PBS_NODEFILE doesn't change
    # during a job, so it forks all three, every render, for the entire
    # life of the job — worth the small bit of extra code.
    # Each variable is declared separately on purpose: `local -A seen=()
    # line n=0` would apply -A to ALL THREE names, making `line` and `n`
    # associative arrays too. That happened to still produce the right
    # answer (bash routes the bare reads and increments through index
    # [0]) but only by accident, not by any documented rule.
    local -A seen=()
    local line
    local -i n=0
    while IFS= read -r line; do
        [[ -n "${seen[$line]-}" ]] && continue
        seen["$line"]=1
        (( n++ ))
    done < "$PBS_NODEFILE"
    (( n > 0 )) && printf '%d nodes' "$n"
}

# ── Slurm ─────────────────────────────────────────────────────────────────
_ps_seg_slurm_job()   { [[ -n "${SLURM_JOB_ID-}"        ]] && printf 'SLURM %s' "$SLURM_JOB_ID"; }
# Slurm partition name for the current job.
_ps_seg_slurm_queue() { [[ -n "${SLURM_JOB_PARTITION-}" ]] && printf '%s'        "$SLURM_JOB_PARTITION"; }
# Node count allocated to the current Slurm job.
_ps_seg_slurm_nodes() { [[ -n "${SLURM_NNODES-}"        ]] && printf '%d nodes'  "$SLURM_NNODES"; }
