# source: empty
mkdir -p "$SRC/private_dot_ssh"
echo "Host *" > "$SRC/private_dot_ssh/config"
dots apply; echo "exit $?"
echo "github.com ssh-ed25519 AAAA" > ~/.ssh/known_hosts; chmod 644 ~/.ssh/known_hosts
dots add ~/.ssh/known_hosts
ls "$SRC"
stat -c '%a %n' ~/.ssh "$SRC/private_dot_ssh/known_hosts" | sed "s|$SRC|SRC|; s|$HOME|HOME|"
dots forget ~/.ssh/known_hosts; echo "exit $?"
[ -L ~/.ssh/known_hosts ] || cat ~/.ssh/known_hosts
dots apply; echo "exit $?"
dots status -a; echo "exit $?"
