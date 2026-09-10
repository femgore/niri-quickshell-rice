#!/usr/bin/env bash
# ────────────────────────────────────────────────────────────────────
#  「✦ WALLPAPER PICKER ✦ 」
# ────────────────────────────────────────────────────────────────────
# RECURSIVE WALLPAPER CATEGORIES
# RANDOM CATEGORY THUMBNAILS
# DYNAMIC ROFI GRID WIDTH
# PYWAL COLOR GENERATION
# ────────────────────────────────────────────────────────────────────

set -u

WALLPAPER_DIR="${WALLPAPER_DIR:-$HOME/walls}"
HYPRPAPER_CONF="${HYPRPAPER_CONF:-$HOME/.config/niri/wallpaper.conf}"
HYPRLOCK_CONF="${HYPRLOCK_CONF:-$HOME/.config/niri/hyprlock.conf}"
ROFI_THEME="${ROFI_THEME:-$HOME/.config/rofi/themes/wallpaper-grid.rasi}"

# Approximate width of one wallpaper card, including spacing.
CARD_WIDTH=350

# Maximum number of cards shown beside each other.
MAX_COLUMNS=3

# Maximum number of visible rows before Rofi scrolls.
MAX_ROWS=3

persist_wallpaper_path() {
    local conf_file="$1"
    local new_path="$2"
    local escaped_path

    [[ -f "$conf_file" ]] || return 0

    escaped_path=$(printf '%s' "$new_path" | sed 's/[\/&]/\\&/g')

    sed -i \
        "0,/^[[:space:]]*path[[:space:]]*=.*/s|^[[:space:]]*path[[:space:]]*=.*|    path = $escaped_path|" \
        "$conf_file"
}

find_images_in_directory() {
    local directory="$1"

    find "$directory" \
        -maxdepth 1 \
        -type f \
        \( \
            -iname "*.jpg" -o \
            -iname "*.jpeg" -o \
            -iname "*.png" -o \
            -iname "*.webp" \
        \) \
        -print0
}

random_image_from_directory() {
    local directory="$1"

    find_images_in_directory "$directory" |
        shuf -z -n 1 |
        tr -d '\0'
}

get_grid_theme() {
    local item_count="$1"
    local columns
    local rows
    local width

    (( item_count < 1 )) && item_count=1

    if (( item_count < MAX_COLUMNS )); then
        columns="$item_count"
    else
        columns="$MAX_COLUMNS"
    fi

    rows=$(( (item_count + columns - 1) / columns ))

    if (( rows > MAX_ROWS )); then
        rows="$MAX_ROWS"
    fi

    width=$(( columns * CARD_WIDTH + 80 ))

    printf '
window {
    width: %dpx;
}

listview {
    columns: %d;
    lines: %d;
    fixed-columns: true;
    fixed-height: true;
    dynamic: false;
    scrollbar: true;
    scrollbar-width: 10px;
    cycle: false;
    flow: horizontal;
}
' "$width" "$columns" "$rows"
}

if [[ ! -d "$WALLPAPER_DIR" ]]; then
    notify-send \
        "Wallpaper Error" \
        "Wallpaper directory does not exist: $WALLPAPER_DIR"

    exit 1
fi

# ── BUILD CATEGORY LIST ─────────────────────────────────────────────

declare -a CATEGORY_NAMES=()
declare -a CATEGORY_DIRS=()
declare -a CATEGORY_THUMBNAILS=()

while IFS= read -r directory; do
    [[ -n "$directory" ]] || continue

    thumbnail=$(random_image_from_directory "$directory")
    [[ -n "$thumbnail" ]] || continue

    if [[ "$directory" == "$WALLPAPER_DIR" ]]; then
        category_name="Root"
    else
        category_name="${directory#"$WALLPAPER_DIR"/}"
    fi

    CATEGORY_NAMES+=("$category_name")
    CATEGORY_DIRS+=("$directory")
    CATEGORY_THUMBNAILS+=("$thumbnail")
done < <(
    find "$WALLPAPER_DIR" \
        -type f \
        \( \
            -iname "*.jpg" -o \
            -iname "*.jpeg" -o \
            -iname "*.png" -o \
            -iname "*.webp" \
        \) \
        -printf '%h\n' |
        sort -u
)

