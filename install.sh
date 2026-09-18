#!/usr/bin/env bash
# 업무일지(work-diary) 스킬 설치 - 맥
#   한 줄 설치:  curl -fsSL https://raw.githubusercontent.com/Pairee/work-diary/main/install.sh | bash
#   내려받은 폴더에서:  bash install.sh      지우기:  bash install.sh --uninstall  (쌓인 일지는 남는다)
# 이 컴퓨터에 있는 AI 도구(클로드 코드·코덱스·안티그래비티·제미나이 CLI)를 찾아 도구마다 같은 스킬을 넣는다.
set -euo pipefail

if [ -z "${HOME:-}" ]; then echo "HOME 이 비어 있어 설치 위치를 정할 수 없습니다."; exit 1; fi

REPO="${WORK_DIARY_REPO:-Pairee/work-diary}"
LABEL="${WORK_DIARY_LABEL:-com.worklog.work-diary}"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"

TARGETS=(
  "클로드 코드|$HOME/.claude/skills|claude|$HOME/.claude"
  "코덱스|$HOME/.codex/skills|codex|$HOME/.codex"
  "안티그래비티|$HOME/.gemini/config/skills|agy|$HOME/.gemini/antigravity"
  "제미나이 CLI|$HOME/.agents/skills|gemini|"
)

has() { command -v "$1" >/dev/null 2>&1; }

if [ "${1:-}" = "--uninstall" ]; then
  for t in "${TARGETS[@]}"; do
    IFS='|' read -r label dir _ _ <<< "$t"
    if [ -d "$dir/work-diary" ]; then rm -rf "$dir/work-diary"; echo "  지움: $label ($dir/work-diary)"; fi
  done
  if [ -f "$PLIST" ]; then
    launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || launchctl unload "$PLIST" 2>/dev/null || true
    rm -f "$PLIST"
    echo "  자동 기록 해제"
  fi
  echo "쌓인 일지(~/worklog)와 기록 상태(~/.work-diary)는 그대로 두었습니다."
  exit 0
fi

if [ "$(uname)" != "Darwin" ]; then
  echo "이 설치 파일은 맥용입니다. 윈도우는 PowerShell 에서 get.ps1 을 쓰세요."
  exit 1
fi
if ! has python3 || ! has git; then
  echo "python3 또는 git 이 없습니다. 터미널에 아래를 입력해 개발 도구를 먼저 설치하세요."
  echo "  xcode-select --install"
  exit 1
fi

# 내려받은 폴더에서 돌리면 그 안의 스킬을, 한 줄 설치(curl | bash)면 깃허브에서 받아 쓴다.
SRC=""
if [ -n "${BASH_SOURCE[0]:-}" ] && [ -f "${BASH_SOURCE[0]}" ]; then
  HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  SRC="$HERE/skills/work-diary"
fi
# curl | bash 로 돌리면 파일이 없으므로(현재 폴더의 것을 집어 오지 않도록) 반드시 깃허브에서 받는다.
if [ -z "$SRC" ] || [ ! -f "$SRC/SKILL.md" ]; then
  TMP="$(mktemp -d)"
  trap 'rm -rf "$TMP"' EXIT
  echo "스킬을 내려받는 중: github.com/$REPO"
  curl -fsSL "https://github.com/$REPO/archive/refs/heads/main.tar.gz" | tar -xz -C "$TMP"
  SRC="$(find "$TMP" -maxdepth 3 -type d -path '*/skills/work-diary' | head -1)"
  if [ -z "$SRC" ] || [ ! -f "$SRC/SKILL.md" ]; then
    echo "내려받기에 실패했습니다. 인터넷 연결을 확인하고 다시 실행하세요."
    exit 1
  fi
fi

installed=0
echo "업무일지 스킬을 설치합니다."
for t in "${TARGETS[@]}"; do
  IFS='|' read -r label dir cmd cfg <<< "$t"
  if has "$cmd" || { [ -n "$cfg" ] && [ -d "$cfg" ]; }; then
    mkdir -p "$dir"
    rsync -a --delete --exclude '__pycache__' --exclude '.DS_Store' "$SRC/" "$dir/work-diary/"
    echo "  넣음: $label  →  $dir/work-diary"
    installed=$((installed + 1))
  else
    echo "  건너뜀: $label (이 컴퓨터에서 찾지 못함)"
  fi
done

if [ "$installed" -eq 0 ]; then
  echo "AI 도구를 찾지 못했습니다. 클로드 코드·코덱스·안티그래비티 중 하나를 먼저 설치하고 다시 실행하세요."
  exit 1
fi

# 이미 자동 기록을 쓰고 있었다면, 예약 실행이 쓰는 사본도 새 판으로 바꾼다(시각·AI 선택은 그대로).
if [ -f "$PLIST" ]; then
  python3 "$SRC/scripts/worklog.py" schedule install >/dev/null && echo "  자동 기록도 새 판으로 바꿨습니다."
fi

cat <<'MSG'

설치가 끝났습니다. 열려 있던 AI 앱은 완전히 껐다가 다시 켜야 새 스킬이 보일 수 있습니다.

기록할 프로젝트 폴더에서 앱을 열고 이렇게 말하세요.
  "이 폴더 업무일지 켜줘"

명령으로 부르려면
  클로드 코드 · 안티그래비티   /work-diary 켜기
  코덱스                       $work-diary 켜기

처음 켤 때 앱이 "예약 실행을 등록해도 되느냐"고 물으면 허용하세요.
일지는 ~/worklog/<프로젝트이름>/ 에 쌓입니다.
MSG
