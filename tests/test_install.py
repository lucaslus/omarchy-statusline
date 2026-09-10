import os
from pathlib import Path
import subprocess
import tempfile
import unittest


class InstallTests(unittest.TestCase):
    def test_enable_waits_for_asynchronous_registration(self):
        with tempfile.TemporaryDirectory() as d:
            root = Path(d)
            bin_dir = root / 'bin'
            bin_dir.mkdir()
            state = root / 'scan-count'
            shell = bin_dir / 'omarchy-shell'
            shell.write_text('''#!/usr/bin/env python3
import json, os, pathlib, sys
p = pathlib.Path(os.environ['TEST_SCAN_STATE'])
if sys.argv[-1] == 'listPlugins':
    n = int(p.read_text()) + 1 if p.exists() else 1
    p.write_text(str(n))
    print(json.dumps([] if n < 3 else [{'id':'lucas.system-pulse'}]))
''')
            cli = bin_dir / 'omarchy'
            cli.write_text('''#!/usr/bin/env python3
import os,pathlib,sys
assert int(pathlib.Path(os.environ['TEST_SCAN_STATE']).read_text()) >= 3, 'enabled before registration'
''')
            shell.chmod(0o755)
            cli.chmod(0o755)
            repo = Path(__file__).resolve().parents[1]
            result = subprocess.run(['bash', str(repo / 'scripts/install.sh')], env={**os.environ, 'HOME': d, 'XDG_CONFIG_HOME': str(root / 'config'), 'PATH': str(bin_dir) + os.pathsep + os.environ['PATH'], 'TEST_SCAN_STATE': str(state)}, capture_output=True, text=True, timeout=10)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(state.read_text(), '3')
            self.assertEqual((root / 'config/omarchy/plugins/lucas.system-pulse').resolve(), repo)


if __name__ == '__main__':
    unittest.main()
