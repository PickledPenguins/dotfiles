# 05-fast.sh: fast mode, for a server whose disk, NFS, CPU or memory is
# slow. In fast mode the features that stat every file, write to disk or
# start a process at each prompt switch to cheaper forms; each module that
# has such a feature says what it does in fast mode. Bash 4.2+, Linux.
#
# Off unless asked for. `dots fast on|off|auto` sets the mode for this
# machine (the file ~/.config/bash/fast), `dots fast reset` removes the
# setting, and DOTS_FAST=on|off|auto in the environment overrides both for
# one shell. `dots fast` alone prints the mode, where it comes from, and
# each signal against its threshold. docs/fast-mode.md has the whole story.
#
# Auto decides at shell start, from what this host looks like now (read
# from /proc, never by testing a disk):
#   blocked  tasks waiting on I/O              on at DOTS_FAST_BLOCKED or more
#   iowait   CPU time waiting on I/O           on at DOTS_FAST_IOWAIT % or more
#   load     1-minute load per CPU             on at DOTS_FAST_LOAD % or more
#   steal    CPU time taken by the hypervisor  on at DOTS_FAST_STEAL % or more
#   mem      memory available                  on at DOTS_FAST_MEM % or less
#   swapin   pages swapped in per second       on at DOTS_FAST_SWAPIN or more
# (iowait, steal and swapin over the time since the last shell or prompt
# looked), and from the last 10 samples of shell startup time and prompt
# git status time on this host. It turns on when a host signal is over its
# threshold or 2 of the last 5 samples were slow, and off only once the
# last 10 were all fast. A running shell in auto turns on after 2 of its
# last 5 git refreshes were slow, and never turns off.
#
# Samples are kept in tmpfs ($XDG_RUNTIME_DIR, else /dev/shm/dots-UID,
# else /tmp/dots-UID), a fixed few lines per host: nothing grows, and
# nothing waits for a reboot to go.
#
# Each setting has its description in the comment above it. A setting with
# "#" directly in front of it is off: delete that "#" to turn it on, or add
# one to turn a setting off. `dots options WORD` searches every file.
# For one machine only, put the line in ~/.bashrc.local instead.
#
# Knobs (set in ~/.bashrc.before, exported so sprobe reads the same):
#   DOTS_FAST             on, off or auto, over dots fast      default: unset
#   DOTS_FAST_STARTUP_MS  shell start this slow is slow        default: 300
#   DOTS_FAST_GIT_MS      prompt git status this slow is slow  default: 200
#   DOTS_FAST_BLOCKED     tasks blocked on I/O                 default: 2
#   DOTS_FAST_IOWAIT      iowait, percent                      default: 20
#   DOTS_FAST_LOAD        1-minute load per CPU, percent       default: 150
#   DOTS_FAST_STEAL       steal, percent                       default: 10
#   DOTS_FAST_MEM         memory available, percent            default: 10
#   DOTS_FAST_SWAPIN      pages swapped in per second          default: 100
#   DOTS_FAST_PROMPT      always: the prompt shows the values  default: unset

# ── State ─────────────────────────────────────────────────────────────────

# DOTS_FAST_ACTIVE=1 (exported, for vim and the other modules) while fast
# mode is on; unset while it is off.
_dots_fast_mode=off             # on, off or auto
_dots_fast_from=default         # env, file or default
_dots_fast_why=""               # why it is on, for the notice and dots fast
_dots_fast_over=""              # signals over threshold now, as the prompt shows them
_dots_fast_all=""               # every value, for DOTS_FAST_PROMPT=always
_dots_fast_recent=""            # this shell's last 5 git refreshes: 1 slow, 0 not
_dots_fast_git_last=""          # this shell's last git refresh, ms
declare -a _dots_fast_hooks=()  # functions called with 1 or 0 when the mode changes
declare -A _dots_fast_val=()    # host signal values from the last look
_dots_fast_prev=""              # /proc counters at the last look: uptime_cs total iowait steal pswpin

# The directory and per-host file prefix for samples, made private on
# first use. "" when none can be had: auto then has only the host signals.
_dots_fast_store() {
    local d
    if [[ -n ${XDG_RUNTIME_DIR-} && -d $XDG_RUNTIME_DIR && -w $XDG_RUNTIME_DIR && -O $XDG_RUNTIME_DIR ]]; then
        d=$XDG_RUNTIME_DIR
    else
        for d in "/dev/shm/dots-$UID" "/tmp/dots-$UID" ""; do
            [[ -n $d ]] || break
            [[ -d $d ]] || mkdir -m 700 "$d" 2>/dev/null
            [[ -d $d && -O $d && -w $d ]] && break
        done
    fi
    _dots_fast_file=${d:+$d/dots-fast.${HOSTNAME%%.*}}
}

