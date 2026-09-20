# 90-local.sh -- machine-local settings, never committed.
#
# ~/.bashrc.local is sourced last so it can override anything above: extra
# aliases, tool paths, secrets, `path_prepend` calls.  Knobs that modules read
# at load time go in ~/.bashrc.before instead (sourced first by ~/.bashrc).

[[ -r ~/.bashrc.local ]] && source ~/.bashrc.local
