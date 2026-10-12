"""Execute workflow shell steps against disposable packages and fake services.

No GitHub, pub.dev, tags, commits, or pushes are performed by these tests.
"""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


def shell_step(workflow, name):
    lines = (ROOT / '.github/workflows' / workflow).read_text().splitlines()
    start = lines.index('      - name: ' + name)
    run = next(i for i in range(start + 1, len(lines))
               if lines[i].startswith('        run: '))
    if lines[run] != '        run: |':
        return lines[run].removeprefix('        run: ')
    block = []
    for line in lines[run + 1:]:
        if line and not line.startswith('          '):
            break
        block.append(line[10:])
    return '\n'.join(block)


class ReleaseWorkflowsTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        shutil.copytree(ROOT / 'tool', self.root / 'tool',
                        ignore=shutil.ignore_patterns('__pycache__'))
        self.bin = self.root / 'bin'
        self.bin.mkdir()
        self.env = dict(os.environ, PATH=str(self.bin) + ':' + os.environ['PATH'],
                        PACKAGE='simple_telephony_android', BUMP='major',
                        DRY_RUN='false')
        self.package = self.root / 'simple_telephony_android'
        self.package.mkdir()
        (self.package / 'pubspec.yaml').write_text(
            'name: simple_telephony_android\nversion: 0.1.1\n')
        self.changelog = self.package / 'CHANGELOG.md'
        self.changelog.write_text(
            '## Unreleased\n\n### Changed\n- Require Query 0.3.0.\n\n'
            '## 0.1.1\n\n- Previous notes.\n')
        self.install_fake('git', '''#!/usr/bin/env bash
case "$1" in
  log) printf '%s\\n' '- Fix dependency floors' ;;
  tag) if [ "${2:-}" = '-a' ]; then exit 0; fi ;;
  diff|rev-parse|ls-remote) exit 1 ;;
  add|commit|push) exit 0 ;;
  *) echo "Unexpected git operation: $*" >&2; exit 99 ;;
esac
''')

    def install_fake(self, name, contents):
        script = self.bin / name
        script.write_text(contents)
        script.chmod(0o755)

    def run_step(self, workflow, name, cwd=None):
        return subprocess.run(['bash', '-euo', 'pipefail', '-c',
                               shell_step(workflow, name)],
                              cwd=cwd or self.root, env=self.env,
                              text=True, capture_output=True)

    def test_cut_moves_authored_notes_into_the_new_version(self):
        result = self.run_step('release.yml', 'Cut release')
        self.assertEqual(result.returncode, 0, result.stderr)
        content = self.changelog.read_text()
        self.assertTrue(content.startswith('## 1.0.0\n\n'))
        self.assertNotIn('## Unreleased', content)
        release, history = content.split('## 0.1.1', 1)
        self.assertIn('### Changed\n- Require Query 0.3.0.', release)
        self.assertIn('- Fix dependency floors', release)
        self.assertEqual(history, '\n\n- Previous notes.\n')
        self.assertEqual(content.count('Require Query 0.3.0.'), 1)

    def test_dry_run_previews_authored_notes_without_changing_files(self):
        self.env['DRY_RUN'] = 'true'
        before = self.changelog.read_text()
        result = self.run_step('release.yml', 'Cut release')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('Require Query 0.3.0.', result.stdout)
        self.assertEqual(self.changelog.read_text(), before)
        self.assertIn('version: 0.1.1',
                      (self.package / 'pubspec.yaml').read_text())

    def test_cut_without_unreleased_preserves_existing_history(self):
        self.changelog.write_text('## 0.1.1\n\n- Previous notes.\n')
        result = self.run_step('release.yml', 'Cut release')
        self.assertEqual(result.returncode, 0, result.stderr)
        content = self.changelog.read_text()
        self.assertTrue(content.startswith('## 1.0.0\n\n- Fix dependency floors'))
        self.assertTrue(content.endswith('## 0.1.1\n\n- Previous notes.\n'))
        self.assertEqual(content.count('## 0.1.1'), 1)

    def test_facade_cut_consumes_its_own_authored_notes(self):
        facade = self.root / 'simple_telephony_native'
        self.package.rename(facade)
        self.env['PACKAGE'] = 'simple_telephony_native'
        result = self.run_step('release.yml', 'Cut release')
        self.assertEqual(result.returncode, 0, result.stderr)
        content = (facade / 'CHANGELOG.md').read_text()
        self.assertTrue(content.startswith('## 1.0.0\n\n'))
        self.assertNotIn('## Unreleased', content)
        self.assertIn('Require Query 0.3.0.', content.split('## 0.1.1')[0])

    def test_cut_creates_missing_changelog(self):
        self.changelog.unlink()
        result = self.run_step('release.yml', 'Cut release')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.changelog.read_text(),
                         '## 1.0.0\n\n- Fix dependency floors\n\n')

    def test_deploy_resolves_hosted_dependencies_without_sibling_checkouts(self):
        (self.package / 'pubspec_overrides.yaml').write_text(
            'dependency_overrides:\n  simple_query:\n'
            '    path: ../../simple-query/packages/simple_query\n')
        example = self.package / 'example'
        example.mkdir()
        (example / 'pubspec.yaml').write_text('name: example\n')
        (example / 'pubspec_overrides.yaml').write_text('dependency_overrides: {}\n')
        original = (self.package / 'pubspec.yaml').read_text()
        self.install_fake('flutter', '''#!/usr/bin/env bash
if [ -n "$(find . -name pubspec_overrides.yaml -type f -print -quit)" ]; then
  echo 'Missing sibling checkout selected by development overrides' >&2
  exit 21
fi
if [ "$*" != 'pub get --no-example' ]; then
  echo "Unexpected Flutter operation: $*" >&2
  exit 22
fi
''')
        result = self.run_step('deploy.yml', 'Install dependencies', self.package)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse((self.package / 'pubspec_overrides.yaml').exists())
        self.assertFalse((example / 'pubspec_overrides.yaml').exists())
        self.assertEqual((self.package / 'pubspec.yaml').read_text(), original)


if __name__ == '__main__':
    unittest.main()
