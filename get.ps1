# work-diary one-line installer for Windows PowerShell:
#   irm https://raw.githubusercontent.com/Pairee/work-diary/main/get.ps1 | iex
# Downloads the repository and runs install.ps1 from disk (install.ps1 holds the Korean messages;
# this bootstrap stays ASCII so that `irm | iex` never trips over text encoding).
$ErrorActionPreference = 'Stop'
$repo = if ($env:WORK_DIARY_REPO) { $env:WORK_DIARY_REPO } else { 'Pairee/work-diary' }
$tmp = Join-Path $env:TEMP ('work-diary-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $tmp | Out-Null
try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $zip = Join-Path $tmp 'repo.zip'
    Write-Host "Downloading github.com/$repo ..."
    Invoke-WebRequest -UseBasicParsing -Uri "https://github.com/$repo/archive/refs/heads/main.zip" -OutFile $zip
    Expand-Archive -Path $zip -DestinationPath $tmp -Force
    $root = Get-ChildItem -Path $tmp -Directory | Select-Object -First 1
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $root.FullName 'install.ps1')
} finally {
    Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue
}
