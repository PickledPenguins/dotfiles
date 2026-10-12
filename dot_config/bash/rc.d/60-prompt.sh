# 60-prompt.sh: the prompt, drawn by bash-prompt-toolkit.
#
# ~/.config/bash/prompt/toolkit/ is bash-prompt-toolkit, kept in this
# repository as a git subtree (docs/contributing.md says how to sync it).
# layout.sh beside it is the configuration: which pieces of information, on
# which rows, in which box -- every piece is listed there with a
# description.
#
# Too slow on a busy login node?  Turn this module off
# (echo prompt >> ~/.config/bash/disabled) and 61-prompt-simple on.
#
# Each setting has its description in the comment above it.  A setting with
# "#" directly in front of it is off: delete that "#" to turn it on, or add
# one to turn a setting off.  `dots options WORD` searches every file.

# The toolkit, then the layout that says what it draws.
source "$DOTFILES_BASH_DIR/prompt/toolkit/prompt.sh"
source "$DOTFILES_BASH_DIR/prompt/layout.sh"
