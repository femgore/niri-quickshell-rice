#!/usr/bin/env python3
import json
import os
import re
import shlex
import subprocess
import sys
from pathlib import Path

HOME = Path.home()
SETTINGS = HOME / ".config/quickshell/settings.json"
NIRI_DIR = HOME / ".config/niri"
OUT_DIR = NIRI_DIR / "imperative"
OUT_FILE = OUT_DIR / "generated-binds.kdl"
TMP_FILE = OUT_DIR / "generated-binds.kdl.tmp"
TEST_FILE = NIRI_DIR / ".imperative-validate.kdl"

def kdl_quote(value: str) -> str:
    return json.dumps(value)

def normalize_mods(mods: str) -> str:
    words = [w for w in re.split(r"\s+", mods.strip()) if w]
    out = []
    for w in words:
        u = w.upper()
        if u in {"$MAINMOD", "SUPER", "WIN", "MOD"}:
            mapped = "Mod"
        elif u in {"SHIFT", "SHIFT_L", "SHIFT_R"}:
            mapped = "Shift"
        elif u in {"CTRL", "CONTROL", "CTRL_L", "CTRL_R"}:
            mapped = "Ctrl"
        elif u in {"ALT", "ALT_L", "ALT_R"}:
            mapped = "Alt"
        else:
            mapped = w
        if mapped not in out:
            out.append(mapped)
    return "+".join(out)

KEY_ALIASES = {
    "RETURN": "Return",
    "ENTER": "Return",
    "SPACE": "Space",
    "TAB": "Tab",
    "ESC": "Escape",
    "ESCAPE": "Escape",
    "LEFT": "Left",
    "RIGHT": "Right",
    "UP": "Up",
    "DOWN": "Down",
    "PRINT": "Print",
    "CAPS_LOCK": "Caps_Lock",
    "XF86AUDIOPLAY": "XF86AudioPlay",
    "XF86AUDIOPAUSE": "XF86AudioPause",
    "XF86AUDIOMUTE": "XF86AudioMute",
    "XF86AUDIOMICMUTE": "XF86AudioMicMute",
    "XF86AUDIOLOWERVOLUME": "XF86AudioLowerVolume",
    "XF86AUDIORAISEVOLUME": "XF86AudioRaiseVolume",
    "XF86MONBRIGHTNESSDOWN": "XF86MonBrightnessDown",
    "XF86MONBRIGHTNESSUP": "XF86MonBrightnessUp",
    "XF86POWEROFF": "XF86PowerOff",
}

def normalize_key(key: str) -> str:
    raw = key.strip()
    if not raw:
        return ""
    return KEY_ALIASES.get(raw.upper(), raw)

def make_hotkey(mods: str, key: str) -> str:
    m = normalize_mods(mods)
    k = normalize_key(key)
    return f"{m}+{k}" if m else k

def direction(command: str) -> str:
    c = command.strip().lower()
    return {
        "l": "left", "left": "left",
        "r": "right", "right": "right",
        "u": "up", "up": "up",
        "d": "down", "down": "down",
    }.get(c, c)

