#!/usr/bin/env python3
"""Snapshot art sources, then publish engine-generated import metadata without refs."""
import argparse, base64, hashlib, json, os, subprocess, urllib.request
from pathlib import Path
import sys
ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT / "tools"))
import texture_policy

def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("operation",choices=["snapshot","publish"])
    parser.add_argument("--out",type=Path,required=True)
    args = parser.parse_args()
    images = {p.relative_to(ROOT).as_posix():digest(p) for p in (ROOT/"assets/art").rglob("*") if p.is_file() and not p.name.endswith(".import")}
    if args.operation == "snapshot":
        params = {}
        for path in (ROOT/"assets/art").rglob("*.import"):
            text = path.read_text()
            parts = texture_policy.sections(text,str(path))
            if texture_policy.values(text,parts["remap"],str(path)).get("importer") == '"texture"':
                params[path.relative_to(ROOT).as_posix()] = {
                    "params":texture_policy.values(text,parts["params"],str(path)),
                    "uid":texture_policy.values(text,parts["remap"],str(path)).get("uid"),
                }
        args.out.parent.mkdir(parents=True,exist_ok=True)
        args.out.write_text(json.dumps({"sources":images,"imports":params},indent=2)+"\n")
        print("TEXTURE_SOURCE_SNAPSHOT "+str(len(images)))
        return
    before = json.loads(args.out.read_text())
    if images != before["sources"]:
        raise RuntimeError("Source art bytes changed")
    selected = texture_policy.load_policy()
    records = []
    repository = os.environ["GITHUB_REPOSITORY"]
    if repository != "obmaz/sjrpg":
        raise RuntimeError("Unexpected repository")
    for relative, original in before["imports"].items():
        path = ROOT / relative
        text = path.read_text()
        parts = texture_policy.sections(text,relative)
        actual = texture_policy.values(text,parts["params"],relative)
        source = relative.removesuffix(".import")
        allowed = texture_policy.EXPECTED_GPU if source in selected else texture_policy.EXPECTED_PROTECTED
        retained_before = {k:v for k,v in original["params"].items() if k not in allowed}
        retained_after = {k:v for k,v in actual.items() if k not in allowed}
        if retained_before != retained_after:
            raise RuntimeError("Non-policy image settings changed: "+relative+" "+json.dumps({"before":retained_before,"after":retained_after}))
        if texture_policy.values(text,parts["remap"],relative).get("uid") != original["uid"]:
            raise RuntimeError("Texture UID changed: "+relative)
        if any(actual.get(k) != v for k,v in allowed.items()):
            raise RuntimeError("Policy import did not survive Godot: "+relative)
        data = path.read_bytes()
        request = urllib.request.Request("https://api.github.com/repos/"+repository+"/git/blobs",
            data=json.dumps({"encoding":"base64","content":base64.b64encode(data).decode()}).encode(),
            method="POST",headers={"Authorization":"Bearer "+os.environ["GH_TOKEN"],"Accept":"application/vnd.github+json","Content-Type":"application/json"})
        with urllib.request.urlopen(request,timeout=60) as response:
            sha = json.load(response)["sha"]
        records.append({"path":"sjrpg_3d/"+relative,"sha":sha,"sha256":hashlib.sha256(data).hexdigest(),"bytes":len(data)})
    report = {"source_commit":os.environ["GITHUB_SHA"],"source_files_unchanged":True,"nonpolicy_settings_unchanged":True,"uids_unchanged":True,"refs_changed":False,"imports":records}
    args.out.with_name("verified-import-blobs.json").write_text(json.dumps(report,indent=2)+"\n")
    print("TEXTURE_IMPORT_BLOBS "+json.dumps(report),flush=True)

if __name__ == "__main__":
    main()
