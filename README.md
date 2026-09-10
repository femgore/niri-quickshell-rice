# Niri + Quickshell Rice

A portable Niri desktop configuration with a Quickshell bar/popup environment, Waybar helper scripts, wallpaper color integration, screenshot tooling, recording helpers, clipboard UI, media controls, and optional examples.

This repository is for Niri. It does not require the original Hyprland rice.

## Screenshots

Add screenshots to `assets/screenshots/` after reviewing them for private information.

## Features

- Niri config with rounded windows, blur, workspace bindings, and focused-column workflow
- Quickshell top bar, launcher, clipboard, music, volume, network, battery, calendar, wallpaper, settings, and utility panels
- Screenshot overlay with region capture, editing, QR scanning, and recording support
- Pywal/Matugen-backed color generation for Niri and Quickshell
- Optional Waybar config and helper scripts
- Safe installer with backup and dry-run support
- Optional personal and gaming examples kept out of the default install

## Requirements

See `docs/DEPENDENCIES.md`.

On Arch/CachyOS, the core package set is roughly:

```fish
sudo pacman -S niri quickshell jq inotify-tools libnotify mako wl-clipboard cliphist playerctl brightnessctl kitty
```

Feature-specific packages are documented separately because screenshots, recording, wallpaper theming, Bluetooth, and NVIDIA recording each add their own tools.

## Installation

Preview first:

```fish
./install.sh --dry-run
```

Install:

```fish
./install.sh
```

The installer copies:

- `config/niri` to `~/.config/niri`
- `config/quickshell` to `~/.config/quickshell`
- `config/waybar/scripts` to `~/.config/waybar/scripts`

Conflicting existing paths are moved under:

```fish
~/.local/state/niri-quickshell-rice/backups/
```

## Manual Installation

```fish
cp -a config/niri ~/.config/niri
cp -a config/quickshell ~/.config/quickshell
mkdir -p ~/.config/waybar
cp -a config/waybar/scripts ~/.config/waybar/scripts
```

Back up existing directories before running those commands manually.

## Optional Components

- `optional/gaming/niri/steam-games.kdl` contains disabled Steam/game rules.
- `optional/personal/niri/machine-example.kdl` preserves an example monitor/input/workspace profile.
- `optional/hyprland-compat/` contains intentionally Hyprland-specific material that is not part of the Niri default install.

## Keybindings

See `docs/KEYBINDS.md`.

Important defaults:

| Key | Action |
| --- | --- |
| `Mod+R` | App launcher |
| `Mod+V` | Clipboard |
| `Mod+Shift+W` | Wallpaper picker |
| `Mod+Shift+R` | Region recording |
| `Print` | Screenshot |
| `Mod+H/J/K/L` | Move focus |
| `Mod+Shift+H/J/K/L` | Move window or column |
| `Mod+1..9` | Focus workspace |

## Configuration Layout

See `docs/CONFIGURATION.md`.

The main files are:

- `config/niri/config.kdl`
- `config/niri/scripts/`
- `config/quickshell/Shell.qml`
- `config/quickshell/settings.json`
- `config/waybar/scripts/`

## Customizing Window Rules

Add general rules directly to `~/.config/niri/config.kdl`.

For app-specific rules, copy examples from `optional/gaming/niri/steam-games.kdl` and adjust `app-id`, title matches, sizes, or floating behavior.

Keep hardware-specific output and input settings in a separate local file or clearly marked block so future updates are easier to merge.

## Updating

Pull new repository changes, review them, then rerun:

```fish
./install.sh --dry-run
./install.sh
```

Review the backup location printed by the installer if local configs already exist.

## Uninstallation

Move your previous backups back from:

```fish
~/.local/state/niri-quickshell-rice/backups/
```

Or remove the installed directories manually after backing up local changes:

```fish
rm -i ~/.config/niri ~/.config/quickshell
```

## Troubleshooting

See `docs/TROUBLESHOOTING.md`.

Validate the Niri config without reloading the desktop:

```fish
niri validate --config ~/.config/niri/config.kdl
```

## Credits

This rice is built around Niri, Quickshell, Waybar, Mako, Pywal/Matugen, and common Wayland utilities.

## License

MIT. See `LICENSE`.
