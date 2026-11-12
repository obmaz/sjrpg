"""자산 경계 검사가 잘못된 모델 소유권·끊긴 연결을 실제로 거부하는지 확인한다."""
from pathlib import Path
import tempfile
import unittest

from check_resource_layout import check_layout


class ResourceLayoutTests(unittest.TestCase):
    def fixture(self, root):
        folder = root / "assets/models/environment/fixture"
        folder.mkdir(parents=True)
        (folder / "model.glb").touch()
        (folder / "visual.tscn").write_text(
            '[ext_resource type="PackedScene" path="res://assets/models/environment/fixture/model.glb" id="model"]\n'
        )
        return folder

    def test_local_model_scene_and_valid_resource(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            self.fixture(root)
            check_layout(root)

    def test_model_cannot_live_in_materials(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            folder = self.fixture(root)
            wrong = root / "assets/materials/model.glb"
            wrong.parent.mkdir()
            (folder / "model.glb").rename(wrong)
            with self.assertRaisesRegex(ValueError, "모델은 assets/models"):
                check_layout(root)

    def test_model_entry_scene_must_reference_own_model(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            folder = self.fixture(root)
            (folder / "visual.tscn").write_text('[ext_resource path="res://assets/materials/other.glb"]')
            with self.assertRaisesRegex(ValueError, "같은 폴더의 모델"):
                check_layout(root)

    def test_broken_preload_is_detected(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            folder = self.fixture(root)
            (folder / "visual.gd").write_text('const Model = preload("res://assets/models/missing.tscn")')
            with self.assertRaisesRegex(ValueError, "연결이 끊긴 리소스"):
                check_layout(root)


if __name__ == "__main__":
    unittest.main()
