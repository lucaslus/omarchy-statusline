#!/usr/bin/env bash
set -euo pipefail
repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
config_dir="${XDG_CONFIG_HOME:-$HOME/.config}/omarchy"
destination="$config_dir/plugins/lucas.system-pulse"
command -v omarchy-shell >/dev/null || { echo 'Requires the Quickshell-based Omarchy Shell.' >&2; exit 1; }
python3 -c 'import tomllib' || { echo 'Requires Python 3.11 or later.' >&2; exit 1; }
mkdir -p "$config_dir/plugins"
if [[ -e "$destination" || -L "$destination" ]]; then
  [[ $(readlink -f -- "$destination") == "$repo" ]] || { echo "Already exists: $destination (left untouched)" >&2; exit 1; }
else
  ln -s -- "$repo" "$destination"
fi
if [[ -f "$config_dir/shell.json" ]]; then
  cp -p -- "$config_dir/shell.json" "$config_dir/shell.json.before-system-pulse.$(date +%Y%m%d%H%M%S).bak"
fi
omarchy-shell shell rescanPlugins
# rescanPlugins starts an asynchronous registry scan. Wait for this plugin, not
# an arbitrary fixed sleep, before enabling a first-time installation.
registered=false
for attempt in {1..60}; do
  if omarchy-shell shell listPlugins | python3 -c 'import json,sys; sys.exit(0 if any(p.get("id") == "lucas.system-pulse" for p in json.load(sys.stdin)) else 1)' 2>/dev/null; then
    registered=true
    break
  fi
  sleep 0.2
done
if [[ $registered != true ]]; then
  echo 'Timed out waiting for plugin registration. Check the Omarchy Shell log and retry.' >&2
  exit 1
fi
omarchy plugin enable lucas.system-pulse --section right --index 0
printf 'System Pulse is installed in your existing bar. Keep the repository at %s\n' "$repo"
