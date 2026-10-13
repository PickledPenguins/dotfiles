# 10-options.sh: how bash itself behaves: globbing, cd, jobs, history,
# the terminal, file permissions and resource limits. Bash 4+.
#
# Each setting has its description in the comment above it. A setting with
# "#" directly in front of it is off: delete that "#" to turn it on, or add
# one to turn a setting off. `dots options WORD` searches every file.
# For one machine only, put the line in ~/.bashrc.local instead.
#
# Knobs (set in ~/.bashrc.before):
#   DOTFILES_HISTSIZE       lines kept in memory            default: 50000
#   DOTFILES_HISTFILESIZE   lines kept on disk              default: 100000
#   DOTFILES_HISTIGNORE     extra colon-separated patterns  default: none

# ── Globbing ──────────────────────────────────────────────────────────────

# ** matches files and directories at any depth: ls **/*.py.
shopt -s globstar

# Extended patterns: !(*.o) anything but, @(a|b) one of, +(x) one or more.
shopt -s extglob

# * and ? match names that start with a dot too (never . and ..). Then
# `rm *` removes dotfiles as well, and `ls *` shows them.
#shopt -s dotglob

# Case-insensitive globbing: *.jpg also matches IMG.JPG.
shopt -s nocaseglob

# A pattern that matches nothing expands to nothing instead of staying as
# typed. Handy in loops; risky at the prompt: `ls *.xyz` with no match
# runs a bare ls and lists everything.
#shopt -s nullglob

# A pattern that matches nothing is an error ("no match: *.xyz") instead of
# being passed on as typed. Catches typos; breaks unquoted patterns meant
# for the command: scp host:*.txt, find -name *.py.
#shopt -s failglob

# Case-insensitive [[ == ]], [[ =~ ]] and case patterns, in every function
# loaded after it too: bash-completion then misses matches (ssh -o
# Contr<Tab> offers nothing).
#shopt -s nocasematch

# ── Directories ───────────────────────────────────────────────────────────

# A directory name typed alone is a cd: `..`, `src`, `~/work`. A command
# with the same name as a directory still runs the command.
shopt -s autocd

# cd fixes a small typo in a directory name (a transposed, missing or
# extra letter) and prints the path it used.
shopt -s cdspell

# Tab completion fixes the same small typos in directory names.
shopt -s dirspell

# cd to the value of a variable when no directory has that name:
# proj=~/work/proj; cd proj.
#shopt -s cdable_vars

# Tab expands a variable in a path in place: $HOME/wo<Tab> becomes
# /home/you/work/. Without it the variable stays and a $ gets escaped.
shopt -s direxpand

# ── Jobs ──────────────────────────────────────────────────────────────────

# exit warns while jobs are running or stopped; a second exit leaves anyway.
shopt -s checkjobs

# exit from a login shell (ssh, console) also hangs up its background jobs;
# without this they keep running after a plain exit. A closed terminal
# hangs them up either way: use nohup, disown or tmux for long work.
shopt -s huponexit

# A background job that finishes is reported at once, not at the next prompt.
#set -o notify

# ── Safety ────────────────────────────────────────────────────────────────

# > refuses to overwrite an existing file; >| overwrites on purpose.
# Protects against a mistyped redirect. Scripts are not affected.
set -o noclobber

# A pipeline fails when any command in it fails, not only the last:
# `false | true` fails. Surprising when head or a pager closes a pipe
# early, which reports as a failure (exit 141).
#set -o pipefail

# Ctrl-D on an empty line does not close the shell; type exit. The number
# is how many Ctrl-Ds in a row are ignored first.
#IGNOREEOF=1

# ! is an ordinary character: echo "done!" and passwords with ! work without
# quoting tricks. Costs history expansion: !!, !$, !git.
#set +o histexpand

# Close a shell that has sat idle at the prompt this many seconds (shared
# or public machines). Also closes idle shells in tmux panes.
#TMOUT=3600

# ── History ───────────────────────────────────────────────────────────────

# Append to the history file when a shell exits instead of overwriting it,
# so the last shell to exit does not erase what the others saved.
shopt -s histappend

# A command typed over several lines is saved as one history entry.
shopt -s cmdhist

