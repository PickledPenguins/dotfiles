# ~/.config/python/pythonrc.py -- run when an interactive python starts
# ($PYTHONSTARTUP, set in ~/.config/bash/rc.d/00-env.sh).  Not run by
# scripts, python -c or IPython.
#
# Each setting has its description in the comment above it.  A setting with
# "#" directly in front of it is off: delete that "#" to turn it on, or add
# one to turn a setting off.  `dots options WORD` searches every file.

# The modules the settings below use.
import atexit
import os
import sys
from contextlib import suppress


# The plain REPL of python 3.12 and older gets Tab completion and history
# kept in ~/.local/state/python/history; python 3.13+ has both built in.
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
    with suppress(OSError):
        readline.read_history_file(history)
    readline.set_history_length(10000)
    atexit.register(readline.write_history_file, history)
if sys.version_info < (3, 13):
    _setup_readline()
del _setup_readline

# json, math, re, Path and pp (pprint) ready at the prompt.
import json                      # noqa: E402,F401
import math                      # noqa: E402,F401
import re                        # noqa: E402,F401
from pathlib import Path         # noqa: E402,F401
from pprint import pprint as pp  # noqa: E402,F401

# datetime, date and timedelta ready too.
#from datetime import date, datetime, timedelta  # noqa: E402,F401

# numpy as np and pandas as pd, in environments that have them.
#with suppress(ImportError): import numpy as np  # noqa: E402,E701
#with suppress(ImportError): import pandas as pd  # noqa: E402,E701

# Results are pretty-printed: long lists and dicts one item per line.
#sys.displayhook = lambda value: None if value is None else (pp(value), setattr(__import__("builtins"), "_", value))

# Results pretty-printed in color by rich, when installed.
#with suppress(ImportError): __import__("rich.pretty").pretty.install()

# A green >>> prompt (the \001 \002 keep readline's line editing aligned).
#sys.ps1, sys.ps2 = "\001\033[1;32m\002>>> \001\033[0m\002", "\001\033[1;32m\002... \001\033[0m\002"
