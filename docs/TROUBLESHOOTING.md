# Troubleshooting

## Quickshell Does Not Start

Run:

```fish
quickshell -p ~/.config/quickshell/Shell.qml
```

Check that `quickshell`, Qt/QML dependencies, and the files under `~/.config/quickshell` are installed.

## Keybinds Do Not Update

Run:

```fish
~/.config/niri/scripts/settings_watcher.sh --compile
```

Then validate Niri:

```fish
niri validate --config ~/.config/niri/config.kdl
```

## Screenshots Fail

Install the screenshot tools listed in `docs/DEPENDENCIES.md`: `grim`, `slurp`, `imagemagick`, `wl-clipboard`, `satty`, and `zbar`.

## Recording Fails

Region recording uses `gpu-screen-recorder`. The Waybar fullscreen recorder uses `wf-recorder` and currently expects an NVIDIA-capable FFmpeg build for NVENC.

## Wallpaper Colors Do Not Change

Install either `pywal` or `matugen`, then apply a wallpaper again from the Quickshell wallpaper picker.

## Existing Config Was Replaced

The installer moves conflicting paths into:

```fish
~/.local/state/niri-quickshell-rice/backups/
```

Move the backup path back into `~/.config` to restore the previous config.
