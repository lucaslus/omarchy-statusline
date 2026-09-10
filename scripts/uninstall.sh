#!/usr/bin/env bash
set -euo pipefail
repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
destination="${XDG_CONFIG_HOME:-$HOME/.config}/omarchy/plugins/lucas.system-pulse"
# Only remove the development link owned by this checkout, never an unrelated install.
if [[ ! -L "$destination" || $(readlink -f -- "$destination") != "$repo" ]]; then
  echo "No development link for this checkout at $destination" >&2
  exit 1
fi
omarchy plugin disable lucas.system-pulse
rm -- "$destination"
omarchy-shell shell rescanPlugins
