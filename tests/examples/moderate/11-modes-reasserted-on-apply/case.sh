# source: empty
mkdir "$SRC/private_dot_ssh"; echo "Host *" > "$SRC/private_dot_ssh/config"
dots apply > /dev/null
chmod 664 "$SRC/private_dot_ssh/config"
stat -c '%a' "$SRC/private_dot_ssh/config"
dots apply
stat -c '%a' "$SRC/private_dot_ssh/config"
