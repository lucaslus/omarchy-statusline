import json
import subprocess
import tempfile
import unittest
from pathlib import Path
import maintenance


class UpdateTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.remote = self.root / 'origin'
        self.remote.mkdir()
        self.run_git(self.remote, 'init', '-b', 'main')
        self.run_git(self.remote, 'config', 'user.email', 'test@example.invalid')
        self.run_git(self.remote, 'config', 'user.name', 'Test')
        (self.remote / 'manifest.json').write_text(json.dumps({'id': maintenance.PLUGIN_ID, 'schemaVersion': 1, 'version': '1.0.0', 'entryPoints': {'barWidget': 'Widget.qml'}}))
        (self.remote / 'Widget.qml').write_text('import QtQuick\nItem {}\n')
        self.commit(self.remote, 'initial')
        self.local = self.root / 'installed'
        subprocess.run(['git', 'clone', '-q', str(self.remote), str(self.local)], check=True)

    def run_git(self, repo, *args):
        return subprocess.run(['git', '-C', str(repo), *args], check=True, capture_output=True, text=True).stdout.strip()

    def commit(self, repo, message):
        self.run_git(repo, 'add', '.')
        self.run_git(repo, 'commit', '-qm', message)
        return self.run_git(repo, 'rev-parse', 'HEAD')

    def advance(self):
        (self.remote / 'Widget.qml').write_text('import QtQuick\nItem { width: 20 }\n')
        return self.commit(self.remote, 'update')

    def test_current_checkout(self):
        self.assertFalse(maintenance.check(self.local)['canUpdate'])

    def test_check_does_not_modify_worktree_and_apply_fast_forwards(self):
        old = self.run_git(self.local, 'rev-parse', 'HEAD')
        target = self.advance()
        result = maintenance.check(self.local)
        self.assertTrue(result['canUpdate'])
        self.assertEqual(self.run_git(self.local, 'rev-parse', 'HEAD'), old)
        maintenance.apply_update(self.local, result['target'])
        self.assertEqual(self.run_git(self.local, 'rev-parse', 'HEAD'), target)

    def test_development_link_never_updates_source(self):
        link = self.root / 'development'
        link.symlink_to(self.local, target_is_directory=True)
        self.assertTrue(maintenance.check(link)['development'])
        with self.assertRaisesRegex(RuntimeError, 'Development install'):
            maintenance.apply_update(link, self.run_git(self.local, 'rev-parse', 'HEAD'))

    def test_edits_after_check_block_update(self):
        self.advance()
        target = maintenance.check(self.local)['target']
        (self.local / 'Widget.qml').write_text('local change')
        with self.assertRaisesRegex(RuntimeError, 'Local changes'):
            maintenance.apply_update(self.local, target)
        self.assertEqual((self.local / 'Widget.qml').read_text(), 'local change')

    def test_invalid_manifest_is_rejected_before_apply(self):
        manifest = json.loads((self.remote / 'manifest.json').read_text())
        manifest['id'] = 'other.plugin'
        (self.remote / 'manifest.json').write_text(json.dumps(manifest))
        self.commit(self.remote, 'invalid')
        old = self.run_git(self.local, 'rev-parse', 'HEAD')
        with self.assertRaisesRegex(RuntimeError, 'compatible'):
            maintenance.check(self.local)
        self.assertEqual(self.run_git(self.local, 'rev-parse', 'HEAD'), old)

    def test_update_uses_checked_commit_even_if_remote_advances(self):
        first = self.advance()
        target = maintenance.check(self.local)['target']
        (self.remote / 'extra').write_text('later update')
        self.commit(self.remote, 'later')
        maintenance.apply_update(self.local, target)
        self.assertEqual(self.run_git(self.local, 'rev-parse', 'HEAD'), first)

    def test_ignored_file_is_not_overwritten(self):
        (self.remote / '.gitignore').write_text('private.txt\n')
        self.commit(self.remote, 'ignore')
        maintenance.apply_update(self.local, maintenance.check(self.local)['target'])
        (self.local / 'private.txt').write_text('private local data')
        (self.remote / 'private.txt').write_text('new upstream file')
        self.run_git(self.remote, 'add', '-f', 'private.txt')
        self.run_git(self.remote, 'commit', '-qm', 'track previously ignored path')
        target = maintenance.check(self.local)['target']
        with self.assertRaises(RuntimeError):
            maintenance.apply_update(self.local, target)
        self.assertEqual((self.local / 'private.txt').read_text(), 'private local data')

    def test_untracked_user_file_blocks_update(self):
        (self.local / 'notes').write_text('keep me')
        self.assertFalse(maintenance.check(self.local)['canUpdate'])


if __name__ == '__main__':
    unittest.main()
