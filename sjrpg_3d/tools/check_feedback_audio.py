#!/usr/bin/env python3
"""실제 CC0 출처·PCM 파형·임포트·보행 접지 기록을 검사한다."""
import hashlib
import json
import struct
import wave
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "assets/source/audio/game-feel-six"


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    recipe = json.loads((SOURCE / "recipes.json").read_text())
    runtime = json.loads((SOURCE / "runtime.json").read_text())
    assert recipe["license"] == "CC0-1.0"
    assert digest(SOURCE / "recipes.json") == runtime["recipe_sha256"]
    assert digest(ROOT / "tools/audio/bake_feedback.py") == runtime["generator_sha256"]
    for pack in ("impact-sounds", "rpg-audio"):
        assert "CC0" in (SOURCE / pack / "License.txt").read_text()
    for row in recipe["samples"]:
        assert digest(ROOT / row["source"]) == row["sha256"]
    total = 0
    for row in runtime["outputs"]:
        path = ROOT / row["path"].removeprefix("res://")
        assert digest(path) == row["sha256"]
        with wave.open(str(path)) as wav:
            assert wav.getnchannels() == 1 and wav.getsampwidth() == 2 and wav.getframerate() == 22050
            assert wav.getnframes() == row["frames"] and wav.getnframes() <= 8820
            pcm = wav.readframes(wav.getnframes())
        values = struct.unpack("<" + "h" * (len(pcm) // 2), pcm)
        peak = max(map(abs, values)) / 32768.0
        assert .25 < peak <= .601, (path, peak)
        settings = path.with_suffix(".wav.import").read_text()
        assert "compress/mode=0" in settings and "edit/loop_mode=0" in settings
        total += len(pcm)
    gait = json.loads((SOURCE / "gait.json").read_text())
    assert digest(ROOT / gait["model"]) == gait["sha256"]
    assert gait["minimum_y_phases"] == {"foot_l": .0625, "foot_r": .5625}
    assert total < 300000
    print("FEEDBACK_AUDIO_PASS", len(runtime["outputs"]), "takes,", total, "PCM bytes")


if __name__ == "__main__":
    main()
