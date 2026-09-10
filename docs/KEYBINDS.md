# Keybindings

`Mod` is Niri's configured main modifier, normally `Super`.

## Application Launching

| Key | Action | Dependency |
| --- | --- | --- |
| `Mod+Q` | Launch Kitty | `kitty` |
| `Mod+E` | Launch Dolphin | `dolphin` |
| `Mod+T` | Launch Firefox from generated settings | `firefox` |
| `Mod+R` | Open Quickshell app launcher | `quickshell` |
| `Mod+Period` | Open emoji picker | `rofi` emoji plugin/support |

## Quickshell Panels

| Key | Action | Dependency |
| --- | --- | --- |
| `Mod+C` / `Mod+V` | Clipboard panel | `quickshell`, `cliphist` |
| `Mod+P` | Movies panel in generated settings; color picker in core config | `quickshell` or screenshot tools |
| `Mod+Shift+Q` | Music panel | `quickshell`, `playerctl` |
| `Mod+B` | Battery panel in generated settings; Waybar toggle in core config | `quickshell` or `waybar` |
| `Mod+Shift+W` | Wallpaper panel | `quickshell`, `awww` |
| `Mod+S` | Calendar panel | `quickshell` |
| `Mod+N` | Network panel | `quickshell`, `nmcli`, `bluetoothctl` |
| `Mod+Shift+T` | Focus-time panel | `quickshell`, `python3` |
| `Mod+V` | Volume panel in generated settings | `quickshell`, `wpctl` |

## Window Management

| Key | Action | Dependency |
| --- | --- | --- |
| `Alt+F4` | Close focused window | Niri |
| `Mod+F` | Toggle floating | Niri |
| `Mod+Y` | Maximize column | Niri |
| `Mod+Shift+F` | Fullscreen focused window | Niri |
| `Mod+O` | Toggle overview | Niri |
| `Mod+H/J/K/L` | Move focus left/down/up/right | Niri |
| `Mod+Shift+H/J/K/L` | Move focused column/window | Niri |
| `Mod+Ctrl+H/J/K/L` | Resize column/window | Niri |
| `Mod+BracketLeft` | Consume or expel window left | Niri |
| `Mod+BracketRight` | Consume or expel window right | Niri |
| `Mod+Ctrl+F` | Expand column to available width | Niri |
| `Mod+C` | Center column in core config | Niri |
| `Mod+Escape` | Toggle keyboard shortcut inhibition | Niri |

## Workspaces

| Key | Action | Dependency |
| --- | --- | --- |
| `Mod+1` through `Mod+5` | Focus workspace 1-5 | Niri |
| `Mod+0` | Focus workspace 10 from generated settings | Niri |
| `Mod+Shift+1` through `Mod+Shift+9` | Move focused window to workspace 1-9 | Niri |
| `Mod+Shift+0` | Move focused window to workspace 10 from generated settings | Niri |
| `Mod+Space` | Toggle `magic` workspace | Niri, `jq` |
| `Mod+Shift+Space` | Move focused window to `magic` and focus it | Niri |
| `Mod+WheelScrollUp/Down` | Focus previous/next column | Niri |
| `Mod+Tab` | Focus next monitor from generated settings | Niri |

## Screenshots And Recording

| Key | Action | Dependency |
| --- | --- | --- |
| `Print` | Native Niri screenshot or staged screenshot helper from generated settings | Niri, `grim`, `wl-copy` |
| `Shift+Print` | Screenshot with editor | `grim`, `satty`, `wl-copy` |
| `Mod+Print` | Fullscreen screenshot | `grim`, `wl-copy` |
| `Mod+Shift+Print` | Fullscreen screenshot with editor | `grim`, `satty`, `wl-copy` |
| `Mod+Shift+S` | Frozen area screenshot / clipboard screenshot from generated settings | `grim`, `slurp`, `imagemagick`, `wl-copy` |
| `Mod+Shift+R` | Region screen recording | `gpu-screen-recorder`, `pactl` |
| `Ctrl+Shift+O` | Toggle replay buffer | `gpu-screen-recorder` |
| `Mod+Alt+O` | Save replay buffer | `gpu-screen-recorder` |

## Media, Audio, Brightness

| Key | Action | Dependency |
| --- | --- | --- |
| `XF86AudioRaiseVolume` | Raise volume | `wpctl` or `swayosd-client` |
| `XF86AudioLowerVolume` | Lower volume | `wpctl` or `swayosd-client` |
| `XF86AudioMute` | Toggle output mute | `wpctl` or `swayosd-client` |
| `XF86AudioMicMute` | Toggle mic mute | `wpctl` or `swayosd-client` |
| `XF86MonBrightnessUp` | Raise brightness | `brightnessctl` or `swayosd-client` |
| `XF86MonBrightnessDown` | Lower brightness | `brightnessctl` or `swayosd-client` |
| `XF86AudioPlay` / `XF86AudioPause` / `Mod+Space` | Play or pause media | `playerctl` |

## Power

| Key | Action | Dependency |
| --- | --- | --- |
| `Alt+L` / `Mod+L` | Lock | `hyprlock` |
| `Alt+S` | Lock then suspend | `hyprlock`, `systemctl` |
| `Alt+E` | Quit Niri | Niri |
| `XF86PowerOff` | Lock from generated settings | `hyprlock` |

## Miscellaneous

| Key | Action | Dependency |
| --- | --- | --- |
| `Mod+Shift+P` | Profile switcher placeholder notification | `notify-send` |
| `Mod+Shift+G` | Shader picker placeholder notification | `notify-send` |
| `Caps_Lock` | Caps lock OSD | `swayosd-client` |
