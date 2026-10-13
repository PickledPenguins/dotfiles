# 12-history.sh: one history file per tmux pane, a log of every command,
# and hgrep to search that log. Bash 4.2+.
#
# With the pane setting on, each tmux pane keeps its own history file, so
# Up and Ctrl-R recall what was typed in that pane only. A new pane's
# file is chosen once, when its shell starts:
#   - a pane split from another starts with a copy of that pane's history;
#   - the first pane of a new window or session takes over the history of
#     the pane closed most recently in a session of the same name;
#   - otherwise it starts with a copy of the shared history file.
# A shell started at a pane's prompt starts with a copy of that shell's
# history, and `exec bash` keeps the file it replaces.
# Each command typed in a pane is also added to the shared file (HISTFILE
# as 10-options.sh sets it), which shells outside tmux keep using.
#
# Pane files are ~/.hist/HOST/SESSION/PID.START, named after the shell
# that writes them. A file is closed once that process is gone. Closed
# files unchanged for DOTFILES_HIST_DAYS days are deleted when a pane
# starts. Each machine has its own HOST directory, so a home shared over
# NFS never mixes up two machines' process IDs.
#
# The log is ~/.hist/log/YYYY-MM, one file a month. When a shell with the
# log on starts, months older than the last DOTFILES_HIST_LOG_MONTHS go.
#
# Each setting has its description in the comment above it. A setting with
# "#" directly in front of it is off: delete that "#" to turn it on, or add
# one to turn a setting off. `dots options WORD` searches every file.
# For one machine only, put the line in ~/.bashrc.local instead.
#
# Knobs (set in ~/.bashrc.before):
#   DOTFILES_HISTDIR          pane history files and the log    default: ~/.hist
#   DOTFILES_HIST_DAYS        days a closed pane file is kept   default: 90
#   DOTFILES_HIST_LOG_MONTHS  months of the log kept            default: 12

# Where the pane files and the log go.
_hist_dir="${DOTFILES_HISTDIR:-$HOME/.hist}"

# The shared file, taken once: sourcing ~/.bashrc again must not mistake
# this pane's own file for it.
_hist_shared="${_hist_shared:-${HISTFILE:-$HOME/.bash_history}}"

# The directory where the commands typed at the last prompt were typed.
_hist_pwd=$PWD

