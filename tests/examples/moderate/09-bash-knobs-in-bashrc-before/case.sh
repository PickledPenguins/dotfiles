# source: repo
dots apply > /dev/null
cat > ~/.bashrc.before <<'EOF'
DOTFILES_HISTSIZE=500
DOTFILES_EDITOR=nano
EOF
bash --rcfile ~/.bashrc -i -c 'echo $HISTSIZE; echo $EDITOR' 2>&1 \
  | grep -v "job control\|process group"
