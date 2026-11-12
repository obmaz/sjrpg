"""CI 중복 실행과 검사 실패 뒤 빌드 진행을 회귀 검사한다. Godot는 실행하지 않는다."""
from contextlib import redirect_stdout
import io
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

from check_workflows import check_workflows
from prepare_combat_review import HOOK, ROOT as REVIEW_ROOT, prepare

ROOT = Path(__file__).resolve().parents[1]


class WorkflowPolicyTest(unittest.TestCase):
    DEPLOY = 'on:\n  workflow_dispatch:\npermissions:\n  contents: read\n'

    def folder(self, root):
        folder = root / '.github/workflows'
        folder.mkdir(parents=True)
        return folder

    def test_workflows_run_only_manually(self):
        with tempfile.TemporaryDirectory() as temporary:
            folder = self.folder(Path(temporary))
            (folder / 'deploy-pages.yml').write_text(self.DEPLOY)
            diagnostic = folder / 'diagnostic.yml'
            diagnostic.write_text('on:\n  workflow_dispatch:\n')
            with redirect_stdout(io.StringIO()):
                check_workflows(Path(temporary))
            for extension in ['.yml', '.yaml']:
                alternate = folder / ('diagnostic' + extension)
                diagnostic.rename(alternate)
                diagnostic = alternate
                for events in ['push:', 'pull_request:', 'schedule:']:
                    diagnostic.write_text('on:\n  %s\n  workflow_dispatch:\n' % events)
                    with self.subTest(extension=extension, events=events), self.assertRaises(AssertionError):
                        check_workflows(Path(temporary))

    def test_deploy_workflow_cannot_run_on_push(self):
        with tempfile.TemporaryDirectory() as temporary:
            folder = self.folder(Path(temporary))
            (folder / 'deploy-pages.yml').write_text(self.DEPLOY.replace('  workflow_dispatch:', '  push:\n  workflow_dispatch:'))
            with self.assertRaises(AssertionError):
                check_workflows(Path(temporary))

    def test_manual_deploy_workflow_is_required(self):
        with tempfile.TemporaryDirectory() as temporary:
            folder = self.folder(Path(temporary))
            (folder / 'diagnostic.yml').write_text('on:\n  workflow_dispatch:\n')
            with self.assertRaises(AssertionError):
                check_workflows(Path(temporary))


class LocalEntryTest(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.write('tools/ci.sh', (ROOT / 'tools/ci.sh').read_text())
        for name in ['tools/check_workflows.py', 'tools/test_ci.py', 'sjrpg_3d/tools/test_stamp_web.py', 'sjrpg_3d/tools/test_import_project.py', 'sjrpg_3d/tools/test_resource_layout.py']:
            self.write(name, 'pass\n')
        for name in ['sjrpg_3d/tools/review/test_diagnostic_contracts.mjs', 'sjrpg_3d/tools/review/village/harness.test.mjs', 'sjrpg_3d/tools/check_native_style.mjs', 'sjrpg_3d/tools/check_combat_visibility.mjs']:
            self.write(name, '// valid module\n')
        self.write('tools/check.sh', '''#!/bin/bash
set -e
echo "check $*" >> commands
test "${FAIL_CHECK:-0}" != 1
if [[ "$*" == *--export* ]]; then
    mkdir -p build/web/2d build/web/3d
    touch build/web/2d/index.html build/web/3d/index.html
fi
''')
        self.write('sjrpg_3d/tools/export_web.sh', '''#!/bin/bash
set -e
echo export3d >> commands
test "${FAIL_EXPORT:-0}" != 1
mkdir -p sjrpg_3d/build/web
touch sjrpg_3d/build/web/index.html
''')
        self.write('tools/check_browser_review.sh', '#!/bin/bash\necho "browser $*" >> commands\n')

    def write(self, name, text):
        path = self.root / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text)
        if path.suffix == '.sh':
            path.chmod(0o755)

    def run_entry(self, *arguments, **environment):
        result = subprocess.run([str(self.root / 'tools/ci.sh'), *arguments], cwd=self.root,
                                env={**os.environ, **environment}, capture_output=True, text=True)
        path = self.root / 'commands'
        commands = path.read_text().splitlines() if path.exists() else []
        return result, commands

    def test_default_checks_and_exports_only_3d(self):
        result, commands = self.run_entry()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(commands, ['check --project=3d', 'export3d'])
        self.assertTrue((self.root / 'build/ci/web/3d/index.html').is_file())
        self.assertFalse((self.root / 'build/ci/web/2d').exists())

    def test_failed_tests_do_not_export(self):
        result, commands = self.run_entry(FAIL_CHECK='1')
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(commands, ['check --project=3d'])
        self.assertFalse((self.root / 'build/ci/web').exists())

    def test_failed_village_harness_stops_before_game_checks(self):
        self.write('sjrpg_3d/tools/review/village/harness.test.mjs', 'throw new Error("harness contract failed");\n')
        result, commands = self.run_entry()
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(commands, [])

    def test_failed_export_cannot_pass_or_start_browser(self):
        result, commands = self.run_entry('--browser', FAIL_EXPORT='1')
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(commands, ['check --project=3d', 'export3d'])

    def test_explicit_all_editions_and_browser(self):
        result, commands = self.run_entry('--all-editions', '--browser')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(commands, ['check --export', 'browser all'])
        self.assertTrue((self.root / 'build/ci/web/2d/index.html').is_file())

    def test_unknown_option_fails_before_checks(self):
        result, commands = self.run_entry('--unknown')
        self.assertEqual(result.returncode, 2)
        self.assertEqual(commands, [])


class DisposableReviewTest(unittest.TestCase):
    def test_never_modifies_operating_checkout(self):
        with self.assertRaises(ValueError):
            prepare(REVIEW_ROOT)

    def test_same_observer_and_single_hook_on_repeated_preparation(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            main = root / 'sjrpg_3d/scripts/app/main.gd'
            main.parent.mkdir(parents=True)
            main.write_text('func _ready():\n\tshow_title()\n')
            prepare(root)
            prepare(root)
            self.assertEqual(main.read_text().count(HOOK), 1)
            self.assertEqual((main.parent / 'combat_visibility_review.gd').read_bytes(),
                             (ROOT / 'sjrpg_3d/tools/perf/combat_visibility_review.gd').read_bytes())


if __name__ == '__main__':
    unittest.main()
