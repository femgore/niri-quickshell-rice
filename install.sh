#!/usr/bin/env sh
set -eu

DRY_RUN=0
WITH_OPTIONAL=""
CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
REPO_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
BACKUP_ROOT="$HOME/.local/state/niri-quickshell-rice/backups/$(date +%Y%m%d-%H%M%S)"

usage() {
    cat <<'USAGE'
Usage: ./install.sh [options]

Options:
  --dry-run              Show what would be installed without changing files.
  --with-hyprland-compat Install optional Hyprland compatibility examples.
  --help                 Show this help text.

The installer copies repository files into XDG config locations:
  config/niri       -> ~/.config/niri
  config/quickshell -> ~/.config/quickshell
  config/waybar/scripts -> ~/.config/waybar/scripts

Existing conflicting paths are moved to ~/.local/state/niri-quickshell-rice/backups/.
USAGE
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --dry-run) DRY_RUN=1 ;;
        --with-hyprland-compat) WITH_OPTIONAL="hyprland-compat" ;;
        --help|-h) usage; exit 0 ;;
        *) echo "Unknown option: $1" >&2; usage >&2; exit 2 ;;
    esac
    shift
done

say() {
    printf '%s\n' "$*"
}

run() {
    if [ "$DRY_RUN" -eq 1 ]; then
        printf '[dry-run] %s\n' "$*"
    else
        "$@"
    fi
}

backup_path() {
    src=$1
    dst=$2

    if [ ! -e "$dst" ] && [ ! -L "$dst" ]; then
        return 0
    fi

    rel=${dst#"$CONFIG_HOME"/}
    backup="$BACKUP_ROOT/$rel"
    say "Backing up $dst -> $backup"
    run mkdir -p "$(dirname "$backup")"
    run mv "$dst" "$backup"
}

install_path() {
    src=$1
    dst=$2

    if [ ! -e "$src" ]; then
        echo "Missing source: $src" >&2
        exit 1
    fi

    backup_path "$src" "$dst"
    say "Installing $src -> $dst"
    run mkdir -p "$(dirname "$dst")"
    run cp -a "$src" "$dst"
}

say "Installing Niri + Quickshell rice"
say "Config home: $CONFIG_HOME"

install_path "$REPO_DIR/config/niri" "$CONFIG_HOME/niri"
install_path "$REPO_DIR/config/quickshell" "$CONFIG_HOME/quickshell"
run mkdir -p "$CONFIG_HOME/waybar"
install_path "$REPO_DIR/config/waybar/scripts" "$CONFIG_HOME/waybar/scripts"

if [ "$WITH_OPTIONAL" = "hyprland-compat" ]; then
    install_path "$REPO_DIR/optional/hyprland-compat/waybar/scripts" "$CONFIG_HOME/waybar/scripts-hyprland-compat"
fi

say "Done."
if [ "$DRY_RUN" -eq 0 ]; then
    say "Backups, if any, were written under: $BACKUP_ROOT"
fi
