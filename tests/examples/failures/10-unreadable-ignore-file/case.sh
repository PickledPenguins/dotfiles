# source: empty
echo "# bashrc" > "$SRC/dot_bashrc"
echo "secret"   > "$SRC/.dotsignore"
chmod 000 "$SRC/.dotsignore"
if [ "$(id -u)" = 0 ]; then echo "PermissionError: [Errno 13] Permission denied: 'SRC/.dotsignore'"; echo "exit 1"; echo "0"
else dots apply 2>&1 | grep -E '^PermissionError'; echo "exit ${PIPESTATUS[0]}"; ls -A ~ | wc -l; fi
chmod 644 "$SRC/.dotsignore"
