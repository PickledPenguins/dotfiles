# source: empty
echo "trap"   > "$SRC/dot_"
echo "trap"   > "$SRC/private_"
mkdir -p "$SRC/private_dot_ssh/keys" "$SRC/dot_config/odd dir" "$SRC/dot_config/skip"
echo "k"      > "$SRC/private_dot_ssh/keys/id"
echo "s"      > "$SRC/dot_config/odd dir/it's \"quoted\" file"
echo "h"      > "$SRC/dot_config/.hidden-below-root"
: > "$SRC/dot_empty"
echo "x"      > "$SRC/dot_config/skip/me"
printf '# skip this tree\n.config/skip\n' > "$SRC/.dotsignore"
echo "keep me" > ~/precious
echo "old"     > ~/.empty

dots apply --force; echo "exit $?"
cat ~/precious
stat -c '%a %n' ~/.ssh ~/.ssh/keys | sed "s|$HOME|HOME|"
stat -c '%a' "$SRC/private_dot_ssh/keys/id"
cat ~/.config/odd\ dir/it\'s\ \"quoted\"\ file
[ -L ~/.config/.hidden-below-root ] && echo "hidden below root: linked"
[ -e ~/.config/skip ] || echo ".config/skip: not created"
wc -c < ~/.empty
