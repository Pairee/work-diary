# 업무일지(work-diary) 스킬 설치 - 윈도우
#   한 줄 설치(PowerShell):  irm https://raw.githubusercontent.com/Pairee/work-diary/main/get.ps1 | iex
#   내려받은 폴더에서:  install.bat 더블클릭      지우기:  install.bat -Uninstall  (쌓인 일지는 남는다)
# 이 컴퓨터에 있는 AI 도구(클로드 코드·코덱스·안티그래비티·제미나이 CLI)를 찾아 도구마다 같은 스킬을 넣는다.
param([switch]$Uninstall)
$ErrorActionPreference = 'Stop'
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch {}

$UserHome = $env:USERPROFILE
$TaskName = if ($env:WORK_DIARY_TASK) { $env:WORK_DIARY_TASK } else { 'WorkDiary' }
$Src = Join-Path $PSScriptRoot 'skills\work-diary'

$Targets = @(
    @{ Label = '클로드 코드';  Dir = "$UserHome\.claude\skills";        Cmd = 'claude'; Cfg = "$UserHome\.claude" },
    @{ Label = '코덱스';       Dir = "$UserHome\.codex\skills";         Cmd = 'codex';  Cfg = "$UserHome\.codex" },
    @{ Label = '안티그래비티'; Dir = "$UserHome\.gemini\config\skills"; Cmd = 'agy';    Cfg = "$UserHome\.gemini\antigravity" },
    @{ Label = '제미나이 CLI'; Dir = "$UserHome\.agents\skills";        Cmd = 'gemini'; Cfg = $null }
)

function Test-Cmd($name) { return [bool](Get-Command $name -ErrorAction SilentlyContinue) }

if ($Uninstall) {
    foreach ($t in $Targets) {
        $d = Join-Path $t.Dir 'work-diary'
        if (Test-Path $d) { Remove-Item $d -Recurse -Force; Write-Host "  지움: $($t.Label) ($d)" }
    }
    if (Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue) {
        Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
        Write-Host '  자동 기록 해제'
    }
    Write-Host '쌓인 일지(~\worklog)와 기록 상태(~\.work-diary)는 그대로 두었습니다.'
    exit 0
}

if (-not (Test-Path (Join-Path $Src 'SKILL.md'))) {
    Write-Host "skills\work-diary 폴더를 찾지 못했습니다. 압축을 푼 폴더 안에서 실행하세요: $Src"
    exit 1
}

# 파이썬 찾기. Microsoft Store 가 깔아 두는 가짜 python(WindowsApps)은 건너뛴다.
function Find-Python {
    $cands = @(@{ Exe = 'py'; Args = @('-3') }, @{ Exe = 'python'; Args = @() }, @{ Exe = 'python3'; Args = @() })
    foreach ($c in $cands) {
        $cmd = Get-Command $c.Exe -ErrorAction SilentlyContinue
        if (-not $cmd -or $cmd.Source -like '*WindowsApps*') { continue }
        & $c.Exe @($c.Args + '--version') *> $null
        if ($LASTEXITCODE -eq 0) { return $c }
    }
    return $null
}
$Py = Find-Python
if (-not $Py -or -not (Test-Cmd 'git')) {
    Write-Host 'python 또는 git 이 없습니다. 아래 두 가지를 먼저 설치하고 다시 실행하세요.'
    Write-Host '  Python: https://www.python.org/downloads/  (설치 첫 화면에서 "Add python.exe to PATH" 체크)'
    Write-Host '  Git:    https://git-scm.com/download/win'
    exit 1
}

$installed = 0
Write-Host '업무일지 스킬을 설치합니다.'
foreach ($t in $Targets) {
    if ((Test-Cmd $t.Cmd) -or ($t.Cfg -and (Test-Path $t.Cfg))) {
        New-Item -ItemType Directory -Force -Path $t.Dir | Out-Null
        $dest = Join-Path $t.Dir 'work-diary'
        if (Test-Path $dest) { Remove-Item $dest -Recurse -Force }
        Copy-Item $Src $dest -Recurse
        Get-ChildItem $dest -Recurse -Directory -Filter '__pycache__' | Remove-Item -Recurse -Force
        Write-Host "  넣음: $($t.Label)  ->  $dest"
        $installed++
    } else {
        Write-Host "  건너뜀: $($t.Label) (이 컴퓨터에서 찾지 못함)"
    }
}
if ($installed -eq 0) {
    Write-Host 'AI 도구를 찾지 못했습니다. 클로드 코드·코덱스·안티그래비티 중 하나를 먼저 설치하고 다시 실행하세요.'
    exit 1
}

# 이미 자동 기록을 쓰고 있었다면, 예약 실행이 쓰는 사본도 새 판으로 바꾼다(시각·AI 선택은 그대로).
if (Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue) {
    & $Py.Exe @($Py.Args + @((Join-Path $Src 'scripts\worklog.py'), 'schedule', 'install')) | Out-Null
    Write-Host '  자동 기록도 새 판으로 바꿨습니다.'
}

Write-Host ''
Write-Host '설치가 끝났습니다. 열려 있던 AI 앱은 완전히 껐다가 다시 켜야 새 스킬이 보일 수 있습니다.'
Write-Host ''
Write-Host '기록할 프로젝트 폴더에서 앱을 열고 이렇게 말하세요.'
Write-Host '  "이 폴더 업무일지 켜줘"'
Write-Host ''
Write-Host '명령으로 부르려면'
Write-Host '  클로드 코드 · 안티그래비티   /work-diary 켜기'
Write-Host '  코덱스                       $work-diary 켜기'
Write-Host ''
Write-Host '처음 켤 때 앱이 "예약 작업을 등록해도 되느냐"고 물으면 허용하세요.'
Write-Host '일지는 사용자 폴더의 worklog\<프로젝트이름>\ 에 쌓입니다.'