def action_for(dispatcher: str, command: str) -> str:
    d = (dispatcher or "exec").strip().lower()
    c = (command or "").strip()

    # Common Imperative commands stored as exec wrappers.
    if d.startswith("exec"):
        lowered = c.lower()
        if "hyprctl dispatch killactive" in lowered:
            return "close-window;"
        if "hyprctl togglefloating" in lowered or "hyprctl dispatch togglefloating" in lowered:
            return "toggle-window-floating;"
        if re.fullmatch(r"(bash\s+)?~/.config/niri/scripts/reload\.sh", c):
            return 'spawn-sh "niri msg action do-screen-transition";'
        return f"spawn-sh {kdl_quote(c)};"

    if d == "killactive":
        return "close-window;"
    if d == "togglefloating":
        return "toggle-window-floating;"

    if d == "movefocus":
        dr = direction(c)
        return {
            "left": "focus-column-left;",
            "right": "focus-column-right;",
            "up": "focus-window-up;",
            "down": "focus-window-down;",
        }.get(dr, f"spawn-sh {kdl_quote('notify-send \"Unsupported Niri action\" ' + shlex.quote(d + ' ' + c))};")

    if d == "movewindow":
        dr = direction(c)
        return {
            "left": "move-column-left;",
            "right": "move-column-right;",
            "up": "move-window-up;",
            "down": "move-window-down;",
        }.get(dr, f"spawn-sh {kdl_quote('notify-send \"Unsupported Niri action\" ' + shlex.quote(d + ' ' + c))};")

    if d == "resizeactive":
        parts = c.split()
        if len(parts) == 2:
            try:
                x, y = int(parts[0]), int(parts[1])
                if x:
                    return f'set-column-width "{x:+d}";'
                if y:
                    return f'set-window-height "{y:+d}";'
            except ValueError:
                pass

    if d == "workspace":
        return f"focus-workspace {kdl_quote(c)};"
    if d == "movetoworkspace":
        return f"move-window-to-workspace {kdl_quote(c)};"

    if d == "dispatch":
        # Let advanced users enter a native Niri action name in command.
        native = c.strip().rstrip(";")
        if re.fullmatch(r"[a-z0-9-]+(?:\s+.*)?", native):
            return native + ";"

    # Preserve unsupported entries visibly rather than silently dropping them.
    msg = f"Unsupported Niri binding: {dispatcher} {command}".strip()
    return f"spawn-sh {kdl_quote('notify-send \"Imperative keybind\" ' + shlex.quote(msg))};"

def repeat_property(bind_type: str) -> str:
    t = (bind_type or "bind").lower()
    # Hyprland binde/bindel repeat; plain bind/bindl do not.
    return "" if "e" in t else " repeat=false"

def generate(data: dict) -> str:
    lines = [
        "// Generated from ~/.config/quickshell/settings.json",
        "// Do not edit by hand; edit through Imperative Settings.",
        "binds {",
    ]
    seen = {}
    for idx, item in enumerate(data.get("keybinds", [])):
        hotkey = make_hotkey(str(item.get("mods", "")), str(item.get("key", "")))
        if not hotkey:
            continue
        if hotkey in seen:
            raise ValueError(f"duplicate keybind {hotkey!r} at entries {seen[hotkey]} and {idx}")
        seen[hotkey] = idx
        action = action_for(str(item.get("dispatcher", "exec")), str(item.get("command", "")))
        prop = repeat_property(str(item.get("type", "bind")))
        lines.append(f"    {hotkey}{prop} {{ {action} }}")
    lines.append("}")
    lines.append("")
    return "\n".join(lines)

def validate() -> tuple[bool, str]:
    # The test config includes the real config, then overlays the candidate binds.
    TEST_FILE.write_text(
        f'include {kdl_quote(str(NIRI_DIR / "config.kdl"))}\n'
        f'include {kdl_quote(str(TMP_FILE))}\n'
    )
    commands = [
        ["niri", "--config", str(TEST_FILE), "validate"],
        ["niri", "validate", "--config", str(TEST_FILE)],
        ["niri", "validate", "-c", str(TEST_FILE)],
    ]
    output = ""
    for cmd in commands:
        proc = subprocess.run(cmd, text=True, capture_output=True)
        output = (proc.stdout or "") + (proc.stderr or "")
        if proc.returncode == 0:
            return True, output
        if "unexpected argument" not in output.lower() and "unrecognized" not in output.lower():
            return False, output
    return False, output

def main() -> int:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    try:
        data = json.loads(SETTINGS.read_text())
        TMP_FILE.write_text(generate(data))
    except Exception as exc:
        print(f"generation failed: {exc}", file=sys.stderr)
        return 1

    ok, output = validate()
    try:
        TEST_FILE.unlink(missing_ok=True)
    except Exception:
        pass

    if not ok:
        print("Niri rejected generated keybinds:", file=sys.stderr)
        print(output, file=sys.stderr)
        TMP_FILE.unlink(missing_ok=True)
        return 1

    os.replace(TMP_FILE, OUT_FILE)
    print(f"updated {OUT_FILE}")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
