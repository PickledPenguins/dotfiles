# source: empty
mkdir "$SRC/private_dot_ssh"
echo "Host *" > "$SRC/private_dot_ssh/config"
chmod 644 "$SRC/private_dot_ssh/config"
dots apply
stat -c '%a %n' ~/.ssh | sed "s|$HOME|HOME|"
stat -c '%a %n' "$SRC/private_dot_ssh/config" | sed "s|$SRC|SRC|"
