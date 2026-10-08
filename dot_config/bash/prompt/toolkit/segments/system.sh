#!/usr/bin/env bash
# Toolkit version: 0.1.7
# ════════════════════════════════════════════════════════════════════════════
# segments/system.sh — machine resources: load average, disk usage, GPU
#
# Sourced by prompt.sh; not usable on its own. Each segment only formats a
# value its collector stored; the collectors run in prompt_build, in the
# shell's own process, on a TTL, and only while a row the layout shows
# uses their segment.
#
# Segments:   _ps_seg_load  _ps_seg_disk  _ps_seg_gpu
# Collectors: load (10 s)  disk (30 s)  gpu (10 s)
# ════════════════════════════════════════════════════════════════════════════

# Values the collectors store for the segments to format. Never write these
# from inside a *_seg_* function; those run via command substitution (a
# subshell) and any assignment made there is silently lost when it exits.
declare -g _PS_GPU_CACHE_VAL=""    # nvidia-smi utilization.gpu, or "" if unavailable
declare -g _PS_DISK_CACHE_VAL=""   # usage percent, or "" if unavailable/not near capacity
declare -g _PS_LOAD_CACHE_VAL=""   # 1-min load average, or "" if unavailable/not busy

# Core count for the load segment's busy threshold — invariant for the
# life of the shell, so it is read once, on the first load collection,
# instead of once per render (as _ps_seg_load used to) or at every shell
# start whether or not @load is shown.
declare -gi _PS_CORES=0

# 1-minute load average, shown only when the node is genuinely busy
# (load exceeds core count) — quiet on an idle shared login node.
# [v0.1.3] Collection (the /proc/loadavg read and the busy-threshold
# check) lives in _ps_collect_load, run from prompt_build and TTL-cached
# (10s). Previously this forked nproc AND awk on *every* render, even the
# vast majority where it prints nothing — and because it ran inside the
# segment (a command-substitution subshell), nothing it computed could
# have been cached here even if it had tried.
_ps_collect_load() {
    _PS_LOAD_CACHE_VAL=""
    (( _PS_CORES > 0 )) || _PS_CORES=$(nproc 2>/dev/null) || _PS_CORES=1
    if [[ -r /proc/loadavg ]]; then
        local load1; read -r load1 _ < /proc/loadavg
        awk -v l="$load1" -v c="$_PS_CORES" 'BEGIN { exit !(l > c) }' &&
            _PS_LOAD_CACHE_VAL="$load1"
    fi
}
# Formats the cached load average (collected by _ps_collect_load).
_ps_seg_load() {
    [[ -n "$_PS_LOAD_CACHE_VAL" ]] && printf '⚖%s' "$_PS_LOAD_CACHE_VAL"
}

# Filesystem usage percent for $PWD, shown only near capacity (>=90%).
# Uses df rather than true quota parsing -- quota semantics vary too much
# across NFS/Lustre/GPFS to get generically right.
# [v0.1.3] Same restructuring as load: collection is _ps_collect_disk,
# TTL-cached (30s — usage doesn't need per-render freshness) and run from
# prompt_build instead of inside the segment.
_ps_collect_disk() {
    _PS_DISK_CACHE_VAL=""
    local pct; pct=$(df -P . 2>/dev/null | awk 'NR==2 {gsub(/%/,"",$5); print $5}')
    [[ -n "$pct" ]] && (( pct >= 90 )) && _PS_DISK_CACHE_VAL="$pct"
}
# Formats the cached disk usage percent (collected by _ps_collect_disk).
_ps_seg_disk() {
    [[ -n "$_PS_DISK_CACHE_VAL" ]] && printf '%s⛁%d%%%s' "$C_BYELLOW" "$_PS_DISK_CACHE_VAL" "$C_R"
}

# GPU utilization -- nvidia-smi is slow (~100ms+), so this is TTL-cached
# (10s) with a timeout guard so a misbehaving driver can't stall every
# prompt render. Silent on non-GPU nodes or if nvidia-smi is unavailable.
#
# [v0.1.3, CRITICAL FIX] This TTL cache never actually worked before —
# collection ran inside _ps_seg_gpu, which _ps_expand calls as
# val=$(_ps_seg_gpu): a command-substitution SUBSHELL. cache_touch and
# the value assignment both happened in that subshell and were discarded
# the instant it exited; the parent shell never saw them. Every render
# re-forked nvidia-smi (with its 1s timeout) regardless of the 10s TTL —
# verified directly: cache_age stayed -1 (never recorded) after repeated
# renders. Collection now runs in _ps_collect_gpu, called from
# prompt_build in the parent shell, same as git, load and disk. The rule
# generalizes: DATA COLLECTION HAPPENS IN A COLLECTOR; *_seg_* functions
# only format already-collected globals.
_ps_collect_gpu() {
    _PS_GPU_CACHE_VAL=""
    if command -v nvidia-smi &>/dev/null; then
        _PS_GPU_CACHE_VAL=$(timeout 1 nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits 2>/dev/null | head -1)
    fi
}
# Formats the cached GPU utilization (collected by _ps_collect_gpu).
_ps_seg_gpu() {
    [[ -n "$_PS_GPU_CACHE_VAL" ]] && printf '%sGPU %s%%%s' "$C_BCYAN" "$_PS_GPU_CACHE_VAL" "$C_R"
}

prompt_collector load 10 _ps_collect_load
prompt_collector disk 30 _ps_collect_disk
prompt_collector gpu  10 _ps_collect_gpu
prompt_segment_needs _ps_seg_load load
prompt_segment_needs _ps_seg_disk disk
prompt_segment_needs _ps_seg_gpu  gpu
