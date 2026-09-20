# source: empty
mkdir -p ~/.config/app; echo "x" > ~/.config/app/rc
ln -s ~/.config/app/rc ~/.rc-link
dots add ~/.config/app ~/.rc-link; echo "exit $?"
