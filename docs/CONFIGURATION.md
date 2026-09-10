# Configuration

## Layout

| Path | Purpose |
| --- | --- |
| `config/niri/config.kdl` | Main Niri config and default keybindings |
| `config/niri/scripts/` | Niri-owned helper scripts copied from the live setup |
| `config/niri/imperative/` | Settings-generated Niri keybind and scale bridge |
| `config/quickshell/` | Active Quickshell shell, widgets, settings, and color files |
| `config/waybar/scripts/` | Helper scripts used by the optional Niri Waybar config |
| `optional/` | Disabled examples and compatibility snippets |

## Personal Material

Machine-specific monitor, input, cursor, and workspace mapping was moved to:

`optional/personal/niri/machine-example.kdl`

Game-specific rules were moved to:

`optional/gaming/niri/steam-games.kdl`

Copy only the parts you need into `~/.config/niri/config.kdl`.

## Generated Files

These files may be rewritten at runtime:

| File | Generator |
| --- | --- |
| `~/.config/niri/focus-mode.kdl` | `~/.config/niri/scripts/focus-mode.sh` |
| `~/.config/niri/colors.kdl` | Pywal/Matugen bridge |
| `~/.config/niri/imperative/generated-binds.kdl` | `niri-keybind-generator.py` |
| `~/.config/niri/imperative/generated-scale.kdl` | `niri-scale-generator.sh` |
| `~/.config/quickshell/settings.json` | Quickshell settings panel |

Do not commit runtime cache or state from `~/.cache`, `~/.local/state`, or `$XDG_RUNTIME_DIR`.
