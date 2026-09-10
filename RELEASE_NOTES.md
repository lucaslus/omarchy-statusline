First public release of Omarchy Statusline, a native Omarchy Shell system monitor.

- CPU usage, per-core bars, memory meter and GPU history in the existing status bar.
- Separate CPU and GPU temperatures with live graphs.
- Compact system panel with CPU/GPU models, VRAM, power, fan speed and hotspot temperature.
- Omarchy theme integration, custom layouts, metric ordering and sampling controls.
- Shared multi-monitor collector, startup controls and manual updates.

## Install

Requires the Quickshell-based Omarchy Shell and Python 3.11 or newer.

```sh
omarchy plugin add https://github.com/lucaslus/omarchy-statusline.git --enable --yes
```

The attached archive contains the tagged source; SHA256SUMS verifies its checksum. Extract it and run `./scripts/install.sh` for a development-style installation (keep the extracted directory in place). Native Git installation is recommended for in-app updates.

Python and shell checks run in CI before publishing. Native QML regression tests were run locally on Omarchy. NVIDIA support is fixture-tested; hardware validation was performed with AMD. Memory module model/speed detection is not included.
