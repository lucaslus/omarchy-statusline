#!/usr/bin/env python3
"""Read update status; apply only a checked fast-forward in a clean installed checkout."""
import argparse
import fcntl
import json
import os
from pathlib import Path
import re
import subprocess

PLUGIN_ID = "lucas.system-pulse"
INSTALL_PATH = Path(__file__).absolute().parent
GIT_ENV = {**os.environ, "GIT_TERMINAL_PROMPT": "0", "GIT_SSH_COMMAND": "ssh -oBatchMode=yes -oConnectTimeout=10"}


def git(repo, *args):
    result = subprocess.run(["git", "-C", str(repo), *args], env=GIT_ENV, capture_output=True, text=True, timeout=30)
    if result.returncode:
        raise RuntimeError(result.stderr.strip() or "Git command failed")
    return result.stdout.strip()


def local_status(repo=INSTALL_PATH):
    manifest = json.loads((repo / "manifest.json").read_text())
    status = {"version": manifest["version"], "canUpdate": False, "target": "", "development": repo.is_symlink() or (repo / ".git").is_file()}
    if status["development"]:
        status["message"] = "Development install · update source manually."
        return status
    if not (repo / ".git").exists():
        status["message"] = "Manual install · Git updates unavailable."
        return status
    try:
        status["head"] = git(repo, "rev-parse", "HEAD")
    except RuntimeError:
        status["message"] = "No committed version."
        return status
    status["dirty"] = bool(git(repo, "status", "--porcelain", "--untracked-files=all"))
    status["message"] = "Local changes · update blocked." if status["dirty"] else "Not checked yet."
    return status


def check(repo=INSTALL_PATH):
    result = local_status(repo)
    if result.get("development") or "head" not in result or result.get("dirty"):
        return result
    # Fetch records exactly the commit offered in the UI. It does not change checked-out files.
    git(repo, "fetch", "--quiet", "--no-tags", "origin", "HEAD")
    target = git(repo, "rev-parse", "FETCH_HEAD")
    if target == result["head"]:
        result["message"] = "Up to date."
    elif git(repo, "merge-base", result["head"], target) != result["head"]:
        result["message"] = "History diverged · update manually."
    else:
        validate_target(repo, target)
        result.update(canUpdate=True, target=target, message="Update available: " + target[:8])
    return result


def validate_target(repo, target):
    manifest = json.loads(git(repo, "show", target + ":manifest.json"))
    if manifest.get("id") != PLUGIN_ID or manifest.get("schemaVersion") != 1:
        raise RuntimeError("The update is not a compatible Omarchy Statusline plugin.")
    entry = manifest.get("entryPoints", {}).get("barWidget")
    if not isinstance(entry, str) or not entry or Path(entry).is_absolute() or ".." in Path(entry).parts:
        raise RuntimeError("The update has an invalid bar widget entry point.")
    git(repo, "cat-file", "-e", target + ":" + entry)


def apply_update(repo, target):
    if not re.fullmatch(r"[0-9a-f]{40}|[0-9a-f]{64}", target):
        raise RuntimeError("Check for updates before applying one.")
    state = local_status(repo)
    if state.get("development") or "head" not in state or state.get("dirty"):
        raise RuntimeError(state["message"])
    lock_path = Path(git(repo, "rev-parse", "--absolute-git-dir")) / "system-pulse-update.lock"
    with lock_path.open("w") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        # Recheck inside the lock. Never stash, reset, or overwrite user edits.
        if git(repo, "status", "--porcelain", "--untracked-files=all"):
            raise RuntimeError("Local changes appeared. Update cancelled.")
        head = git(repo, "rev-parse", "HEAD")
        if git(repo, "merge-base", head, target) != head:
            raise RuntimeError("The checked update is no longer a fast-forward. Check again.")
        validate_target(repo, target)
        git(repo, "merge", "--ff-only", "--no-edit", "--no-overwrite-ignore", target)
    return "Updated to " + target[:8] + ". Reload shell to apply."


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=("status", "check", "apply"))
    parser.add_argument("target", nargs="?", default="")
    args = parser.parse_args()
    try:
        if args.action == "apply":
            print(apply_update(INSTALL_PATH, args.target))
            if os.isatty(0):
                input("Press Enter to close this terminal.")
        else:
            print(json.dumps(local_status() if args.action == "status" else check()))
    except (OSError, ValueError, RuntimeError, subprocess.SubprocessError) as exc:
        if args.action == "apply":
            print("Update stopped: " + str(exc))
            if os.isatty(0):
                input("Press Enter to close this terminal.")
        else:
            print(json.dumps({"canUpdate": False, "message": str(exc)}))
        raise SystemExit(1)


if __name__ == "__main__":
    main()
