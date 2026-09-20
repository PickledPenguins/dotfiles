# Prompt: the bash-prompt-toolkit engine plus the layout in
# ~/.config/bash/prompt/layout.sh.  Edit layout.sh to change what the prompt
# shows; leave prompt.sh and lib/ alone (they are a vendored snapshot).
#
# Too heavy for a slow login node?  Disable this module and enable
# 61-prompt-simple.sh.off instead.

source "$DOTFILES_BASH_DIR/prompt/prompt.sh"
source "$DOTFILES_BASH_DIR/prompt/layout.sh"
