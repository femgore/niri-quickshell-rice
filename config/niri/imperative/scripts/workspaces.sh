#!/usr/bin/env bash

set -uo pipefail

SETTINGS_FILE="$HOME/.config/quickshell/settings.json"
RUN_DIR="$XDG_RUNTIME_DIR/quickshell/workspaces"
OUTPUT="$RUN_DIR/workspaces.json"

mkdir -p "$RUN_DIR"

get_workspace_count() {
    local count

    count="$(
        jq -r '.workspaceCount // 8' "$SETTINGS_FILE" 2>/dev/null
    )"

    if [[ ! "$count" =~ ^[0-9]+$ ]]; then
        count=8
    fi

    printf '%s\n' "$count"
}

write_state() {
    local workspaces windows count

    workspaces="$(niri msg --json workspaces 2>/dev/null)" || return
    windows="$(niri msg --json windows 2>/dev/null || printf '[]')"
    count="$(get_workspace_count)"

    jq \
        --argjson count "$count" \
        --argjson windows "$windows" '
        def ws_at($index):
            map(select(.idx == $index))[0] // null;

        def occupied($workspace_id):
            if $workspace_id == null then
                false
            else
                any($windows[]?; .workspace_id == $workspace_id)
            end;

        [
            range(1; $count + 1) as $index
            | ws_at($index) as $ws
            | {
                id: $index,
                state:
                    if ($ws != null and $ws.is_focused == true) then
                        "active"
                    elif ($ws != null and $ws.is_active == true) then
                        "active"
                    elif ($ws != null and occupied($ws.id)) then
                        "occupied"
                    else
                        "empty"
                    end
            }
        ]
    ' <<<"$workspaces" >"$OUTPUT.tmp" &&
        mv "$OUTPUT.tmp" "$OUTPUT"
}

write_state

niri msg --json event-stream 2>/dev/null |
while IFS= read -r _event; do
    write_state
done
