Omarchy Statusline v0.2.3 delegates plugin updates to Omarchy’s plugin manager.

## Fixes and improvements

- Removed the custom Python Git updater and its remote checks, downloads and update application code.
- Settings → Updates now reads the installed version from the local manifest and shows the host plugin update command, a marketplace link and an explicit shell reload action.
- Addressed marketplace review #7752: the plugin no longer fetches mutable origin HEAD or buffers remote Git output and manifest data.
- System monitoring, layouts and saved preferences are unchanged.

## 本次修复

移除插件自带的 Git 检查和更新逻辑，改由 Omarchy 插件管理器处理更新。设置页保留本地版本显示、更新命令说明、市场链接和重载 Shell 按钮。

## Updating

For a normal Git-managed installation, run:

```sh
omarchy plugin update lucas.system-pulse
```

Follow Omarchy’s prompts, then run `omarchy restart shell` to load the new QML components. This restarts the whole shell. Development installations should be updated manually through their source checkout.

New installation (Quickshell-based Omarchy Shell and Python 3.11+ required):

```sh
omarchy plugin add https://github.com/lucaslus/omarchy-statusline.git --enable --yes
```

## Validation

Run the Python unit tests, installer/uninstaller shell syntax checks, Omarchy manifest validator and native QML regression suite. The QML suite covers local version display and host update guidance alongside monitoring lifecycle, settings and responsive layouts.
