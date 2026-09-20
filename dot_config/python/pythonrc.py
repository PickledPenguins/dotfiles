"""~/.config/python/pythonrc.py -- run at interactive python start-up.

Set as $PYTHONSTARTUP by ~/.config/bash/rc.d/00-env.sh.  Gives the plain
python3 REPL persistent history under ~/.local/state and Tab completion;
python 3.13+ has both built in, and this only fills in on older versions.
Also imports the modules that are always wanted at a prompt.
"""

import atexit
import os
import sys


def _setup_readline():
    try:
        import readline
    except ImportError:          # windows, or python built without it
        return
    import rlcompleter           # noqa: F401  -- registers the completer
    readline.parse_and_bind("tab: complete")

    state = os.environ.get("XDG_STATE_HOME", os.path.expanduser("~/.local/state"))
    history = os.path.join(state, "python", "history")
    os.makedirs(os.path.dirname(history), exist_ok=True)
    try:
        readline.read_history_file(history)
    except OSError:
        pass
    readline.set_history_length(10000)
    atexit.register(readline.write_history_file, history)


if sys.version_info < (3, 13):
    _setup_readline()

# always-wanted names at the prompt
import json                      # noqa: E402,F401
import math                      # noqa: E402,F401
import re                        # noqa: E402,F401
from pathlib import Path         # noqa: E402,F401
from pprint import pprint as pp  # noqa: E402,F401

del _setup_readline