# Point HISTFILE at this tmux pane's own file, chosen as the header says.
# Outside tmux, or when tmux does not answer, nothing changes. Sourcing
# ~/.bashrc again keeps the file already chosen.
_hist_pane_start() {
    if [[ -n ${_hist_pane_file-} ]]; then
        HISTFILE=$_hist_pane_file
        return 0
    fi
    [[ -n ${TMUX_PANE-} ]] || return 0
    local session='' id active last pid self_active='' self_pid='' last_pid='' active_pid=''
    {
        IFS= read -r session
        while read -r id active last pid; do
            if [[ $id == "$TMUX_PANE" ]]; then
                self_active=$active self_pid=$pid
            else
                [[ $last == 1 ]] && last_pid=$pid
                [[ $active == 1 ]] && active_pid=$pid
            fi
        done
    } < <(tmux display -p -t "$TMUX_PANE" '#{session_name}' \; \
               list-panes -t "$TMUX_PANE" -F '#{pane_id} #{pane_active} #{pane_last} #{pane_pid}' 2>/dev/null)
    [[ -n $session ]] || return 0

    # A pane split off and focused leaves its source as the last pane. One
    # split off with -d leaves its source active. A shell started inside
    # the pane's own shell (bash at the prompt) starts from that shell's.
    local source_pid=$active_pid
    [[ $self_active == 1 ]] && source_pid=$last_pid
    [[ $self_pid != "$$" ]] && source_pid=$self_pid

    # Prune before choosing, so nothing about to be taken over is old
    # enough to go. A live pane's file stays however old, and an empty
    # directory goes only when old: never one another shell has just made
    # and is about to fill.
    local old days=${DOTFILES_HIST_DAYS:-90}
    while IFS= read -r -d '' old; do
        [[ ${old##*/} =~ ^([0-9]+)\. ]] && kill -0 "${BASH_REMATCH[1]}" 2>/dev/null && continue
        command rm -f -- "$old"
    done < <(command find "$_hist_dir/$HOSTNAME" -mindepth 1 -type f -mtime +"$days" -print0 2>/dev/null)
    command find "$_hist_dir/$HOSTNAME" -mindepth 1 -type d -empty -mtime +"$days" -delete 2>/dev/null

    # The session's directory: a "/" in its name becomes "_", and a name
    # starting with "." gets "_" in front.
    local name=${session//\//_} start file
    [[ $name == .* ]] && name=_$name
    local dir="$_hist_dir/$HOSTNAME/$name"
    [[ -d $dir ]] || ( umask 077 && command mkdir -p -- "$dir" ) || return 0
    printf -v start '%(%s)T' -1

    # The file this process had before `exec bash`, else a new one: copied
    # from the source pane's, else taken over from a closed pane's, else
    # copied from the shared file. `exec bash` keeps $$ and the
    # environment; a shell started inside has another $$.
    if [[ ${_hist_own-} == "$$:"* ]]; then
        file=${_hist_own#*:}
    else
        file="$dir/$$.$start"
        if [[ -n $source_pid ]]; then
            _hist_newest "$dir" "$source_pid" && command cp -- "$REPLY" "$file"
        else
            local tried=' '
            while [[ ! -e $file ]] && _hist_newest "$dir" "" "$tried"; do
                # Made new first: at its old age another shell could prune it.
                command touch -c -- "$REPLY"
                command mv -- "$REPLY" "$file" 2>/dev/null || tried+="${REPLY##*/} "
            done
        fi
        if [[ ! -e $file ]]; then
            if [[ -f $_hist_shared ]]; then
                command cp -- "$_hist_shared" "$file"
            else
                : >> "$file"
            fi
        fi
    fi
    # Assigning HISTFILESIZE trims HISTFILE: the shared file, which no
    # shell exiting trims when every shell is in tmux.
    HISTFILE=$_hist_shared
    # shellcheck disable=SC2269
    HISTFILESIZE=$HISTFILESIZE
    _hist_pane_file=$file _hist_session=$session
    export _hist_own="$$:$file"
    HISTFILE=$file
    _hist_hook
    return 0
}

# _hist_newest DIR PID [SKIP]: REPLY is the most recently written pane
# file in DIR: of shell PID when PID is given, else of any shell that has
# exited, leaving out the names listed in SKIP (" a b "). Fails when there
# is none.
_hist_newest() {
    local f base newest=
    for f in "$1"/*; do
        base=${f##*/}
        [[ -f $f && $base =~ ^([0-9]+)\.[0-9]+$ ]] || continue
        if [[ -n $2 ]]; then
            [[ ${BASH_REMATCH[1]} == "$2" ]] || continue
        else
            [[ ${3- } == *" $base "* ]] && continue
            kill -0 "${BASH_REMATCH[1]}" 2>/dev/null && continue
        fi
        [[ -z $newest || $f -nt $newest ]] && newest=$f
    done
    [[ -n $newest ]] && REPLY=$newest
}

# At each prompt the commands typed since the last one go to HISTFILE, to
# the shared file when HISTFILE is the pane's, and to the log when it is
# on. HISTFILE unset, empty or /dev/null keeps them out of all three.
# `history -a` into a scratch file is how bash says which commands are new:
# it leaves out ignored ones and keeps count across `history -c; history -r`.
# The exit status is handed on untouched for the prompt to show.
_hist_record() {
    local status=$? entries dir=$_hist_pwd
    _hist_pwd=$PWD
    builtin history -a "$_hist_scratch" && [[ -s $_hist_scratch ]] || return "$status"
    IFS= read -r -d '' entries < "$_hist_scratch"
    : >| "$_hist_scratch"
    [[ -n ${HISTFILE-} && $HISTFILE != /dev/null ]] || return "$status"
    printf '%s' "$entries" >> "$HISTFILE"
    [[ $HISTFILE == "${_hist_pane_file-}" ]] && printf '%s' "$entries" >> "$_hist_shared"
    [[ -n ${_hist_log_dir-} ]] && _hist_log "$entries" "$dir"
    return "$status"
}

# _hist_log ENTRIES DIR: add history-file ENTRIES, typed in DIR, to this
# month's log, one line each: time, host, tmux session (- outside tmux),
# DIR, the command. A command over several lines is joined with \n, and a
# tab in the command or directory is written \t.
_hist_log() {
    local where=${_hist_session:--} dir=${2//$'\t'/\\t}
    local line epoch now month cmd='' out='' stamped=''
    printf -v now '%(%s)T' -1
    printf -v month '%(%Y-%m)T' "$now"
    epoch=$now
    [[ $1 =~ ^#[0-9]+$'\n' ]] && stamped=1
    while IFS= read -r line; do
        if [[ -n $stamped && $line =~ ^#[0-9]+$ ]]; then
            [[ -n $cmd ]] && printf -v out '%s%(%F %T)T\t%s\t%s\t%s\t%s\n' \
                "$out" "$epoch" "$HOSTNAME" "$where" "$dir" "${cmd//$'\t'/\\t}"
            epoch=${line#\#} cmd=
        elif [[ -n $stamped ]]; then
            cmd+=${cmd:+\\n}$line
        else
            printf -v out '%s%(%F %T)T\t%s\t%s\t%s\t%s\n' \
                "$out" "$now" "$HOSTNAME" "$where" "$dir" "${line//$'\t'/\\t}"
        fi
    done <<< "${1%$'\n'}"
    [[ -n $cmd ]] && printf -v out '%s%(%F %T)T\t%s\t%s\t%s\t%s\n' \
        "$out" "$epoch" "$HOSTNAME" "$where" "$dir" "${cmd//$'\t'/\\t}"
    printf '%s' "$out" >> "$_hist_log_dir/$month"
}

# Turn the log on for this shell: drop the months too old to keep, and look
# the tmux session up once.
_hist_log_start() {
    _hist_log_dir="$_hist_dir/log"
    [[ -d $_hist_log_dir ]] || ( umask 077 && command mkdir -p -- "$_hist_log_dir" ) || return 0
    local f year month first
    printf -v month '%(%Y %m)T' -1
    read -r year month <<< "$month"
    (( month = year * 12 + 10#$month - ${DOTFILES_HIST_LOG_MONTHS:-12} ))
    printf -v first '%04d-%02d' $(( month / 12 )) $(( month % 12 + 1 ))
    for f in "$_hist_log_dir"/*; do
        [[ ${f##*/} =~ ^[0-9]{4}-[0-9]{2}$ && ${f##*/} < $first ]] && command rm -f -- "$f"
    done
    if [[ -z ${_hist_session-} && -n ${TMUX_PANE-} ]]; then
        _hist_session=$(tmux display -p -t "$TMUX_PANE" '#{session_name}' 2>/dev/null)
    fi
    _hist_hook
}

# Put _hist_record in PROMPT_COMMAND once, ahead of what is there. Its
# scratch file holds only what is typed between two prompts and goes when
# the shell exits, unless an EXIT trap was set already: that one is kept.
# The scratch files of shells that are gone, left by that or by a kill,
# go when the next shell starts.
_hist_hook() {
    [[ -d $_hist_dir/$HOSTNAME ]] || ( umask 077 && command mkdir -p -- "$_hist_dir/$HOSTNAME" )
    _hist_scratch="${XDG_RUNTIME_DIR:-$_hist_dir/$HOSTNAME}/bash-history.$$"
    local f
    for f in "${_hist_scratch%.*}".*; do
        [[ ${f##*.} =~ ^[0-9]+$ ]] && ! kill -0 "${f##*.}" 2>/dev/null && command rm -f -- "$f"
    done
    local trap_before
    trap_before=$(trap -p EXIT)
    [[ -n $trap_before ]] || trap 'command rm -f -- "$_hist_scratch"' EXIT
    [[ "${PROMPT_COMMAND-}" == *_hist_record* ]] || PROMPT_COMMAND="_hist_record${PROMPT_COMMAND:+; $PROMPT_COMMAND}"
}

# hgrep PATTERN [N]: the last N (default 30) logged commands matching
# PATTERN, newest last: time, directory, command. PATTERN is an extended
# regular expression, matched in any case when it has no capital letter.
# Needs the log setting below.
hgrep() {
    [[ $# -ge 1 && $# -le 2 && ${2:-1} =~ ^[0-9]+$ ]] || { echo "usage: hgrep PATTERN [N]" >&2; return 2; }
    local logs=("$_hist_dir"/log/[0-9]*)
    [[ -f ${logs[0]-} ]] || { echo "hgrep: no log in $_hist_dir/log; switch the log on in 12-history.sh" >&2; return 1; }
    # The pattern goes through the environment: awk -v would expand its \.
    HGREP_RE=$1 awk -F'\t' 'BEGIN { re = ENVIRON["HGREP_RE"]; fold = re !~ /[A-Z]/ }
        (fold ? tolower($5) : $5) ~ re { print $1 "  " $4 "  " $5 }' "${logs[@]}" | tail -n "${2:-30}"
}

# One history file per tmux pane, kept after the pane closes and picked up
# by the next pane as the header describes, so panes never mix their
# commands. Costs one tmux call when a shell starts. Shells outside tmux
# keep the shared file.
# Needs: tmux.
#_hist_pane_start

# Every command, from every shell, with its time, host, tmux session and
# directory, also goes to ~/.hist/log for hgrep to search: about 100 bytes
# a command, kept for DOTFILES_HIST_LOG_MONTHS months.
#_hist_log_start
