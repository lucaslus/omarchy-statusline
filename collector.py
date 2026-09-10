#!/usr/bin/env python3
"""Read-only Linux telemetry. One JSON line every two seconds; no pip dependencies."""
import argparse
from functools import lru_cache
import json
from pathlib import Path
import re
import shutil
import shlex
import subprocess
import time
import tomllib


def read(path):
    try:
        return Path(path).read_text().strip()
    except (OSError, UnicodeError):
        return ""


def number(path, scale=1):
    try:
        return float(read(path)) / scale
    except ValueError:
        return None


def cpu_ticks(raw):
    result = {}
    for line in raw.splitlines():
        fields = line.split()
        if fields and re.fullmatch(r"cpu\d*", fields[0]) and len(fields) >= 5:
            values = [int(v) for v in fields[1:9]]  # guest already included in user/nice
            result[fields[0]] = (sum(values), values[3] + (values[4] if len(values) > 4 else 0))
    return result


def cpu_percent(current, previous):
    result = {}
    for key, (total, idle) in current.items():
        old = previous.get(key)
        dt = total - old[0] if old else 0
        result[key] = round(max(0, min(100, 100 * (dt - (idle - old[1])) / dt)), 1) if dt > 0 else None
    return result


def memory(raw):
    fields = {}
    for line in raw.splitlines():
        parts = line.split()
        if len(parts) >= 2:
            fields[parts[0].rstrip(":")] = int(parts[1]) * 1024
    total = fields.get("MemTotal", 0)
    available = fields.get("MemAvailable")
    if not total or available is None:
        return {"percent": None, "used": None, "total": total or None}
    used = max(0, total - available)
    return {"percent": round(100 * used / total, 1), "used": used, "total": total}


def sensors(root):
    result = []
    for hw in sorted(root.glob("class/hwmon/hwmon*")):
        name = read(hw / "name")
        for path in sorted(hw.glob("temp*_input")):
            value = number(path, 1000)
            if value is not None and -20 <= value <= 150:
                label = read(path.with_name(path.name.replace("_input", "_label"))) or name
                result.append({"driver": name, "label": label, "value": value})
    return result


def cpu_model(raw):
    fields = dict(line.split(":", 1) for line in raw.splitlines() if ":" in line)
    fields = {key.strip(): value.strip() for key, value in fields.items()}
    return fields.get("model name") or fields.get("Hardware") or fields.get("Processor") or ""


@lru_cache(maxsize=32)
def gpu_model(address, vendor, device, revision):
    # AMD's revision-specific database identifies the product more precisely
    # than the PCI family name. Cache static identity, never live telemetry.
    if vendor == "0x1002":
        for line in read("/usr/share/libdrm/amdgpu.ids").splitlines():
            parts = [part.strip() for part in line.split(",", 2)]
            if len(parts) == 3 and parts[0].lower() == device.removeprefix("0x").lower() and parts[1].lower() == revision.removeprefix("0x").lower():
                return parts[2]
    if re.fullmatch(r"[0-9a-fA-F]{4}:[0-9a-fA-F]{2}:[0-9a-fA-F]{2}\.[0-7]", address):
        try:
            output = subprocess.run(["lspci", "-D", "-mm", "-s", address], capture_output=True, text=True, timeout=1, check=True).stdout
            parts = shlex.split(output)
            if len(parts) >= 4:
                return parts[3]
        except (OSError, subprocess.SubprocessError, ValueError):
            pass
    return {"0x1002": "AMD Radeon GPU", "0x10de": "NVIDIA GPU", "0x8086": "Intel GPU"}.get(vendor, "GPU")


def gpu_sysfs(root):
    gpus = []
    for card in sorted(root.glob("class/drm/card*")):
        if not re.fullmatch(r"card\d+", card.name):
            continue
        device = card / "device"
        vendor = read(device / "vendor")
        if not vendor:
            continue
        hw = next(iter(sorted(device.glob("hwmon/hwmon*"))), None)
        temps = {}
        if hw:
            for p in sorted(hw.glob("temp*_input")):
                label = read(p.with_name(p.name.replace("_input", "_label"))).lower()
                temps[label or "edge"] = number(p, 1000)
        total = number(device / "mem_info_vram_total")
        used = number(device / "mem_info_vram_used")
        gpus.append({"id": card.name, "vendor": vendor, "name": gpu_model(device.resolve().name, vendor, read(device / "device"), read(device / "revision")),
                     "percent": number(device / "gpu_busy_percent"), "total": total, "used": used,
                     "temperature": temps.get("edge"), "hotspot": temps.get("junction"),
                     "power": number(hw / "power1_average", 1e6) if hw else None,
                     "fan": number(hw / "fan1_input") if hw else None})
    return gpus


