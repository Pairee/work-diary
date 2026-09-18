#!/usr/bin/env python3
"""릴리스에 올릴 맥·윈도우 zip 두 개를 dist/ 에 만든다.  사용: python3 tools/build_zips.py"""
import os
import pathlib
import zipfile

ROOT = pathlib.Path(__file__).resolve().parent.parent
DIST = ROOT / "dist"


def entry(arc, mode):
    info = zipfile.ZipInfo(arc)
    info.create_system = 3  # 유닉스에서 만든 것으로 적어야 맥에서 풀 때 실행 권한이 살아난다
    info.external_attr = (0o100000 | mode) << 16
    info.compress_type = zipfile.ZIP_DEFLATED
    return info


def add_tree(z, src, arc):
    for f in sorted(src.rglob("*")):
        if f.is_file() and "__pycache__" not in f.parts and f.name != ".DS_Store":
            mode = 0o755 if os.access(f, os.X_OK) else 0o644
            z.writestr(entry(str(pathlib.PurePosixPath(arc) / f.relative_to(src).as_posix()), mode), f.read_bytes())


def add_file(z, name, arc, mode=0o644):
    z.writestr(entry(arc, mode), (ROOT / name).read_bytes())


DIST.mkdir(exist_ok=True)
skill = ROOT / "skills" / "work-diary"
with zipfile.ZipFile(DIST / "work-diary-mac.zip", "w") as z:
    add_tree(z, skill, "work-diary-mac/skills/work-diary")
    add_file(z, "install.sh", "work-diary-mac/install.sh", 0o755)
    add_file(z, "설치하기.command", "work-diary-mac/설치하기.command", 0o755)
    add_file(z, "설치안내.html", "work-diary-mac/설치안내.html")
with zipfile.ZipFile(DIST / "work-diary-windows.zip", "w") as z:
    add_tree(z, skill, "work-diary-windows/skills/work-diary")
    add_file(z, "install.ps1", "work-diary-windows/install.ps1")
    add_file(z, "install.bat", "work-diary-windows/install.bat")
    add_file(z, "설치안내.html", "work-diary-windows/guide.html")  # 윈도우 압축 풀기에서 한글 이름이 깨지지 않게
version = (skill / "VERSION").read_text(encoding="utf-8").strip()
print("v%s: %s" % (version, ", ".join(sorted(p.name for p in DIST.glob("*.zip")))))
