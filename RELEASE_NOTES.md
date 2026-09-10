Omarchy Statusline v0.2.2 fixes status bar metrics overlapping the centered date and time on narrow or portrait monitors.

## Fixes and improvements

- **Prevent clock overlap:** reserve space for the center clock and neighboring bar widgets before sizing the monitor widget.
- **Adapt per monitor:** each screen uses its own available width, including desktop scaling. A portrait monitor can show a shorter readout while a wide monitor retains the full layout.
- **Reduce content progressively:** hide charts first, then display only the metrics that fit in the saved order. When space is very limited, collapse to a small launcher. Click to access the complete system panel.
- **Restore automatically:** bring back the configured metrics and charts as space becomes available. Saved layout, metric order and monitoring settings are preserved.
- **Handle changing bar contents:** account for neighboring widget widths, including a growing system tray, and constrain rendering to the widget bounds.

## 本次修复

修复竖屏或窄屏上，性能指标与居中的日期时间重叠的问题。每块屏幕独立计算剩余空间：先隐藏图表，再按已保存的顺序减少指标，空间极小时收起为入口按钮。空间恢复后自动还原完整布局，不修改用户设置；点击仍可查看完整数据。

## Updating

For an existing Git-managed installation, open **Settings → Updates**, check for updates, run **Update in terminal**, then **reload Omarchy Shell**. A full shell reload clears cached QML components; rescanning plugins alone may keep the old layout.

Updates track the repository's default branch. This release does not change the updater itself. Development symlinks and local checkouts are not automatically updated; use a regular Git-managed plugin installation to test the update flow.

New installation (Quickshell-based Omarchy Shell and Python 3.11+ required):

```sh
omarchy plugin add https://github.com/lucaslus/omarchy-statusline.git --enable --yes
```

The source archive includes `./scripts/install.sh`; keep its extracted directory in place. SHA256SUMS provides the archive checksum.

## Validation

- Python unit tests and installer/uninstaller shell syntax checks.
- Native QML regression checks for narrow-screen fitting, clock clearance, crowded-tray fallback, wide-screen restoration and preserved preferences, plus existing lifecycle/settings coverage.
- Visual verification on a portrait monitor (about 1234 logical pixels wide) and a landscape monitor (about 2194 logical pixels wide) after restarting Omarchy Shell.
- GitHub Actions repeats Python, shell and version/tag checks before publishing. The end-to-end user update flow remains to be verified after publication.
