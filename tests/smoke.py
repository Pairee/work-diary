#!/usr/bin/env python3
"""설치 → 등록 → 한 편 기록 → 예약 실행 걸기·풀기 → 지우기를 한 바퀴 도는 시험. 맥과 윈도우에서 같은 파일로 돈다.

진짜 홈 폴더와 진짜 예약 작업은 건드리지 않는다. 가짜 홈과 시험용 작업 이름을 쓴다.
일지를 쓰는 AI 는 가짜(표준입력을 읽고 정해진 본문을 내는 파이썬 한 줄)로 바꿔 끼운다.
"""
import os
import pathlib
import shutil
import subprocess
import sys
import tempfile

# 깃허브 윈도우 러너의 화면 출력은 cp1252 라 한글을 찍다 멈춘다.
for _stream in (sys.stdout, sys.stderr):
    try:
        _stream.reconfigure(encoding="utf-8", errors="replace")
    except (AttributeError, ValueError):
        pass

ROOT = pathlib.Path(__file__).resolve().parent.parent
IS_WIN = os.name == "nt"

tmp = pathlib.Path(tempfile.mkdtemp(prefix="wd-smoke-")).resolve()
home = tmp / "home"
(home / ".claude").mkdir(parents=True)
bindir = tmp / "bin"
bindir.mkdir()
repo = tmp / "프로젝트"

env = dict(os.environ)
env.update({
    "HOME": str(home),
    "USERPROFILE": str(home),
    "WORK_DIARY_LABEL": "com.worklog.work-diary.smoketest",
    "WORK_DIARY_TASK": "WorkDiarySmokeTest",
    "PYTHONIOENCODING": "utf-8",
    "PATH": str(bindir) + os.pathsep + os.environ["PATH"],
    # 새 판 확인은 실제 깃허브 대신 없는 파일을 보게 해서, 시험이 네트워크에 기대지 않게 한다.
    "WORK_DIARY_UPDATE_URL": (tmp / "no-version").as_uri(),
})
FAKE_TOKEN = "ghp_" + "Z" * 36

# 예약 실행을 걸 때는 일지를 쓸 도구가 있는지만 본다. 가짜 claude 를 둔다.
if IS_WIN:
    (bindir / "claude.cmd").write_text("@echo off\r\necho fake\r\n", encoding="ascii")
else:
    fake = bindir / "claude"
    fake.write_text("#!/bin/sh\necho fake\n")
    fake.chmod(0o755)

writer = tmp / "fake_writer.py"
writer.write_text(
    "import sys\n"
    "data = sys.stdin.buffer.read().decode('utf-8')\n"
    "assert '보고서.md' in data, '한글 파일 이름이 자료에 그대로 들어가야 한다'\n"
    "assert 'ghp_' not in data and '[토큰 가림]' in data, '코드에 적힌 토큰은 가려져야 한다'\n"
    "sys.stdout.buffer.write('**한 줄 요약**: 시험 기록입니다.\\n\\n**무엇을 했나**\\n- 시험\\n'.encode('utf-8'))\n",
    encoding="utf-8")
env["WORKLOG_LLM_CMD"] = '"%s" "%s"' % (sys.executable, writer)


def run(args, check=True, extra_env=None):
    print("$ " + " ".join(str(a) for a in args), flush=True)
    r = subprocess.run([str(a) for a in args], env=dict(env, **(extra_env or {})),
                       stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    out = r.stdout.decode("utf-8", "replace")
    print(out, flush=True)
    if check and r.returncode != 0:
        sys.exit("실패(%d): %s" % (r.returncode, args))
    return out


def installer(*extra):
    if IS_WIN:
        return run(["powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", ROOT / "install.ps1"] + list(extra))
    return run(["bash", ROOT / "install.sh"] + list(extra))


# 시험 저장소: 한글 파일 하나, 커밋 하나, 저장만 해 둔 변경 하나
repo.mkdir()
run(["git", "init", "-q", repo])
run(["git", "-C", repo, "config", "user.name", "시험자"])
run(["git", "-C", repo, "config", "user.email", "tester@example.com"])
(repo / "보고서.md").write_text("# 보고서\n", encoding="utf-8")
run(["git", "-C", repo, "add", "-A"])
run(["git", "-C", repo, "commit", "-q", "-m", "feat: 보고서 초안 추가", "-m", "팀장 요청"])
(repo / "보고서.md").write_text("# 보고서\n\n둘째 줄\ntoken = \"%s\"\n" % FAKE_TOKEN, encoding="utf-8")

# 1. 설치
installer()
skill = home / ".claude" / "skills" / "work-diary"
assert (skill / "SKILL.md").exists(), "클로드 스킬 폴더에 설치돼야 한다"
wl = [sys.executable, skill / "scripts" / "worklog.py"]

# 2. 등록하고 한 편 쓰기
run(wl + ["add", repo])
out = run(wl + ["run", "--name", "프로젝트", "--force"])
assert "written" in out, "일지가 써져야 한다"
logs = list((home / "worklog").rglob("*.md"))
assert logs, "일지 파일이 생겨야 한다"
assert "시험 기록입니다" in logs[0].read_text(encoding="utf-8"), "쓴 본문이 파일에 있어야 한다"

# 3. 예약 실행 걸기 → 확인 → 끄기
out = run(wl + ["schedule", "install", "--llm", "claude"], check=False)
if "설정됨" in out:
    status = run(wl + ["schedule", "status"])
    assert "11:30" in status and "15:30" in status and "18:30" in status, "세 시각이 걸려 있어야 한다"
    run(wl + ["stop", "프로젝트"])
    status = run(wl + ["schedule", "status"])
    assert "걸려 있지 않음" in status, "끄면 예약 실행이 풀려야 한다"
elif IS_WIN:
    sys.exit("실패: 윈도우 작업 스케줄러 등록")
else:
    print("주의: 이 맥 환경에서는 launchd 등록이 되지 않았다(화면 로그인이 없는 CI 러너일 수 있음)")
    run(wl + ["stop", "프로젝트"], check=False)

# 4. 새 판 알림: 더 높은 판 번호가 보이면 알리고, 하루 동안은 기억해 둔 것으로 다시 알린다
newer = tmp / "VERSION-newer"
newer.write_text("99.0.0\n", encoding="utf-8")
out = run(wl + ["update-check"], extra_env={"WORK_DIARY_UPDATE_URL": newer.as_uri()})
assert "[새 판]" in out and "99.0.0" in out, "새 판이 있으면 알려야 한다"
out = run(wl + ["status"])
assert "[새 판]" in out, "하루 안에는 확인해 둔 새 판을 다시 알려야 한다"

# 5. 지우기
installer("-Uninstall" if IS_WIN else "--uninstall")
assert not skill.exists(), "지우면 스킬 폴더가 없어져야 한다"

shutil.rmtree(tmp, ignore_errors=True)
print("통과")
