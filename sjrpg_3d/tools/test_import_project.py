"""임포트 경계: 완료된 초기 폰트 캐시 중단만 재시도하고 오류는 보존한다."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

SCRIPT = Path(__file__).with_name('import_project.sh')
FONT = "ERROR: Cannot open file 'res://.godot/imported/font.ttf-abc.fontdata'."
DONE = '[ DONE ] reimport'


class ImportBoundaryTests(unittest.TestCase):
    def run_import(self, first_code, first_log, second_code=0, second_log=''):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            tools = root / 'tools'
            tools.mkdir()
            shutil.copyfile(SCRIPT, tools / 'import_project.sh')
            (tools / 'texture_policy.py').write_text('pass\n')
            engine = tools / 'godot.sh'
            engine.write_text('''#!/usr/bin/env python3
import os
from pathlib import Path
root = Path(__file__).parent
state = root / 'calls'
count = int(state.read_text()) + 1 if state.exists() else 1
state.write_text(str(count))
prefix = 'FIRST' if count == 1 else 'SECOND'
print(os.environ[prefix + '_LOG'])
raise SystemExit(int(os.environ[prefix + '_CODE']))
''')
            engine.chmod(0o755)
            env = dict(os.environ, FIRST_CODE=str(first_code), FIRST_LOG=first_log,
                       SECOND_CODE=str(second_code), SECOND_LOG=second_log)
            result = subprocess.run(['bash', str(tools / 'import_project.sh')],
                                    capture_output=True, text=True, env=env)
            return result, int((tools / 'calls').read_text())

    def test_clean_import_runs_once(self):
        result, calls = self.run_import(0, '')
        self.assertEqual((result.returncode, calls), (0, 1))

    def test_completed_font_bootstrap_abort_retries_once(self):
        result, calls = self.run_import(134, FONT + '\n' + DONE)
        self.assertEqual((result.returncode, calls), (0, 2))

    def test_existing_successful_font_bootstrap_still_retries(self):
        result, calls = self.run_import(0, FONT)
        self.assertEqual((result.returncode, calls), (0, 2))

    def test_unfinished_or_unrelated_abort_is_not_retried(self):
        for log in [FONT, DONE, 'ERROR: invalid mesh\n' + DONE]:
            with self.subTest(log=log):
                result, calls = self.run_import(134, log)
                self.assertEqual((result.returncode, calls), (1, 1))

    def test_script_failure_is_not_retried(self):
        result, calls = self.run_import(134, FONT + '\n' + DONE + '\nSCRIPT ERROR: Parse Error: broken')
        self.assertEqual((result.returncode, calls), (1, 1))

    def test_second_failure_preserves_both_logs(self):
        for code in [0, 1, 134]:
            with self.subTest(code=code):
                result, calls = self.run_import(134, FONT + '\n' + DONE, code, 'ERROR: second failure')
                self.assertEqual((result.returncode, calls), (1, 2))
                self.assertIn(FONT, result.stdout)
                self.assertIn('ERROR: second failure', result.stdout)


if __name__ == '__main__':
    unittest.main()
