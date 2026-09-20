# source: repo
dots apply > /dev/null
cat > ~/.bashrc.before <<'EOF'
DOTFILES_HISTSIZE=500
DOTFILES_SAFE_RM=0
DOTFILES_PROMPT_LAYOUT=minimal
EOF
bash --rcfile ~/.bashrc -i -c 'echo $HISTSIZE; alias rm 2>&1; prompt_build; echo "$PS1" | head -1 | cut -c1-2' 2>&1 \
  | grep -v "job control\|process group"