CATEGORY_COUNT=${#CATEGORY_NAMES[@]}

if (( CATEGORY_COUNT == 0 )); then
    notify-send \
        "Wallpaper Error" \
        "No supported images were found in $WALLPAPER_DIR"

    exit 1
fi

CATEGORY_THEME=$(get_grid_theme "$CATEGORY_COUNT")

# ── CATEGORY SELECTION OR GLOBAL SEARCH ─────────────────────────────

CATEGORY_INPUT=$(
    {
        for ((i = 0; i < CATEGORY_COUNT; i++)); do
            printf '%s\0icon\x1f%s\n' \
                "${CATEGORY_NAMES[$i]}" \
                "${CATEGORY_THUMBNAILS[$i]}"
        done
    } |
        rofi \
            -dmenu \
            -i \
            -show-icons \
            -matching fuzzy \
            -p "Choose category or search all wallpapers..." \
            -theme "$ROFI_THEME" \
            -theme-str "$CATEGORY_THEME"
)

[[ -n "$CATEGORY_INPUT" ]] || exit 0

CATEGORY_DIR=""
SEARCH_MODE=false
SEARCH_QUERY=""

# Check whether the returned text exactly matches a category.
for ((i = 0; i < CATEGORY_COUNT; i++)); do
    if [[ "${CATEGORY_NAMES[$i]}" == "$CATEGORY_INPUT" ]]; then
        CATEGORY_DIR="${CATEGORY_DIRS[$i]}"
        break
    fi
done

# "/" opens every wallpaper recursively.
# Any other non-category input becomes a global filename search.
if [[ -z "$CATEGORY_DIR" ]]; then
    SEARCH_MODE=true

    if [[ "$CATEGORY_INPUT" == "/" ]]; then
        SEARCH_QUERY=""
    else
        SEARCH_QUERY="$CATEGORY_INPUT"
    fi
fi
# ── BUILD WALLPAPER LIST ────────────────────────────────────────────

declare -a WALLPAPER_NAMES=()
declare -a WALLPAPER_PATHS=()

if [[ "$SEARCH_MODE" == true ]]; then
    # Search every supported image recursively.
    # Matching is case-insensitive and checks the filename only.
    while IFS= read -r -d '' file; do
        filename="$(basename "$file")"

        if [[ "${filename,,}" == *"${SEARCH_QUERY,,}"* ]]; then
            relative_path="${file#"$WALLPAPER_DIR"/}"

            WALLPAPER_NAMES+=("$relative_path")
            WALLPAPER_PATHS+=("$file")
        fi
    done < <(
        find "$WALLPAPER_DIR" \
            -type f \
            \( \
                -iname "*.jpg" -o \
                -iname "*.jpeg" -o \
                -iname "*.png" -o \
                -iname "*.webp" \
            \) \
            -print0 |
            sort -z
    )
else
    # Normal category mode: only show images directly inside that folder.
    while IFS= read -r -d '' file; do
        WALLPAPER_NAMES+=("$(basename "$file")")
        WALLPAPER_PATHS+=("$file")
    done < <(
        find_images_in_directory "$CATEGORY_DIR" |
            sort -z
    )
fi

WALLPAPER_COUNT=${#WALLPAPER_PATHS[@]}

if (( WALLPAPER_COUNT == 0 )); then
    if [[ "$SEARCH_MODE" == true ]]; then
        notify-send \
            "Wallpaper Search" \
            "No wallpaper filenames matched: $SEARCH_QUERY"
    else
        notify-send \
            "Wallpaper Error" \
            "No wallpapers were found in $CATEGORY_DIR"
    fi

    exit 1
fi

WALLPAPER_THEME=$(get_grid_theme "$WALLPAPER_COUNT")

# ── WALLPAPER SELECTION ─────────────────────────────────────────────

if [[ "$SEARCH_MODE" == true ]]; then
    WALLPAPER_PROMPT="Search: $SEARCH_QUERY"
else
    WALLPAPER_PROMPT="$CATEGORY_INPUT"
fi

CHOICE=$(
    {
        for ((i = 0; i < WALLPAPER_COUNT; i++)); do
            printf '%s\0icon\x1f%s\n' \
                "${WALLPAPER_NAMES[$i]}" \
                "${WALLPAPER_PATHS[$i]}"
        done
    } |
        rofi \
            -dmenu \
            -i \
            -show-icons \
            -matching fuzzy \
            -p "$WALLPAPER_PROMPT" \
            -theme "$ROFI_THEME" \
            -theme-str "$WALLPAPER_THEME"
)

[[ -n "$CHOICE" ]] || exit 0

WALLPAPER=""

for ((i = 0; i < WALLPAPER_COUNT; i++)); do
    if [[ "${WALLPAPER_NAMES[$i]}" == "$CHOICE" ]]; then
        WALLPAPER="${WALLPAPER_PATHS[$i]}"
        break
    fi
done

if [[ -z "$WALLPAPER" || ! -f "$WALLPAPER" ]]; then
    notify-send \
        "Wallpaper Error" \
        "Wallpaper file could not be found: $CHOICE"

    exit 1
fi
# ── APPLY WALLPAPER ─────────────────────────────────────────────────

"$HOME/.config/niri/scripts/set-wallpaper.sh" "$WALLPAPER"

if [[ "$SEARCH_MODE" == true ]]; then
    DISPLAY_CATEGORY="Search"
else
    DISPLAY_CATEGORY="$CATEGORY_INPUT"
fi

notify-send \
    "Wallpaper Updated" \
    "$DISPLAY_CATEGORY/$CHOICE" \
    -i "$WALLPAPER"
