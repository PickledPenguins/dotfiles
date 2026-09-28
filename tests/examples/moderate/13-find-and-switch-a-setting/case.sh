# source: repo
dots apply > /dev/null
dots options -f nocasematch | sed -n '1,2p'
bash --rcfile ~/.bashrc -i -c 'shopt nocasematch' 2>&1 | grep -v "job control\|process group"
sed -i 's/^#shopt -s nocasematch/shopt -s nocasematch/' "$SRC/dot_config/bash/rc.d/10-options.sh"
dots options --on nocasematch | awk 'NR == 2 {print $2}'
bash --rcfile ~/.bashrc -i -c 'shopt nocasematch' 2>&1 | grep -v "job control\|process group"
