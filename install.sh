#!/usr/bin/env sh
set -eu

REPO_URL="${NIRI_RICE_REPO_URL:-https://github.com/femgore/niri-quickshell-rice.git}"
CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" 2>/dev/null && pwd || pwd)

BACKUP_ROOT="$HOME/.local/state/niri-quickshell-rice/backups/$(date +%Y%m%d-%H%M%S)"

DRY_RUN=0
INTERACTIVE=1
WITH_WALLPAPERS=""
SOURCE_DIR=""
TMP_DIR=""

usage() {
    cat <<'USAGE'
Usage: ./install.sh [options]

Options:
  --dry-run                 Show what would be installed without changing files.
  --with-wallpapers         Include the optional wallpaper collection.
  --without-wallpapers      Skip the optional wallpaper collection.
  --non-interactive         Do not ask questions; unspecified optional items are skipped.
  --help                    Show this help text.

When run from a full local clone, files are copied directly from that clone.

When run remotely, for example from the README installation one-liner,
the installer performs an on-demand sparse Git checkout and downloads
only the required configuration plus any optional components selected.

Core install:
  config/niri            -> ~/.config/niri
  config/quickshell      -> ~/.config/quickshell
  config/kitty           -> ~/.config/kitty
  config/matugen         -> ~/.config/matugen

Optional:
  assets/wallpapers      -> ~/.config/Wallpapers

Existing conflicting paths are moved to:
  ~/.local/state/niri-quickshell-rice/backups/
USAGE
}

say() {
    printf '%s\n' "$*"
}

warn() {
    printf 'Warning: %s\n' "$*" >&2
}

fail() {
    printf 'Error: %s\n' "$*" >&2
    exit 1
}

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

cleanup() {
    if [ -n "$TMP_DIR" ] && [ -d "$TMP_DIR" ]; then
        rm -rf "$TMP_DIR"
    fi
}

trap cleanup EXIT HUP INT TERM

ask_yes_no() {
    prompt=$1
    default=${2:-no}

    if [ "$INTERACTIVE" -eq 0 ]; then
        [ "$default" = "yes" ]
        return
    fi

    if [ "$default" = "yes" ]; then
        suffix='[Y/n]'
    else
        suffix='[y/N]'
    fi

    while :; do
        printf '%s %s ' "$prompt" "$suffix"

        # Prefer the controlling terminal so this still works when invoked
        # through a pipe, for example: curl ... | sh
        if [ -r /dev/tty ]; then
            IFS= read -r answer </dev/tty || answer=""
        else
            IFS= read -r answer || answer=""
        fi

        case "$answer" in
            y|Y|yes|YES|Yes)
                return 0
                ;;
            n|N|no|NO|No)
                return 1
                ;;
            '')
                [ "$default" = "yes" ] && return 0 || return 1
                ;;
            *)
                say "Please answer y or n."
                ;;
        esac
    done
}

run() {
    if [ "$DRY_RUN" -eq 1 ]; then
        printf '[dry-run]'
        printf ' %s' "$@"
        printf '\n'
    else
        "$@"
    fi
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --dry-run)
            DRY_RUN=1
            ;;
        --with-wallpapers)
            WITH_WALLPAPERS=1
            ;;
        --without-wallpapers)
            WITH_WALLPAPERS=0
            ;;
        --non-interactive)
            INTERACTIVE=0
            ;;
        --help|-h)
            usage
            exit 0
            ;;
        *)
            printf 'Unknown option: %s\n\n' "$1" >&2
            usage >&2
            exit 2
            ;;
    esac
    shift
done

say "Niri + Quickshell rice installer"
say ""
say "Core configuration:"
say "  - Niri"
say "  - Quickshell"
say "  - Kitty"
say "  - Matugen"
say ""
say "Optional features:"

if [ -z "$WITH_WALLPAPERS" ]; then
    if ask_yes_no "Install the wallpaper collection (~1.3 GB)?" no; then
        WITH_WALLPAPERS=1
    else
        WITH_WALLPAPERS=0
    fi
