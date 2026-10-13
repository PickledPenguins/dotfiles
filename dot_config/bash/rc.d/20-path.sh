# 20-path.sh: PATH, and the helpers other modules and ~/.bashrc.local use
# to extend it.
#
#   path_prepend DIR   put DIR first on PATH
#   path_append DIR    put DIR last on PATH
#   path_remove DIR    take DIR off PATH
#
# prepend and append move a directory already on PATH rather than adding it
# twice, and skip one that does not exist, so each line below is harmless on
# a machine without that directory.
#
# Each setting has its description in the comment above it. A setting with
# "#" directly in front of it is off: delete that "#" to turn it on, or add
# one to turn a setting off. `dots options WORD` searches every file.
# For one machine only, put the line in ~/.bashrc.local instead.
#
# Knobs (set in ~/.bashrc.before):
#   DOTFILES_PATH_PREPEND  colon-separated dirs to put first  default: none
#   DOTFILES_PATH_APPEND   colon-separated dirs to put last   default: none

# The helpers themselves.
path_remove()  { PATH=":$PATH:"; PATH="${PATH//:"$1":/:}"; PATH="${PATH#:}"; PATH="${PATH%:}"; }
path_prepend() { [[ -d "$1" ]] || return 0; path_remove "$1"; PATH="$1${PATH:+:$PATH}"; }
path_append()  { [[ -d "$1" ]] || return 0; path_remove "$1"; PATH="${PATH:+$PATH:}$1"; }

# ── Your own programs ─────────────────────────────────────────────────────

# ~/.local/bin (pip --user, pipx, uv tool) and ~/bin come first, so a
# program of yours wins over a system one of the same name.
path_prepend "$HOME/bin"
path_prepend "$HOME/.local/bin"

# ── Language toolchains, when installed ───────────────────────────────────

# Rust: programs from rustup and `cargo install`.
path_append "${CARGO_HOME:-$HOME/.cargo}/bin"

# Go: programs from `go install`.
path_append "${GOPATH:-$HOME/go}/bin"

# node: programs from `npm install -g`, in NPM_CONFIG_PREFIX (00-env.sh can
# move it) or after `npm config set prefix ~/.npm-global`.
path_append "${NPM_CONFIG_PREFIX:-$HOME/.npm-global}/bin"

# deno: programs from `deno install`, in DENO_INSTALL_ROOT when 00-env.sh
# moves it.
#path_append "${DENO_INSTALL_ROOT:-$HOME/.deno}/bin"

# bun: programs from `bun install -g`, in BUN_INSTALL when 00-env.sh moves it.
#path_append "${BUN_INSTALL:-$HOME/.bun}/bin"

# .NET global tools: `dotnet tool install -g`, under DOTNET_CLI_HOME when
# 00-env.sh moves it.
#path_append "${DOTNET_CLI_HOME:-$HOME}/.dotnet/tools"

# Julia versions installed by juliaup.
#path_append "$HOME/.juliaup/bin"

# Haskell: ghcup's toolchain and programs from `cabal install`, in
# CABAL_DIR when set. With GHCUP_USE_XDG_DIRS (00-env.sh) ghcup puts its
# programs in ~/.local/bin, already on PATH.
#path_append "$HOME/.ghcup/bin"; path_append "${CABAL_DIR:-$HOME/.cabal}/bin"

# pixi: global environments from `pixi global install`, in PIXI_HOME when
# 00-env.sh moves it.
#path_append "${PIXI_HOME:-$HOME/.pixi}/bin"

# CUDA compilers and tools in the usual install location (nvcc, nsys).
#path_append /usr/local/cuda/bin

# Flatpak applications by their application ID (org.gnome.Meld).
#path_append /var/lib/flatpak/exports/bin; path_append "$HOME/.local/share/flatpak/exports/bin"

# Snap packages, for shells that did not start from a login session.
#path_append /snap/bin

# ── Per machine ───────────────────────────────────────────────────────────

# Directories from the DOTFILES_PATH_PREPEND and DOTFILES_PATH_APPEND knobs.
IFS=: read -ra _dirs <<<"${DOTFILES_PATH_PREPEND-}"
for _d in "${_dirs[@]}"; do path_prepend "$_d"; done
IFS=: read -ra _dirs <<<"${DOTFILES_PATH_APPEND-}"
for _d in "${_dirs[@]}"; do path_append "$_d"; done
unset _dirs _d

# Programs started from this shell see the result.
export PATH

# man finds pages installed under ~/.local/share/man (pip, cargo, by hand)
# as well as the system's; the trailing : keeps the system path. Added
# once, so a nested shell does not add it again.
[[ -d "$HOME/.local/share/man" && ":${MANPATH-}:" != *":$HOME/.local/share/man:"* ]] &&
    export MANPATH="$HOME/.local/share/man:${MANPATH:-}"