# ... keeping its line breaks rather than joining the lines with semicolons.
# Easier to re-edit; tools that read ~/.bash_history a line at a time see
# the pieces.
shopt -s lithist

# A history expansion (!!, !$, !git) is put on the command line for a look
# before it runs. Safer; costs one more Enter.
shopt -s histverify

# A failed history expansion (no command matches !foo) comes back for
# editing instead of being thrown away with the whole line.
shopt -s histreedit

# Lines kept in memory (Up, `history`) and in the history file. -1 keeps
# everything, and the file then grows without bound. Only a bash that
# reads this file knows them: bash --norc or sudo -s trims ~/.bash_history
# to 500 lines on exit (the HISTFILE line below avoids that).
HISTSIZE="${DOTFILES_HISTSIZE:-50000}"
HISTFILESIZE="${DOTFILES_HISTFILESIZE:-100000}"

# Not recorded: a repeat of the line before, with older copies of it erased
# from this shell's history (erasedups; the file keeps them, since history
# -a only appends), and lines that start with a space (ignorespace), which
# keeps a command holding a secret out of history.
HISTCONTROL=ignoreboth:erasedups

# Never recorded: these short commands, so history keeps what is worth
# recalling; Up cannot bring them back either. DOTFILES_HISTIGNORE adds more.
HISTIGNORE="pwd:exit:clear:clc:history:bg:fg:jobs${DOTFILES_HISTIGNORE:+:$DOTFILES_HISTIGNORE}"

# `history` shows when each command ran: 2026-09-20 15:04:05.
HISTTIMEFORMAT="%F %T  "

# Keep history in ~/.local/state/bash/history rather than ~/.bash_history.
# Move the old file there first, or history starts empty.
HISTFILE="${XDG_STATE_HOME:-$HOME/.local/state}/bash/history"; command mkdir -p "${HISTFILE%/*}"

# Save each command to the history file as soon as it runs, not when the
# shell exits: a crash or a closed window loses nothing, and a new shell
# sees the commands of shells still open. Per machine off, in
# ~/.bashrc.local: PROMPT_COMMAND=${PROMPT_COMMAND/history -a/:}
[[ "${PROMPT_COMMAND-}" == *'history -a'* ]] || PROMPT_COMMAND="history -a${PROMPT_COMMAND:+;$PROMPT_COMMAND}"

# Also reload the history file at every prompt, so Up in one window
# recalls what was just typed in another. Your own recent commands get
# interleaved with theirs; reading the file costs a few ms per prompt.
# Needs the line above.
#PROMPT_COMMAND="${PROMPT_COMMAND/history -a/history -a; history -c; history -r}"

# ── Terminal ──────────────────────────────────────────────────────────────

# Update LINES and COLUMNS after each command, so output fits a resized window.
shopt -s checkwinsize

# Tab on an empty line does nothing instead of offering every command on PATH.
shopt -s no_empty_cmd_completion

# Free Ctrl-S and Ctrl-Q from flow control, where Ctrl-S freezes the
# terminal until Ctrl-Q. Ctrl-S then searches history forward.
[[ -t 0 ]] && stty -ixon 2>/dev/null

# No "You have new mail in /var/spool/mail/you" -- on a cluster login node
# usually cron output nobody reads.
#unset MAILCHECK

# ── File permissions and limits ───────────────────────────────────────────

# New files rw-r--r--, new directories rwxr-xr-x: everyone may read them.
# Set in every interactive shell, so it replaces a umask from ~/.profile.
#umask 022

# New files private to you (rw-------): the safer choice on a shared machine
# such as a cluster login node. Sharing with a group then needs a chmod.
#umask 077

# New files readable by your group but nobody else (rw-r-----).
umask 027

# No core dumps: a crashing program leaves no core file, which can be
# gigabytes. Soft limit only, so `ulimit -Sc hard` turns them back on.
#ulimit -Sc 0

# Core dumps of any size, to debug a crash with gdb afterwards. Only as
# far as the system's hard limit allows.
ulimit -Sc hard

# No stack size limit, which some Fortran and deeply recursive programs
# need. Only as far as the system's hard limit allows.
ulimit -Ss hard
