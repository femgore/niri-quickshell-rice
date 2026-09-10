#!/usr/bin/env python3
from __future__ import annotations

import json
import os
from pathlib import Path

H = Path.home()
wal_json = H / ".cache/wal/colors.json"
if not wal_json.exists():
    raise SystemExit(f"Missing {wal_json}; run wal first")

data = json.loads(wal_json.read_text())
colors = data.get("colors", {})
special = data.get("special", {})

def c(name: str, fallback: str = "#888888") -> str:
    return str(colors.get(name, fallback))

def s(name: str, fallback: str) -> str:
    return str(special.get(name, fallback))

def hex_to_rgb(value: str) -> tuple[int, int, int]:
    value = value.lstrip("#")
    return tuple(int(value[i:i+2], 16) for i in (0, 2, 4))

def rgba(value: str, alpha: float) -> str:
    r, g, b = hex_to_rgb(value)
    return f"rgba({r}, {g}, {b}, {alpha:.2f})"

def write(path: Path, text: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_suffix(path.suffix + ".tmp")
    tmp.write_text(text)
    os.replace(tmp, path)

bg = s("background", c("color0", "#101010"))
fg = s("foreground", c("color7", "#eeeeee"))

# Same semantic schema consumed by Imperative's MatugenColors.qml.
qs = {
    "base": bg,
    "mantle": c("color0", bg),
    "crust": c("color0", bg),
    "text": fg,
    "subtext0": c("color7", fg),
    "subtext1": c("color8", "#777777"),
    "surface0": c("color0", bg),
    "surface1": c("color8", "#555555"),
    "surface2": c("color8", "#666666"),
    "overlay0": c("color8", "#777777"),
    "overlay1": c("color7", fg),
    "overlay2": fg,
    "blue": c("color4"),
    "sapphire": c("color6"),
    "peach": c("color3"),
    "green": c("color2"),
    "red": c("color1"),
    "mauve": c("color5"),
    "pink": c("color5"),
    "yellow": c("color3"),
    "maroon": c("color1"),
    "teal": c("color6"),
}
write(H / ".config/quickshell/qs_colors.json", json.dumps(qs, indent=2) + "\n")

kitty = f'''# Generated from Pywal by Imperative color-engine bridge.
foreground {fg}
background {bg}
selection_foreground {bg}
selection_background {c("color7", fg)}
cursor {c("color4")}
cursor_text_color {bg}
url_color {c("color6")}
active_border_color {c("color4")}
inactive_border_color {c("color8")}
bell_border_color {c("color1")}
active_tab_foreground {bg}
active_tab_background {c("color4")}
inactive_tab_foreground {fg}
inactive_tab_background {c("color0", bg)}
tab_bar_background {bg}
color0 {c("color0")}
color1 {c("color1")}
color2 {c("color2")}
color3 {c("color3")}
color4 {c("color4")}
color5 {c("color5")}
color6 {c("color6")}
color7 {c("color7")}
color8 {c("color8")}
color9 {c("color9", c("color1"))}
color10 {c("color10", c("color2"))}
color11 {c("color11", c("color3"))}
color12 {c("color12", c("color4"))}
color13 {c("color13", c("color5"))}
color14 {c("color14", c("color6"))}
color15 {c("color15", fg)}
'''
write(H / ".config/kitty/kitty-matugen-colors.conf", kitty)

niri = f'''// Generated from Pywal by Imperative color-engine bridge.
layout {{
    border {{
        active-color "{c("color4")}"
        inactive-color "{c("color8")}"
        urgent-color "{c("color1")}"
    }}
    shadow {{ color "{bg}aa"; }}
    tab-indicator {{
        active-color "{c("color4")}"
        inactive-color "{c("color8")}"
        urgent-color "{c("color1")}"
    }}
}}
overview {{ backdrop-color "{bg}"; }}
'''
write(H / ".config/niri/colors.kdl", niri)

# Preserve the existing glass/layout stylesheet and only swap Discord variables.
equibop = f'''/* Generated from Pywal by Imperative color-engine bridge. */
@import url("./Pywal.theme.pre-matugen-style.css");
:root, .theme-dark, .theme-light, .visual-refresh.theme-dark, .visual-refresh.theme-light {{
  --background-primary: {bg} !important;
  --background-secondary: {c("color0", bg)} !important;
  --background-secondary-alt: {c("color0", bg)} !important;
  --background-tertiary: {c("color8")} !important;
  --background-floating: {c("color0", bg)} !important;
  --background-accent: {c("color4")} !important;
  --background-modifier-hover: {rgba(fg, .08)} !important;
  --background-modifier-active: {rgba(fg, .12)} !important;
  --background-modifier-selected: {rgba(fg, .16)} !important;
  --background-modifier-accent: {rgba(c("color8"), .45)} !important;
  --text-normal: {fg} !important;
  --text-muted: {c("color7", fg)} !important;
  --text-link: {c("color4")} !important;
  --text-positive: {c("color2")} !important;
  --text-warning: {c("color3")} !important;
  --text-danger: {c("color1")} !important;
  --header-primary: {fg} !important;
  --header-secondary: {c("color7", fg)} !important;
  --interactive-normal: {c("color7", fg)} !important;
  --interactive-hover: {fg} !important;
  --interactive-active: {c("color4")} !important;
  --interactive-muted: {c("color8")} !important;
  --brand-500: {c("color4")} !important;
  --brand-560: {c("color4")} !important;
  --brand-600: {c("color12", c("color4"))} !important;
  --control-brand-foreground: {c("color4")} !important;
  --control-brand-foreground-new: {c("color4")} !important;
  --mention-foreground: {c("color4")} !important;
  --mention-background: {rgba(c("color4"), .16)} !important;
  --status-positive: {c("color2")} !important;
  --status-warning: {c("color3")} !important;
  --status-danger: {c("color1")} !important;
  --status-speaking: {c("color4")} !important;
  --channel-icon: {c("color7", fg)} !important;
  --channels-default: {c("color7", fg)} !important;
  --channel-text-area-placeholder: {c("color8")} !important;
  --scrollbar-thin-thumb: {c("color8")} !important;
  --scrollbar-auto-thumb: {c("color8")} !important;
  --scrollbar-auto-track: transparent !important;
}}
body, #app-mount {{ color: {fg}; }}
::selection {{ background: {rgba(c("color4"), .35)}; color: {bg}; }}
'''
write(H / ".config/equibop/themes/Pywal.theme.css", equibop)

# Lightweight shared outputs for the remaining themed apps.
write(H / ".config/cava/colors", f'''[color]\ngradient = 1\ngradient_color_1 = '{c("color4")}'\ngradient_color_2 = '{c("color5")}'\ngradient_color_3 = '{c("color6")}'\n''')
write(H / ".cache/matugen/colors-gtk.css", f'''@define-color accent_color {c("color4")};\n@define-color accent_bg_color {c("color4")};\n@define-color accent_fg_color {bg};\n@define-color window_bg_color {bg};\n@define-color window_fg_color {fg};\n@define-color view_bg_color {bg};\n@define-color view_fg_color {fg};\n''')
qss = f'''/* Generated from Pywal */\n* {{ selection-background-color: {c("color4")}; selection-color: {bg}; }}\nQToolTip {{ color: {fg}; background-color: {c("color0", bg)}; border: 1px solid {c("color8")}; }}\n'''
write(H / ".config/qt5ct/qss/matugen-style.qss", qss)
write(H / ".config/qt6ct/qss/matugen-style.qss", qss)
print("Generated Pywal-backed Imperative themes")
