# source: empty
printf '# dots options\n\n# Append to the history file.\nshopt -s histappend\n\n# Verify history expansions first.\n#   Costs one more Enter.\n#shopt -s histverify\n' > "$SRC/dot_bashrc"
dots options
dots options --off
dots options -f verify