fi

say ""
say "Selection:"
say "  Wallpapers: $([ "$WITH_WALLPAPERS" -eq 1 ] && printf 'yes' || printf 'no')"
say ""

# If install.sh is being run from a complete local clone, reuse it and avoid
# performing another network checkout.
if [ -d "$SCRIPT_DIR/config/niri" ] &&
   [ -d "$SCRIPT_DIR/config/quickshell" ] &&
   [ -d "$SCRIPT_DIR/config/kitty" ] &&
   [ -d "$SCRIPT_DIR/config/matugen" ]; then

    SOURCE_DIR=$SCRIPT_DIR
    say "Using files from the local repository."

elif [ "$DRY_RUN" -eq 1 ]; then
    # A dry run should not need to download the repository.
    SOURCE_DIR="<sparse-checkout>"
    say "[dry-run] Would create a temporary partial clone of: $REPO_URL"

else
    command_exists git ||
        fail "git is required for the remote installer. Install Git and run this again."

    command_exists mktemp ||
        fail "mktemp is required but was not found."

    TMP_DIR=$(mktemp -d "${TMPDIR:-/tmp}/niri-quickshell-rice.XXXXXX")
    SOURCE_DIR="$TMP_DIR/repo"

    say "Downloading selected components..."

    git clone \
        --quiet \
        --depth 1 \
        --filter=blob:none \
        --no-checkout \
        "$REPO_URL" \
        "$SOURCE_DIR"

    git -C "$SOURCE_DIR" sparse-checkout init --cone

    set -- \
        config/niri \
        config/quickshell \
        config/kitty \
        config/matugen

    if [ "$WITH_WALLPAPERS" -eq 1 ]; then
        set -- "$@" assets/wallpapers
    fi

    git -C "$SOURCE_DIR" sparse-checkout set "$@"
    git -C "$SOURCE_DIR" checkout --quiet
fi

backup_path() {
    dst=$1

    if [ ! -e "$dst" ] && [ ! -L "$dst" ]; then
        return 0
    fi

    case "$dst" in
        "$CONFIG_HOME"/*)
            rel=${dst#"$CONFIG_HOME"/}
            ;;
        "$HOME"/*)
            rel="home/${dst#"$HOME"/}"
            ;;
        *)
            rel="external/$(printf '%s' "$dst" | sed 's|^/||; s|/|_|g')"
            ;;
    esac

    backup="$BACKUP_ROOT/$rel"

    say "Backing up $dst -> $backup"

    run mkdir -p "$(dirname "$backup")"
    run mv "$dst" "$backup"
}

install_path() {
    rel_src=$1
    dst=$2

    if [ "$DRY_RUN" -eq 1 ] &&
       [ "$SOURCE_DIR" = "<sparse-checkout>" ]; then

        say "Installing $rel_src -> $dst"
        run mkdir -p "$(dirname "$dst")"
        return 0
    fi

    src="$SOURCE_DIR/$rel_src"

    [ -e "$src" ] ||
        fail "Missing source in repository: $rel_src"

    backup_path "$dst"

    say "Installing $rel_src -> $dst"

    run mkdir -p "$(dirname "$dst")"
    run cp -a "$src" "$dst"
}

say ""
say "Installing selected files..."

install_path config/niri "$CONFIG_HOME/niri"
install_path config/quickshell "$CONFIG_HOME/quickshell"
install_path config/kitty "$CONFIG_HOME/kitty"
install_path config/matugen "$CONFIG_HOME/matugen"

if [ "$WITH_WALLPAPERS" -eq 1 ]; then
    install_path assets/wallpapers "$CONFIG_HOME/Wallpapers"
fi

say ""
say "Done."

if [ "$DRY_RUN" -eq 0 ]; then
    say "Backups, if any, were written under:"
    say "  $BACKUP_ROOT"
fi
