"""최신 전달 기록과 프리셋이 달라도 번호를 조용히 건너뛰지 않는지 검사합니다."""
import json
import tempfile
import unittest
from pathlib import Path
from prepare_apk_version import prepare


class VersionTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.latest = self.root / 'latest.json'
        self.preset = self.root / 'export.cfg'
        self.record = {'versionCode': 10, 'buildNumber': 10, 'fileName': 'initialsj-1.0.10.apk'}
        self.latest.write_text(json.dumps(self.record))
        self.set_preset(10)

    def set_preset(self, code):
        self.preset.write_text(f'[preset.0]\nplatform="Android"\n[preset.0.options]\nversion/code={code}\nversion/name="1.0.{code}"\n')

    def run_prepare(self, history=()):
        return prepare(self.latest, self.preset, 'initialsj', history)

    def test_next_from_latest_and_repeat_is_idempotent(self):
        self.assertEqual(self.run_prepare()['versionCode'], 11)
        self.assertEqual(self.run_prepare()['versionCode'], 11)

    def test_older_preset_uses_latest(self):
        self.set_preset(2)
        self.assertEqual(self.run_prepare()['versionCode'], 11)

    def test_newer_history_stops_without_edit(self):
        history = self.root / 'history.json'
        history.write_text(json.dumps({**self.record, 'versionCode': 12, 'buildNumber': 12}))
        before = self.preset.read_text()
        with self.assertRaises(ValueError):
            self.run_prepare([history])
        self.assertEqual(before, self.preset.read_text())

    def test_newer_preset_stops_without_edit(self):
        self.set_preset(12)
        before = self.preset.read_text()
        with self.assertRaises(ValueError):
            self.run_prepare()
        self.assertEqual(before, self.preset.read_text())

    def test_mismatched_build_number(self):
        self.latest.write_text(json.dumps({**self.record, 'buildNumber': 9}))
        with self.assertRaises(ValueError):
            self.run_prepare()

    def test_other_app_is_rejected(self):
        self.latest.write_text(json.dumps({**self.record, 'fileName': 'sjrpg-1.0.10.apk'}))
        with self.assertRaises(ValueError):
            self.run_prepare()


if __name__ == '__main__':
    unittest.main()
