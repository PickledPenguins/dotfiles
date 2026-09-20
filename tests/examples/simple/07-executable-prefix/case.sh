# source: empty
mkdir -p "$SRC/dot_local/bin"
printf '#!/bin/sh\necho hi\n' > "$SRC/dot_local/bin/executable_hi"
chmod 644 "$SRC/dot_local/bin/executable_hi"
dots apply
~/.local/bin/hi