def nvidia():
    if not shutil.which("nvidia-smi"):
        return []
    try:
        output = subprocess.run(["nvidia-smi", "--query-gpu=index,name,utilization.gpu,memory.used,memory.total,temperature.gpu,power.draw", "--format=csv,noheader,nounits"], capture_output=True, text=True, timeout=1.2, check=True).stdout
        result = []
        for row in output.splitlines():
            parts = [p.strip() for p in row.split(",")]
            if len(parts) != 7:
                continue
            def val(i, scale=1):
                try:
                    return float(parts[i]) * scale
                except ValueError:
                    return None
            result.append({"id": "nvidia-" + parts[0], "name": parts[1], "percent": val(2), "used": val(3, 1048576), "total": val(4, 1048576), "temperature": val(5), "power": val(6), "fan": None, "hotspot": None})
        return result
    except (OSError, subprocess.SubprocessError):
        return []


def palette():
    # Theme swaps replace a directory/symlink: reopen instead of watching its old inode.
    home = Path.home()
    candidates = [home / ".local/state/omarchy/current/theme/colors.toml", home / ".config/omarchy/current/theme/colors.toml"]
    for path in candidates:
        try:
            colors = tomllib.loads(path.read_text())
            return {k: v for k, v in colors.items() if isinstance(v, str) and re.fullmatch(r"#[0-9a-fA-F]{6}", v)}
        except (OSError, ValueError):
            continue
    return {}


class Collector:
    def __init__(self, proc=Path("/proc"), sys=Path("/sys"), use_nvidia=True):
        self.proc, self.sys = proc, sys
        self.previous = {}
        self.cpu_model = cpu_model(read(proc / "cpuinfo"))
        self.use_nvidia = use_nvidia

    def sample(self):
        ticks = cpu_ticks(read(self.proc / "stat"))
        loads = cpu_percent(ticks, self.previous)
        self.previous = ticks
        temperatures = sensors(self.sys)
        cpu_temps = [t["value"] for t in temperatures if t["driver"] in ("coretemp", "k10temp", "zenpower", "cpu_thermal")]
        gpus = gpu_sysfs(self.sys)
        nv = nvidia() if self.use_nvidia and any(g.get("vendor") == "0x10de" for g in gpus) else []
        if nv:
            gpus = [g for g in gpus if g.get("vendor") != "0x10de"] + nv
        # Prefer a GPU with utilization telemetry, while retaining all adapters in the payload.
        gpu = next((g for g in gpus if g["percent"] is not None), gpus[0] if gpus else {})
        return {"time": time.time(), "cpu": loads.get("cpu"), "cores": [loads[k] for k in sorted(loads, key=lambda k: int(k[3:] or -1)) if k != "cpu"],
                "cpuModel": self.cpu_model, "cpuTemperature": max(cpu_temps) if cpu_temps else None,
                "memory": memory(read(self.proc / "meminfo")), "gpu": gpu, "gpus": gpus, "palette": palette(),
                "error": "Cannot read /proc CPU or memory data" if not ticks or not read(self.proc / "meminfo") else ""}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--once", action="store_true")
    parser.add_argument("--interval", type=int, choices=(1, 2, 5), default=2)
    args = parser.parse_args()
    collector = Collector()
    if args.once:
        collector.sample()
        time.sleep(0.15)
    while True:
        start = time.monotonic()
        print(json.dumps(collector.sample(), allow_nan=False), flush=True)
        if args.once:
            return
        time.sleep(max(0.1, args.interval - (time.monotonic() - start)))


if __name__ == "__main__":
    try:
        main()
    except (BrokenPipeError, KeyboardInterrupt):
        pass
