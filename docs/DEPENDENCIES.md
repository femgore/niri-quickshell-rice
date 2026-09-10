# Dependencies

Package names below use Arch/CachyOS naming where practical. Other distributions may split packages differently.

## Required

| Program | Used for |
| --- | --- |
| `niri` | Wayland compositor and window-management actions |
| `quickshell` | Top bar, popups, launcher, clipboard UI, settings, notifications |
| `bash` | Helper scripts |
| `jq` | JSON settings and Niri workspace/output parsing |
| `inotify-tools` | Settings and Quickshell state watchers |
| `libnotify` / `notify-send` | User-facing status and error messages |
| `mako` | Notification daemon and DND state |
| `wl-clipboard` | Clipboard history and screenshot copy |
| `cliphist` | Clipboard history storage |
| `pipewire` / `wireplumber` tools | Audio control through `wpctl` |
| `brightnessctl` | Brightness keys and sliders |
| `playerctl` | Media controls |
| `kitty` | Default terminal binding |

The included Kitty config expects a Nerd Font-compatible monospace family. It defaults to JetBrains Mono.

## Feature-Specific

| Program | Feature |
| --- | --- |
| `hyprlock` | Lock screen used by the Niri config |
| `swayidle` | Idle locking and monitor power-off |
| `swayosd` | OSD for volume, brightness, and caps lock |
| `awww` | Wallpaper daemon |
| `rofi` | Power menu, emoji picker, and fallback launchers |
| `grim`, `slurp`, `imagemagick`, `satty`, `zbar` | Screenshots, annotation, QR scanning, color picker |
| `gpu-screen-recorder`, `wf-recorder`, `ffmpeg`, `pulseaudio`/`pactl` | Region recording, replay buffer, fullscreen Waybar recording |
| `pywal`, `matugen` | Wallpaper color generation |
| `networkmanager`, `bluez` | Network and Bluetooth panels |
| `power-profiles-daemon` | Power profile controls |
| `kservice` / `kbuildsycoca6` | KDE app menu cache refresh |
| `xwayland-satellite` | XWayland support |

## Optional Or Personal

| Program | Notes |
| --- | --- |
| `dolphin`, `nautilus`, `firefox` | Default app bindings and file-opening conveniences |
| `batsignal` | Battery warnings on startup |
| `bwrap` | Optional Quickshell GPU device isolation launcher |
| NVIDIA-capable `ffmpeg` | Needed only by the included NVENC Waybar fullscreen recorder |

The core staged config no longer requires the user's Hyprland configuration tree.
