# Omarchy Statusline v0.3.0

This release adds per-adapter GPU monitoring throughout the bar, settings, and detail panel.

## What's new

- Show each detected GPU's utilization and temperature separately in the status bar, with its own history. Settings identifies adapters by name and lets you toggle each GPU's load and temperature readouts independently; preferences are saved by adapter ID.
- Show every detected GPU in the detail panel with its own utilization, VRAM, power, fan, temperature, hotspot, and history where the hardware exposes them. CPU temperature now sits with CPU information. The separate temperature section has been removed.
- Simplify bar presets to Default, Overview, and Minimal. Default is the initial preset; older `custom` and `compact` bar preferences continue to load as Default. Minimal uses short labels and hides charts.
- Remove the widget's selected outline and increase the gap between bar content and Omarchy's open-panel indicator.
- Replace the README and marketplace preview screenshots with native captures. Hackerman and Ristretto are labeled as examples; the widget follows the active Omarchy theme.

Unsupported sensor values continue to display `—`. AMD hardware and the native QML integration were exercised locally; NVIDIA telemetry remains covered by fixtures rather than a physical NVIDIA test.

## Updating

For a normal Git-managed installation, run:

```sh
omarchy plugin update lucas.system-pulse
```

Follow Omarchy's prompts, then use **Reload shell** in Settings or run `omarchy restart shell` to load the new QML components. Development symlinks use their local source checkout instead. The Marketplace's verified listing is updated separately through its exact-commit verification and publication workflow.

## Validation

- `omarchy plugin validate .`
- `python3 -m unittest discover -s tests -v` (15 tests)
- `python3 scripts/test-qml.py` (native QML regression suite)
- `bash -n scripts/install.sh scripts/uninstall.sh`
- `python3 -m json.tool manifest.json`
- `git diff --check`
