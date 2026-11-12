#!/usr/bin/env python3
"""보존된 CC0 원본에서 짧은 PCM을 만든다. 런타임에는 인코더·합성이 필요 없다."""
import hashlib
import json
import re
import subprocess
import wave
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "assets/source/audio/game-feel-six"
DESTINATION = ROOT / "assets/audio/feedback"
RATE = 22050


def main():
    recipe = json.loads((SOURCE / "recipes.json").read_text())
    DESTINATION.mkdir(parents=True, exist_ok=True)
    banks = {}
    outputs = []
    for item in recipe["samples"]:
        source = ROOT / item["source"]
        assert hashlib.sha256(source.read_bytes()).hexdigest() == item["sha256"]
        data = subprocess.check_output([
            "ffmpeg", "-v", "error", "-i", str(source), "-ac", "1", "-ar", str(RATE),
            "-af", "highpass=f=45", "-f", "f32le", "-",
        ])
        samples = np.frombuffer(data, dtype="<f4").copy()
        active = np.flatnonzero(np.abs(samples) > max(0.001, np.max(np.abs(samples)) * .015))
        assert active.size
        start = max(0, active[0] - 110)
        samples = samples[start:min(active[-1] + 221, start + int(RATE * item["max_seconds"]))]
        samples *= .60 / max(.001, float(np.max(np.abs(samples))))
        fade = min(220, samples.size // 4)
        samples[:44] *= np.linspace(0, 1, 44)
        samples[-fade:] *= np.linspace(1, 0, fade)
        output = DESTINATION / item["output"]
        with wave.open(str(output), "wb") as wav:
            wav.setnchannels(1)
            wav.setsampwidth(2)
            wav.setframerate(RATE)
            wav.writeframes((np.clip(samples, -1, 1) * 32767).astype("<i2").tobytes())
        settings = output.with_suffix(".wav.import")
        if settings.exists():
            settings.write_text(re.sub(r"^compress/mode=.*$", "compress/mode=0", settings.read_text(), flags=re.M))
        path = "res://" + str(output.relative_to(ROOT))
        banks.setdefault(item["family"], []).append(path)
        outputs.append({"path": path, "sha256": hashlib.sha256(output.read_bytes()).hexdigest(), "frames": samples.size})
    (DESTINATION / "banks.json").write_text(json.dumps(banks, indent=2) + "\n")
    (SOURCE / "runtime.json").write_text(json.dumps({
        "recipe_sha256": hashlib.sha256((SOURCE / "recipes.json").read_bytes()).hexdigest(),
        "generator_sha256": hashlib.sha256(Path(__file__).read_bytes()).hexdigest(), "outputs": outputs,
    }, indent=2) + "\n")
    print("FEEDBACK_AUDIO", len(outputs), "samples", sum(p.stat().st_size for p in DESTINATION.glob("*.wav")), "bytes")


if __name__ == "__main__":
    main()
