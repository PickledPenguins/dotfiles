# source: empty
echo "token"    > ~/.netrc;        chmod 600 ~/.netrc
echo "set nu"   > ~/.vimrc;        chmod 644 ~/.vimrc
mkdir -p ~/.local/bin
printf '#!/bin/sh\n' > ~/.local/bin/tool; chmod 755 ~/.local/bin/tool
echo "shared"   > ~/.shared;       chmod 644 ~/.shared
dots add ~/.netrc ~/.vimrc ~/.local/bin/tool
dots add --private ~/.shared
