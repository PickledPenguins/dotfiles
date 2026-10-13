# 90-local.sh: machine-local settings, never committed.
#
# ~/.bashrc.local is read last, so it can override anything above: extra
# aliases, tool paths, secrets, path_prepend calls, a setting from this
# directory switched on or off for this machine only. Knobs that modules
# read while loading go in ~/.bashrc.before instead, which ~/.bashrc reads
# first.
#
# Each setting has its description in the comment above it. A setting with
# "#" directly in front of it is off: delete that "#" to turn it on, or add
# one to turn a setting off. `dots options WORD` searches every file.

# Read ~/.bashrc.local when it exists.
[[ -r ~/.bashrc.local ]] && source ~/.bashrc.local
