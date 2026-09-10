#!/usr/bin/env bash
set -euo pipefail

current=$(niri msg --json workspaces | jq -r '.[] | select(.is_focused == true) | .name // ""')
if [[ "$current" == "magic" ]]; then
    niri msg action focus-workspace-previous
else
    niri msg action focus-workspace magic
fi
