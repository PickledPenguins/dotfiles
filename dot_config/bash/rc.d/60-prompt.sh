# 60-prompt.sh -- the bash-prompt-toolkit prompt.
#
# prompt.sh and lib/ under ~/.config/bash/prompt/ are a vendored snapshot of
# bash-prompt-toolkit (version in their headers); do not edit them here.
# layout.sh is the configuration: which segments, which rows, which box.
#
# Too heavy for a slow login node?  Disable this module (echo prompt >>
# ~/.config/bash/disabled) and enable 61-prompt-simple instead.
#
# Knobs (set in ~/.bashrc.before):
#   DOTFILES_PROMPT_LAYOUT   layout name from layout.sh: box, hpc, minimal   default: box

source "$DOTFILES_BASH_DIR/prompt/prompt.sh"
source "$DOTFILES_BASH_DIR/prompt/layout.sh"
