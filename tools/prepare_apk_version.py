#!/usr/bin/env python3
"""플러그인으로 읽어 저장한 Dropbox 기록에서 다음 APK 버전을 정합니다. 네트워크 요청은 하지 않습니다."""
import argparse
import json
import re
from pathlib import Path


def read_record(path, project, legacy=False):
    record = json.loads(Path(path).read_text(encoding="utf-8"))
    if not isinstance(record, dict):
        raise ValueError(f"{path}: 빌드 기록은 JSON 객체여야 합니다")
    code = record.get("versionCode", record.get("version_code") if legacy else None)
    if type(code) is not int or not 1 <= code < 2100000000:
        raise ValueError(f"{path}: 유효한 정수 versionCode가 필요합니다")
    name = record.get("fileName", record.get("filename") if legacy else None)
    prefixes = (project + "-", "sjrpg_3d-" if project == "sjrpg" else project + "-")
    if not isinstance(name, str) or not name.startswith(prefixes):
        raise ValueError(f"{path}: {project} 앱의 fileName을 확인해야 합니다")
    if record.get("project", project) != project:
        raise ValueError(f"{path}: 다른 앱의 기록은 사용할 수 없습니다")
    return code


def prepare(latest, preset, project, history=()):
    codes = [read_record(latest, project)]
    codes.extend(read_record(path, project, legacy=True) for path in history)
    path = Path(preset)
    source = path.read_text(encoding="utf-8")
    sections = re.split(r"(?m)(?=^\[)", source)
    android = [re.search(r"(?m)^\[preset\.(\d+)\]$", section).group(1)
               for section in sections
               if re.search(r"(?m)^\[preset\.(\d+)\]$", section)
               and re.search(r'^platform="Android"$', section, re.M)]
    if len(android) != 1:
        raise ValueError("Android 내보내기 프리셋이 정확히 하나여야 합니다")
    header = f"[preset.{android[0]}.options]"
    indices = [i for i, section in enumerate(sections) if section.startswith(header + "\n")]
    if len(indices) != 1:
        raise ValueError("Android 프리셋 옵션을 찾지 못했습니다")
    index = indices[0]
    options = sections[index]
    current = re.findall(r"(?m)^version/code=(\d+)$", options)
    if len(current) != 1 or len(re.findall(r'(?m)^version/name="[^"\n]+"$', options)) != 1:
        raise ValueError("Android version/code 및 version/name을 확인해야 합니다")
    number = max(codes + [int(current[0])]) + 1
    if number > 2100000000:
        raise ValueError("다음 versionCode가 Android 허용 범위를 초과합니다")
    version = f"1.0.{number}"
    options = re.sub(r"(?m)^version/code=\d+$", f"version/code={number}", options)
    sections[index] = re.sub(r'(?m)^version/name="[^"\n]+"$', f'version/name="{version}"', options)
    path.write_text("".join(sections), encoding="utf-8")
    return {"buildNumber": number, "versionName": version, "versionCode": number}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--latest", required=True, type=Path, help="Dropbox 플러그인으로 읽어 저장한 해당 앱의 latest-build.json")
    parser.add_argument("--history", action="append", default=[], type=Path, help="더 최근 전달본을 포함한 앱별 빌드 기록 JSON, 반복 지정 가능")
    parser.add_argument("--preset", required=True, type=Path, help="Godot export_presets.cfg 경로")
    parser.add_argument("--project", required=True, choices=("initialsj", "sjrpg"))
    args = parser.parse_args()
    try:
        result = prepare(args.latest, args.preset, args.project, args.history)
    except (OSError, ValueError, TypeError) as error:
        parser.exit(1, f"APK 버전 결정 실패: {error}\n")
    print(json.dumps(result, ensure_ascii=False))


if __name__ == "__main__":
    main()
