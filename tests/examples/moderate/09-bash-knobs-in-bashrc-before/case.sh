# source: repo
dots apply > /dev/null
cat > ~/.bashrc.before <<'EOF'
DOTFILES_HISTSIZE=500
DOTFILES_EDITOR=nano
DOTFILES_PROMPT_LAYOUT=minimal
EOF
bash --rcfile ~/.bashrc -i -c 'echo $HISTSIZE; echo $EDITOR; prompt_build; echo "$PS1" | head -1 | cut -c1-2' 2>&1 \
  | grep -v "job control\|process group"
