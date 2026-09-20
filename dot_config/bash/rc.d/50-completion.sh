# 50-completion.sh -- programmable completion.
#
# Loads bash-completion if the system has it (Debian: package bash-completion;
# it is skipped under `set -o posix`), then user-supplied completions from
# ~/.config/bash/completion.d/*.bash -- drop `foo completion bash > that dir`
# output there.

if ! shopt -oq posix; then
    if [[ -r /usr/share/bash-completion/bash_completion ]]; then
        source /usr/share/bash-completion/bash_completion
    elif [[ -r /etc/bash_completion ]]; then
        source /etc/bash_completion
    fi
fi

for _c in "$DOTFILES_BASH_DIR"/completion.d/*.bash; do
    [[ -r "$_c" ]] && source "$_c"
done
unset _c

# The git aliases from 30-aliases.sh complete like git itself.  bash-completion
# loads git's completion lazily on first Tab, so force it now (2.12+ uses
# _comp_load, older releases __load_completion).
if declare -F _comp_load >/dev/null; then _comp_load git 2>/dev/null
elif declare -F __load_completion >/dev/null; then __load_completion git 2>/dev/null; fi
if declare -F __git_wrap__git_main >/dev/null; then
    complete -o bashdefault -o default -o nospace -F __git_wrap__git_main g
fi
