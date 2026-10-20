# 50-completion.sh: Tab completion for commands' options and arguments.
#
# Programs that print their own completion script (`foo completion bash`)
# are fastest when that output is saved once into
# ~/.config/bash/completion.d/foo.bash, which is read below; running the
# program at every shell start costs its start-up time each time.
# 80-tools.sh loads kubectl's and gh's on the first Tab instead.
#
# Each setting has its description in the comment above it. A setting with
# "#" directly in front of it is off: delete that "#" to turn it on, or add
# one to turn a setting off. `dots options WORD` searches every file.

# bash-completion, when the system has it (Debian: the bash-completion
# package): options and arguments for hundreds of commands. The largest
# fixed cost of a new shell, 20-40 ms; turn it off for plain file and
# command completion only.
if ! shopt -oq posix; then
    if [[ -r /usr/share/bash-completion/bash_completion ]]; then
        source /usr/share/bash-completion/bash_completion
    elif [[ -r /etc/bash_completion ]]; then
        source /etc/bash_completion
    fi
fi

# Your own completion scripts: every ~/.config/bash/completion.d/*.bash.
for _c in "$DOTFILES_BASH_DIR"/completion.d/*.bash; do
    [[ -r "$_c" ]] && source "$_c"
done
unset _c

# The g alias (30-aliases.sh) completes like git. bash-completion loads
# git's completion on the first Tab, so load it now (2.12+ has _comp_load,
# older releases __load_completion).
if declare -F _comp_load >/dev/null; then _comp_load git 2>/dev/null
elif declare -F __load_completion >/dev/null; then __load_completion git 2>/dev/null; fi
if declare -F __git_wrap__git_main >/dev/null; then
    complete -o bashdefault -o default -o nospace -F __git_wrap__git_main g
fi

# `git ctags` (~/.local/bin/git-ctags) completes its one subcommand, off.
_git_ctags() { __gitcomp "off"; }

# `git hooks` (~/.local/bin/git-hooks) completes its subcommands, then the
# packaged hooks' names.
_git_hooks() {
    local subcommands="available show install remove on off update template" subcommand
    subcommand=$(__git_find_on_cmdline "$subcommands")
    if [[ -z $subcommand ]]; then
        __gitcomp "$subcommands"
    elif [[ $subcommand != @(available|update|template) ]]; then
        __gitcomp "$(git hooks available 2>/dev/null | awk '{print $2}')"
    fi
}

# `git scrub` (~/.local/bin/git-scrub) completes its options, and a file
# after the ones that take one.
_git_scrub() {
    # shellcheck disable=SC2154  # prev: set by git's completion
    case $prev in --path | --trailer | --messages | --words | --backup) return ;; esac
    __gitcomp "--path --trailer --messages --words --backup --filter-branch --dry-run"
}

# `git each` (~/.local/bin/git-each) completes -k, then a range
# shellcheck disable=SC2154  # cur: set by git's completion
_git_each() {
    case $cur in -*) __gitcomp "-k" ;; *) __git_complete_revlist ;; esac
}

# `git resolve` (~/.local/bin/git-resolve) completes its subcommands, then
# the conflicted files
_git_resolve() {
    local subcommands="list show ours theirs base both" subcommand
    subcommand=$(__git_find_on_cmdline "$subcommands")
    case $subcommand in
        '') __gitcomp "$subcommands" ;;
        list) ;;
        *) __gitcomp "$(git diff --name-only --relative --diff-filter=U 2>/dev/null)" ;;
    esac
}

# `git absorb` (~/.local/bin/git-absorb) completes its options, and a
# revision after --base.
# shellcheck disable=SC2154  # prev: set by git's completion
_git_absorb() {
    [[ $prev == --base ]] && { __git_complete_refs; return; }
    __gitcomp "--base --dry-run"
}

# `git wt` (~/.local/bin/git-wt) completes its subcommands, then branch
# names: every branch after new, the ones in a worktree after rm and cd.
# shellcheck disable=SC2154  # cur: set by git's completion
_git_wt() {
    local subcommands="new ls rm cd" subcommand
    subcommand=$(__git_find_on_cmdline "$subcommands")
    case $subcommand in
        '') __gitcomp "$subcommands" ;;
        new) __gitcomp_direct "$(__git_heads "" "$cur" " ")" ;;
        rm | cd)
            [[ $subcommand == rm && $cur == -* ]] && { __gitcomp "-f"; return; }
            __gitcomp "$(git worktree list --porcelain 2>/dev/null | sed -n 's|^branch refs/heads/||p')"
            ;;
    esac
}
# Host names after ssh, scp and rsync come only from ~/.ssh/config and
# known_hosts, not also every name in /etc/hosts.
#COMP_KNOWN_HOSTS_WITH_HOSTFILE=

# pip's completion, generated at every shell start. Costs about 300 ms;
# prefer saving `pip completion --bash` into completion.d once.
# Needs: pip
#eval "$(pip completion --bash 2>/dev/null)"
