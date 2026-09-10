Omarchy Statusline v0.2.1 adds disk monitoring and simplifies the update interface.

- Show root filesystem (`/`) usage, used capacity and free space in the system panel.
- Show aggregate read/write throughput across whole hardware drives, without double-counting partitions or device-mapper layers.
- Add an optional **Disk /** status bar meter in Settings → Layout.
- Unify display names as **Omarchy Statusline** and shorten update messages.
- Preserve existing plugin identity and saved settings for compatibility.

The panel keeps its fixed size; scroll to see additional information. Disk throughput is unavailable until the second sample. Existing status bar layouts remain unchanged until Disk is enabled.

## Install

Requires Quickshell-based Omarchy Shell and Python 3.11+.

```sh
omarchy plugin add https://github.com/lucaslus/omarchy-statusline.git --enable --yes
```

For an existing Git-managed installation, use Settings → Updates, then reload Omarchy Shell. Development checkouts should be updated manually.

The source archive includes an installer (`./scripts/install.sh`); keep its extracted directory in place. SHA256SUMS provides the archive checksum.

Validation: 23 Python tests, shell syntax checks and local native QML regression tests. CI repeats Python and shell checks before publishing; native QML tests require Omarchy and run locally.
