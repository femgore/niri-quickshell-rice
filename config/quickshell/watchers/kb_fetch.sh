#!/usr/bin/env bash
layout=$(localectl status 2>/dev/null | awk -F: '/X11 Layout/ { gsub(/^[[:space:]]+/, "", $2); print $2; found=1 } END { if (!found) print "" }')
[[ -z "$layout" || "$layout" == "null" ]] && layout="US"
echo "${layout:0:2}" | tr '[:lower:]' '[:upper:]'
