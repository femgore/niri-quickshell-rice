#!/usr/bin/env bash

if pgrep -x wf-recorder >/dev/null; then
    printf '{"text":"⏺ Recording ON","class":"recording","tooltip":"Screen recording active"}\n'
else
    printf '{"text":"○ Recording OFF","class":"idle","tooltip":"Start fullscreen recording"}\n'
fi