# A clock in milliseconds, into the variable named $1: $EPOCHREALTIME on
# bash 5, /proc/uptime (10 ms steps) before.
_dots_fast_clock() {
    if [[ -n ${EPOCHREALTIME-} ]]; then
        printf -v "$1" '%d' "$(( 10#${EPOCHREALTIME/[.,]/} / 1000 ))"
    else
        local up _
        read -r up _ < /proc/uptime
        printf -v "$1" '%d' "$(( 10#${up/./} * 10 ))"
    fi
}

# A threshold knob as a whole number: its value, else the default
_dots_fast_knob() {
    local v
    eval "v=\${DOTS_FAST_$1-}"
    [[ $v =~ ^[0-9]+$ ]] || v=$2
    printf -v "_dots_fast_t_$1" '%d' "$v"
}

# Every threshold knob into _dots_fast_t_NAME
_dots_fast_thresholds() {
    _dots_fast_knob STARTUP_MS 300; _dots_fast_knob GIT_MS 200
    _dots_fast_knob BLOCKED 2;      _dots_fast_knob IOWAIT 20
    _dots_fast_knob LOAD 150;       _dots_fast_knob STEAL 10
    _dots_fast_knob MEM 10;         _dots_fast_knob SWAPIN 100
}

# ── Host signals ──────────────────────────────────────────────────────────

