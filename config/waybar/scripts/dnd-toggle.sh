#!/usr/bin/env bash

MODE="do-not-disturb"

if [[ "${1:-}" == "toggle" ]]; then
    makoctl mode -t "$MODE" >/dev/null 2>&1
fi

if makoctl mode 2>/dev/null | grep -Fxq "$MODE"; then
    printf '%s\n' '{"text":"󰽥 ON","class":"enabled","tooltip":"Do Not Disturb: On"}'
else
    printf '%s\n' '{"text":"󰽦 OFF","class":"disabled","tooltip":"Do Not Disturb: Off"}'
fi
