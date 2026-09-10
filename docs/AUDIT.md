# Audit Notes

## Rice Files

Core files are under:

- `config/niri/`
- `config/quickshell/`
- `config/waybar/scripts/`

The active Quickshell setup originally lived under a Hyprland script directory. It has been copied into `config/quickshell/` and staged references were rewritten to use `~/.config/quickshell`.

## Generated Files

The following are generated or rewritten at runtime:

- `config/niri/colors.kdl`
- `config/niri/focus-mode.kdl`
- `config/niri/imperative/generated-binds.kdl`
- `config/niri/imperative/generated-scale.kdl`
- `config/quickshell/qs_colors.json`
- `config/quickshell/settings.json`

They are included as defaults only. Runtime caches and state are ignored.

## Personal Files Not Included In Core

- Booru/browser subsystem
- Credentials and `.env` files
- Backups and generated Python caches
- Vendored downloader/browser code
- Original machine-specific Niri profile, moved to `optional/personal/niri/machine-example.kdl`
- Steam/game-specific rules, moved to `optional/gaming/niri/steam-games.kdl`

## Hyprland Dependencies Removed From Core

- Quickshell no longer launches from `~/.config/hypr/scripts/quickshell`
- Settings no longer read `~/.config/hypr/settings.json`
- Niri generated keybinds now read `~/.config/quickshell/settings.json`
- Niri helper scripts live under `~/.config/niri/scripts`
- Hyprland monitor mutation was disabled in the Quickshell settings UI
- Hyprland keyboard-layout watcher was replaced with a neutral `localectl` query
- Focus-time tracking now uses Niri focused-window data

## Known Follow-Up Items

- The lock program is still `hyprlock`, but its config is staged under `config/niri/hyprlock.conf`.
- `hyprpolkitagent` remains a startup command. It is a package/runtime dependency, not a dependency on the Hyprland config tree.
- `launch-igpu.sh` contains optional NVIDIA isolation logic and should be documented as hardware-specific.
