# source: empty
echo "a" > "$SRC/dot_a"
echo "b" > "$SRC/dot_b"
echo "mine" > ~/.b
dots apply; echo "exit $?"
