# source: empty
echo "x" > "$SRC/../outside"
dots add "$SRC/../outside" ~/../outside 2>&1; echo "exit $?"
cat "$SRC/../outside"
