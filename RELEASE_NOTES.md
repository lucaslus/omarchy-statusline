# Omarchy Statusline v0.4.0

This release refines the status bar and settings while preserving per-adapter GPU monitoring and the existing `lucas.system-pulse` plugin ID.

## What's new

- Put each bar metric's full label on the left and its value above the chart on the right. Center the readouts vertically in the host bar.
- Offer Default and Minimal bar layouts. Minimal keeps full labels and hides charts. Existing Overview, Custom, and Compact preferences load as Default; saved stacked-label preferences are ignored.
- Improve metric contrast when a transparent bar sits over a light background, while keeping theme colors on dark backgrounds.
- Refresh Settings colors and simplify Updates to the installed version, Omarchy's plugin update command, and the official guide.
- Replace the README screenshots with consistent captures from empty workspaces under Hackerman, Ristretto, and Tokyo Night. Refresh the marketplace preview.

This update also includes the unpublished v0.3.0 changes since the current marketplace snapshot: separate utilization and temperature readings for each detected GPU in the bar, settings, and detail panel; CPU temperature in its CPU row; and removal of the standalone temperature section. Unsupported sensor values display `—`.

## Updating

For a normal Git-managed installation, run:

```sh
omarchy plugin update lucas.system-pulse
```

Omarchy uses the saved Git remote and rescans plugins after updating. If the updated interface does not appear, run `omarchy restart shell` to clear cached QML components. Development symlinks use their source checkout instead. Marketplace verification and publication are a separate process tied to the exact upstream commit.

## Validation

- `omarchy plugin validate .`
- `python3 -m unittest discover -s tests -v`
- `python3 scripts/test-qml.py`
- `bash -n scripts/install.sh scripts/uninstall.sh`
- `python3 -m json.tool manifest.json`
- `git diff --check`
