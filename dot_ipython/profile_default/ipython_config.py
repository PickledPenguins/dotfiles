# ~/.ipython/profile_default/ipython_config.py: IPython's defaults. Every
# setting here is off, so IPython behaves as it does without a config file
# until you choose. `ipython --help-all` lists every option.
#
# Each setting has its description in the comment above it. A setting with
# "#" directly in front of it is off: delete that "#" to turn it on, or add
# one to turn a setting off. `dots options WORD` searches every file.

# The object every setting below is set on.
c = get_config()  # noqa: F821 -- provided by IPython when it reads this file

# ── Start-up ──────────────────────────────────────────────────────────────

# Edited modules are reloaded before each command: change a file, call its
# function again, get the new code. Occasionally confuses class instances.
# Its start-up line is added to exec_lines, beside the next setting's.
#c.InteractiveShellApp.extensions = ["autoreload"]
#c.InteractiveShellApp.exec_lines.extend(["%autoreload 2"])

# numpy as np and pandas as pd at every start (slower start-up).
#c.InteractiveShellApp.exec_lines.extend(["import numpy as np", "import pandas as pd"])

# No banner at start.
#c.TerminalIPythonApp.display_banner = False

# ── Editing ───────────────────────────────────────────────────────────────

# vi keys on the input line instead of emacs keys.
#c.TerminalInteractiveShell.editing_mode = "vi"

# Leave with Ctrl-D or exit without "Do you really want to exit?".
#c.TerminalInteractiveShell.confirm_exit = False

# Grey suggestions from history as you type; Right accepts them.
#c.TerminalInteractiveShell.autosuggestions_provider = "NavigableAutoSuggestFromHistory"

# The editor %edit opens.
#c.TerminalInteractiveShell.editor = "vim"

# Brackets and quotes are not closed automatically.
#c.TerminalInteractiveShell.auto_match = False

# ── Output ────────────────────────────────────────────────────────────────

# Syntax colors for a light terminal background.
#c.InteractiveShell.colors = "lightbg"

# Tracebacks show less context: one line per frame.
#c.InteractiveShell.xmode = "Minimal"

# Every expression on a line prints its value, not only the last.
#c.InteractiveShell.ast_node_interactivity = "all"

# ── History ───────────────────────────────────────────────────────────────

# Input history is not saved to the history database.
#c.HistoryManager.enabled = False
