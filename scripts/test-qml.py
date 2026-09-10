#!/usr/bin/env python3
"""Run native QML regression tests in a temporary, windowless Quickshell instance."""
from pathlib import Path
import os
import shutil
import subprocess
import sys
import tempfile

repo = Path(__file__).resolve().parents[1]
shell = Path(os.environ.get('OMARCHY_PATH', '/usr/share/omarchy')) / 'shell'
if not shutil.which('quickshell') or not (shell / 'Ui').is_dir():
    sys.exit('Requires Quickshell and the Omarchy Shell QML modules.')
with tempfile.TemporaryDirectory(prefix='pulse-qml-test-') as directory:
    root = Path(directory)
    pulse = root / 'Pulse'
    pulse.mkdir()
    for path in repo.iterdir():
        if path.suffix in ('.qml', '.js', '.py') or path.name in ('qmldir', 'manifest.json'):
            shutil.copy2(path, pulse / path.name)
    for module in ('Commons', 'Ui'):
        (root / module).symlink_to(shell / module, target_is_directory=True)
    shutil.copy2(repo / 'tests/qml/shell.qml', root / 'shell.qml')
    result = subprocess.run(['quickshell', '-p', str(root), '--no-color'], capture_output=True, text=True, timeout=25)
    output = result.stdout + result.stderr
    print(output)
    failed = result.returncode != 0 or 'PULSE_TEST_PASS' not in output or any(s in output for s in ('PULSE_TEST_FAIL', 'ReferenceError:', 'TypeError:', 'Binding loop', 'ERROR:'))
    sys.exit(1 if failed else 0)