# Read the host signals from /proc with builtins into _dots_fast_val, and
# _dots_fast_over and _dots_fast_all for the prompt. iowait, steal and
# swapin are rates since the last look; with none, or one under 1 s or
# over 10 minutes ago, they are left out this time.
_dots_fast_host() {
    local k a b c d e f g h _ ncpu=0 blocked="" total iow st up cs swapin="" l1 mem="" avail=""
    _dots_fast_val=(); _dots_fast_over=""; _dots_fast_all=""
    [[ -r /proc/stat ]] || return 0
    while read -r k a b c d e f g h _; do
        case $k in
            cpu)           total=$(( a + b + c + d + e + f + g + h )); iow=$e; st=$h ;;
            cpu[0-9]*)     ncpu=$(( ncpu + 1 )) ;;
            procs_blocked) blocked=$a; break ;;
        esac
    done < /proc/stat
    while read -r k a; do
        [[ $k == pswpin ]] && { swapin=$a; break; }
    done < /proc/vmstat
    while read -r k a _; do
        case $k in
            MemTotal:)     mem=$a ;;
            MemAvailable:) avail=$a; break ;;
        esac
    done < /proc/meminfo
    read -r l1 _ < /proc/loadavg
    read -r up _ < /proc/uptime
    cs=$(( 10#${up/./} ))
    # Values now, then the rates since the last look
    [[ -n $blocked ]] && _dots_fast_val[blocked]=$blocked
    (( ncpu )) && _dots_fast_val[load]=$(( 10#${l1/./} / ncpu ))
    [[ -n $avail ]] && (( mem )) && _dots_fast_val[mem]=$(( avail * 100 / mem ))
    local -a p
    read -ra p <<< "$_dots_fast_prev"
    if (( ${#p[@]} == 5 && cs - p[0] >= 100 && cs - p[0] <= 60000 && total > p[1] )); then
        _dots_fast_val[iowait]=$(( (iow - p[2]) * 100 / (total - p[1]) ))
        _dots_fast_val[steal]=$(( (st - p[3]) * 100 / (total - p[1]) ))
        [[ -n $swapin ]] && _dots_fast_val[swapin]=$(( (swapin - p[4]) * 100 / (cs - p[0]) ))
    fi
    (( ${#p[@]} == 5 && cs - p[0] < 100 )) || _dots_fast_prev="$cs $total $iow $st ${swapin:-0}"
    # For the prompt
    _dots_fast_mark blocked BLOCKED blk "" ge
    _dots_fast_mark iowait IOWAIT io % ge
    _dots_fast_mark load LOAD ld "" ge
    _dots_fast_mark steal STEAL st % ge
    _dots_fast_mark mem MEM mem % le
    _dots_fast_mark swapin SWAPIN swp "" ge
}

# Add one signal to _dots_fast_all and, when over its threshold, to
# _dots_fast_over: NAME KNOB TAG UNIT ge|le. Load shows as a ratio (ld1.8).
_dots_fast_mark() {
    local v=${_dots_fast_val[$1]-} t s
    [[ -n $v ]] || return 0
    eval "t=\$_dots_fast_t_$2"
    if [[ $1 == load ]]; then s="$3$(( v / 100 )).$(( v % 100 / 10 ))"; else s="$3$v$4"; fi
    _dots_fast_all+=" $s"
    if [[ $5 == ge ]]; then (( v >= t )); else (( v <= t )); fi && _dots_fast_over+=" $s"
    return 0
}

# The host signals over threshold, as "io 23% >= 20, mem 7% <= 10"
_dots_fast_host_why() {
    local n k t unit op out=""
    for n in blocked:BLOCKED iowait:IOWAIT load:LOAD steal:STEAL mem:MEM swapin:SWAPIN; do
        k=${n#*:}; n=${n%:*}
        [[ -n ${_dots_fast_val[$n]-} ]] || continue
        eval "t=\$_dots_fast_t_$k"
        unit=""; op=">="
        case $n in iowait|load|steal) unit=% ;; mem) unit=%; op="<=" ;; swapin) unit=/s ;; esac
        if [[ $op == ">=" ]]; then (( _dots_fast_val[$n] >= t )); else (( _dots_fast_val[$n] <= t )); fi &&
            out+=", $n ${_dots_fast_val[$n]}$unit $op $t"
    done
    printf '%s' "${out#, }"
}

# ── Samples ───────────────────────────────────────────────────────────────

# The ring of the last 10 samples on this host, one "KIND MS SLOW" a line,
# into _dots_fast_ring.
_dots_fast_ring_read() {
    _dots_fast_ring=()
    [[ -n ${_dots_fast_file-} && -r $_dots_fast_file.ring ]] || return 0
    mapfile -t _dots_fast_ring < "$_dots_fast_file.ring"
}

# Add a sample: KIND MS. Slow when MS is at or over KIND's threshold.
_dots_fast_sample() {
    local t slow=0
    if [[ $1 == git ]]; then t=$_dots_fast_t_GIT_MS; else t=$_dots_fast_t_STARTUP_MS; fi
    (( $2 >= t )) && slow=1
    [[ -n ${_dots_fast_file-} ]] || return 0
    _dots_fast_ring_read
    _dots_fast_ring+=("$1 $2 $slow")
    local n=${#_dots_fast_ring[@]}
    (( n <= 10 )) || _dots_fast_ring=("${_dots_fast_ring[@]:n-10}")
    { printf '%s\n' "${_dots_fast_ring[@]}" > "$_dots_fast_file.ring"; } 2>/dev/null
    return 0
}

# How many of the last N ring samples were slow, into _dots_fast_n; the
# slow ones, as "git 340 ms >= 200", into _dots_fast_slow.
_dots_fast_count() {
    local n=${#_dots_fast_ring[@]} i s k ms t
    _dots_fast_n=0; _dots_fast_slow=""
    for (( i = n > $1 ? n - $1 : 0; i < n; i++ )); do
        read -r k ms s <<< "${_dots_fast_ring[i]}"
        (( s )) || continue
        _dots_fast_n=$(( _dots_fast_n + 1 ))
        if [[ $k == git ]]; then t=$_dots_fast_t_GIT_MS; else t=$_dots_fast_t_STARTUP_MS; fi
        _dots_fast_slow+=", $k $ms ms >= $t"
    done
    _dots_fast_slow=${_dots_fast_slow#, }
}

# ── Deciding ──────────────────────────────────────────────────────────────

# The mode asked for and where it comes from: DOTS_FAST, then
# ~/.config/bash/fast, then off.
_dots_fast_asked() {
    local m="" f=${DOTFILES_BASH_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/bash}/fast
    if [[ -n ${DOTS_FAST-} ]]; then
        _dots_fast_mode=$DOTS_FAST; _dots_fast_from="env"
    elif [[ -r $f ]]; then
        read -r m < "$f"
        _dots_fast_mode=$m; _dots_fast_from="file"
    else
        _dots_fast_mode=off; _dots_fast_from=default
    fi
    case $_dots_fast_mode in
        on|off|auto) ;;
        *) printf 'fast mode: %s is not on, off or auto; taking off\n' "$_dots_fast_mode" >&2
           _dots_fast_mode=off ;;
    esac
}

# Auto's verdict: 0 for on, 1 for off, with the reason in _dots_fast_why.
# STATE (on or off) is the last verdict on this host, for the way back.
_dots_fast_auto() {
    local host
    host=$(_dots_fast_host_why)
    _dots_fast_ring_read
    _dots_fast_count 5
    if [[ -n $host ]] || (( _dots_fast_n >= 2 )); then
        _dots_fast_why=$host
        (( _dots_fast_n >= 2 )) && _dots_fast_why+="${host:+, }$_dots_fast_slow"
        return 0
    fi
    _dots_fast_count 10
    if [[ $1 == on ]] && (( ${#_dots_fast_ring[@]} < 10 || _dots_fast_n > 0 )); then
        _dots_fast_why="staying on: $_dots_fast_n of the last ${#_dots_fast_ring[@]} samples slow, off once 10 in a row are fast"
        return 0
    fi
    _dots_fast_why=""
    return 1
}

# Turn fast mode on (1) or off (0) in this shell, and tell every hook
_dots_fast_set() {
    local f
    if (( $1 )); then export DOTS_FAST_ACTIVE=1; else unset DOTS_FAST_ACTIVE; fi
    for f in "${_dots_fast_hooks[@]}"; do "$f" "$1"; done
}

# A module's fast-mode switch: FUNC is called now with 1 or 0, and again
# whenever the mode changes.
dots_fast_hook() {
    _dots_fast_hooks+=("$1")
    "$1" "${DOTS_FAST_ACTIVE:-0}"
}

# The notice: bold, reversed, on stderr
_dots_fast_notice() {
    printf '\e[1;7m FAST MODE ON \e[0m  %s\n' "$1" >&2
}

# Decide the mode and apply it. Prints the notice when it is on, and a
# line when it goes off in a shell where it was on.
_dots_fast_init() {
    local was=${DOTS_FAST_ACTIVE:-0} on=0 state=""
    _dots_fast_thresholds
    _dots_fast_store
    [[ -n ${_dots_fast_file-} && -r $_dots_fast_file.base ]] && read -r _dots_fast_prev < "$_dots_fast_file.base"
    _dots_fast_host
    [[ -z ${_dots_fast_file-} ]] || { printf '%s\n' "$_dots_fast_prev" > "$_dots_fast_file.base"; } 2>/dev/null
    _dots_fast_asked
    case $_dots_fast_mode in
        on)   on=1; _dots_fast_why="forced: ${_dots_fast_from/env/DOTS_FAST=on}"
              _dots_fast_why=${_dots_fast_why/file/dots fast on} ;;
        off)  _dots_fast_why="" ;;
        auto) [[ -n ${_dots_fast_file-} && -r $_dots_fast_file.state ]] && read -r state < "$_dots_fast_file.state"
              _dots_fast_auto "$state" && on=1
              _dots_fast_why="auto: $_dots_fast_why"
              [[ -z ${_dots_fast_file-} ]] || { (( on )) && echo on || echo off; } > "$_dots_fast_file.state" 2>/dev/null ;;
    esac
    _dots_fast_set "$on"
    if (( on )); then
        _dots_fast_notice "$_dots_fast_why"
    elif (( was )); then
        printf 'fast mode off\n' >&2
    fi
}

# ── Samples from this shell ───────────────────────────────────────────────

# Shell startup time, from the process start in /proc/$$/stat to now
# (10 ms steps), as a sample. The loader calls this after the last module.
_dots_fast_started() {
    local s up _
    { read -r s < "/proc/$$/stat" && read -r up _ < /proc/uptime; } 2>/dev/null || return 0
    local -a f
    read -ra f <<< "${s##*) }"
    _dots_fast_sample startup "$(( (10#${up/./} - f[19]) * 10 ))"
}

# The prompt's git collector, timed: a refresh that starts git is a sample,
# and one that runs past the prompt's budget is slow. In auto, 2 slow of
# this shell's last 5 turn fast mode on.
_dots_fast_collect_git() {
    git_info_cache_valid && return 0
    local pending=$GIT_PENDING t0 t1 rc=0
    _dots_fast_clock t0
    git_info_refresh || rc=$?
    (( pending )) && return "$rc"
    _dots_fast_clock t1
    t1=$(( t1 - t0 ))
    (( GIT_PENDING && t1 < _dots_fast_t_GIT_MS )) && t1=$_dots_fast_t_GIT_MS
    _dots_fast_git_last=$t1
    _dots_fast_sample git "$t1"
    _dots_fast_recent+=$(( t1 >= _dots_fast_t_GIT_MS ))
    (( ${#_dots_fast_recent} <= 5 )) || _dots_fast_recent=${_dots_fast_recent:1}
    if [[ $_dots_fast_mode == auto && -z ${DOTS_FAST_ACTIVE-} && $_dots_fast_recent == *1*1* ]]; then
        _dots_fast_why="auto: git $t1 ms >= $_dots_fast_t_GIT_MS, 2 of the last 5 prompts"
        [[ -z ${_dots_fast_file-} ]] || { echo on > "$_dots_fast_file.state"; } 2>/dev/null
        _dots_fast_set 1
        _dots_fast_notice "$_dots_fast_why"
    fi
    return "$rc"
}

# The prompt's look at the host signals, for its segment
_dots_fast_collect() {
    _dots_fast_host
    [[ -n $_dots_fast_git_last ]] || return 0
    _dots_fast_all+=" git$_dots_fast_git_last"
    (( _dots_fast_git_last < _dots_fast_t_GIT_MS )) || _dots_fast_over+=" git$_dots_fast_git_last"
}

# ── dots fast ─────────────────────────────────────────────────────────────

# dots fast on|off|auto|reset writes the setting, then decides again here.
# Other open shells take it at their next start.
dots() {
    local rc=0
    command dots "$@" || rc=$?
    (( rc == 0 )) && [[ ${1-} == fast && $# -gt 1 ]] && _dots_fast_init
    return "$rc"
}

# What `dots fast` prints: the mode, where it comes from, and each signal
# against its threshold. Samples the host over a second.
_dots_fast_status() {
    local state="" n k v t op unit mark
    _dots_fast_thresholds
    _dots_fast_store
    _dots_fast_host; sleep 1; _dots_fast_host
    _dots_fast_asked
    case $_dots_fast_from in
        env)     k="DOTS_FAST=$_dots_fast_mode in the environment" ;;
        file)    k="${DOTFILES_BASH_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/bash}/fast" ;;
        default) k="default: no ${DOTFILES_BASH_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/bash}/fast" ;;
    esac
    case $_dots_fast_mode in
        on)   printf 'fast mode  on, forced (%s)\n' "$k" ;;
        off)  printf 'fast mode  off (%s)\n' "$k" ;;
        auto) [[ -n ${_dots_fast_file-} && -r $_dots_fast_file.state ]] && read -r state < "$_dots_fast_file.state"
              if _dots_fast_auto "$state"; then v=on; else v=off; fi
              printf 'fast mode  auto, %s now (%s)\n' "$v" "$k"
              [[ -z $_dots_fast_why ]] || printf 'reason     %s\n' "$_dots_fast_why" ;;
    esac
    for n in blocked:BLOCKED: iowait:IOWAIT:% load:LOAD:% steal:STEAL:% mem:MEM:% swapin:SWAPIN:/s; do
        IFS=: read -r n k unit <<< "$n"
        eval "t=\$_dots_fast_t_$k"
        op="or more"; [[ $n == mem ]] && op="or less"
        v=${_dots_fast_val[$n]-}
        mark=""
        if [[ -n $v ]]; then
            [[ $n != mem ]] && (( v >= t )) && mark="  !"
            [[ $n == mem ]] && (( v <= t )) && mark="  !"
        else
            v=-
        fi
        printf '%-10s %-10s at %s%s %s (DOTS_FAST_%s)%s\n' "$n" "$v${unit:+ $unit}" "$t" "$unit" "$op" "$k" "$mark"
    done
    _dots_fast_ring_read
    if (( ${#_dots_fast_ring[@]} == 0 )); then
        printf 'samples    none yet on %s\n' "${HOSTNAME%%.*}"
    else
        _dots_fast_count 5;  n=$_dots_fast_n
        _dots_fast_count 10
        printf 'samples    %d of the last 5 slow (on at 2), %d of the last %d (off at 0 of 10)\n' \
            "$n" "$_dots_fast_n" "${#_dots_fast_ring[@]}"
        for k in "${_dots_fast_ring[@]}"; do
            read -r n v t <<< "$k"
            (( t )) && t="  !" || t=""
            printf '  %-8s %6d ms%s\n' "$n" "$v" "$t"
        done
        printf '           startup at %d ms (DOTS_FAST_STARTUP_MS), git at %d ms (DOTS_FAST_GIT_MS)\n' \
            "$_dots_fast_t_STARTUP_MS" "$_dots_fast_t_GIT_MS"
    fi
}

# Decide at shell start. The loader reads modules only in an interactive
# shell; dots fast sources this file in a script for _dots_fast_status.
if [[ $- == *i* ]]; then
    _dots_fast_init
fi
