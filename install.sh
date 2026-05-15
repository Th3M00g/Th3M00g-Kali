#!/usr/bin/env bash
# install.sh — symlink dotfiles into $HOME for fresh Kali setup
#
# Usage:
#   ./install.sh           # symlink everything, backup any existing files
#   ./install.sh -f        # force re-link even if target is already correct
#   ./install.sh -n        # dry run, show what would happen
#   ./install.sh -h        # help

set -euo pipefail

# ─── Config ────────────────────────────────────────────────────────────────
DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="$DOTFILES/src"
BACKUP_DIR="$HOME/.dotfiles-backup-$(date +%Y%m%d-%H%M%S)"

# Map of: source-in-src -> target-in-home
# Format: "source:target" (relative to $SRC and $HOME respectively)
LINKS=(
    "zshrc:.zshrc"
    "vimrc:.vimrc"
    "inputrc:.inputrc"
)

# Directories to ensure exist (for files that reference them)
DIRS=(
    ".vim/undo"
    ".config"
)

# Git identity (override per-machine if needed)
GIT_NAME="your-git-username"
GIT_EMAIL="your-email@example.com"

# ─── Args ──────────────────────────────────────────────────────────────────
FORCE=false
DRY_RUN=false

usage() {
    sed -n '2,8p' "$0"
    exit 0
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        -f|--force) FORCE=true ;;
        -n|--dry-run) DRY_RUN=true ;;
        -h|--help) usage ;;
        *) echo "Unknown option: $1" >&2; exit 1 ;;
    esac
    shift
done

# ─── Helpers ───────────────────────────────────────────────────────────────
log()  { echo "[LOG] $*"; }
info() { echo "[INFO] $*"; }
warn() { echo "[WARN] $*" >&2; }

run() {
    if $DRY_RUN; then
        log "[dry-run] $*"
    else
        "$@"
    fi
}

# ─── Sanity check ──────────────────────────────────────────────────────────
if [[ ! -d "$SRC" ]]; then
    warn "src/ directory not found at $SRC"
    warn "Expected layout: dotfiles/src/{zshrc,vimrc,inputrc,...}"
    exit 1
fi

# ─── Create directories ────────────────────────────────────────────────────
info "Ensuring directories exist..."
for d in "${DIRS[@]}"; do
    target="$HOME/$d"
    if [[ ! -d "$target" ]]; then
        log "create $target"
        run mkdir -p "$target"
    fi
done

# ─── Symlink dotfiles ──────────────────────────────────────────────────────
info "Linking dotfiles..."
backed_up=false

for entry in "${LINKS[@]}"; do
    src="$SRC/${entry%%:*}"
    dst="$HOME/${entry##*:}"

    # Source must exist in repo
    if [[ ! -e "$src" ]]; then
        warn "missing in repo: $src — skipping"
        continue
    fi

    # Already correctly linked?
    if [[ -L "$dst" && "$(readlink "$dst")" == "$src" ]]; then
        if $FORCE; then
            log "relink (forced) $dst"
            run ln -sf "$src" "$dst"
        else
            log "ok      $dst"
        fi
        continue
    fi

    # Existing file/symlink that doesn't match — back it up
    if [[ -e "$dst" || -L "$dst" ]]; then
        if ! $backed_up; then
            log "backup dir: $BACKUP_DIR"
            run mkdir -p "$BACKUP_DIR"
            backed_up=true
        fi
        log "backup  $dst -> $BACKUP_DIR/"
        run mv "$dst" "$BACKUP_DIR/"
    fi

    log "link    $dst -> $src"
    run ln -s "$src" "$dst"
done

# ─── Git basics ────────────────────────────────────────────────────────────
info "Configuring git..."
run git config --global user.name "$GIT_NAME"
run git config --global user.email "$GIT_EMAIL"
run git config --global init.defaultBranch main
run git config --global push.autoSetupRemote true

# ─── apt packages ──────────────────────────────────────────────────────────
if [[ -f "$SRC/apt-packages.txt" ]]; then
    if command -v apt-get &>/dev/null; then
        info "Installing apt packages from src/apt-packages.txt..."
        pkgs=()
        while read -r pkg; do
            [[ -z "$pkg" || "$pkg" =~ ^[[:space:]]*# ]] && continue
            pkgs+=("$pkg")
        done < "$SRC/apt-packages.txt"
        if [[ ${#pkgs[@]} -gt 0 ]]; then
            log "apt-get install -y ${pkgs[*]}"
            run sudo apt-get install -y "${pkgs[@]}" || warn "one or more apt packages failed to install"
        fi
    else
        warn "apt-get not found; skipping system package install"
        warn "install these manually: $(grep -vE '^[[:space:]]*(#|$)' "$SRC/apt-packages.txt" | tr '\n' ' ')"
    fi
fi

# ─── pipx tools (optional) ─────────────────────────────────────────────────
if [[ -f "$SRC/pipx-tools.txt" ]]; then
    if command -v pipx &>/dev/null; then
        info "Installing pipx tools from src/pipx-tools.txt..."
        while read -r tool; do
            # Skip blank lines and comments
            [[ -z "$tool" || "$tool" =~ ^[[:space:]]*# ]] && continue
            log "pipx install $tool"
            run pipx install "$tool" 2>/dev/null || warn "failed: $tool"
        done < "$SRC/pipx-tools.txt"
    else
        warn "pipx not installed; skipping tool restore"
        warn "install with: sudo apt install pipx"
    fi
fi

# ─── Summary ───────────────────────────────────────────────────────────────
echo ""
if $DRY_RUN; then
    info "Dry run complete. No changes made."
else
    info "Done."
    if $backed_up; then
        info "Existing files backed up to: $BACKUP_DIR"
    fi
    echo ""
    info "Next steps:"
    log "1. Open a new shell, or run: exec zsh"
    log "2. Copy src/zshrc.local.example -> ~/.zshrc.local and customize"
    log "   (private aliases, machine-specific paths, etc.)"
fi