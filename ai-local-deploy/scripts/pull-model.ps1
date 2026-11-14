#Requires -Version 5.1
<#
.SYNOPSIS
    拉取并校验本地模型。
.DESCRIPTION
    自动识别 Docker 容器或原生 Ollama，下载指定模型并打印体积与放置结果。
.EXAMPLE
    .\scripts\pull-model.ps1
.EXAMPLE
    .\scripts\pull-model.ps1 -Model qwen2.5:14b
.EXAMPLE
    .\scripts\pull-model.ps1 -Model nomic-embed-text
#>
[CmdletBinding()]
param(
    [string]$Model,

    [ValidateSet('auto', 'docker', 'native')]
    [string]$Mode = 'auto'
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$composeFile = Join-Path $projectRoot 'docker-compose.yml'

function Read-DotEnv {
    param([string]$Path)
    $values = @{}
    if (-not (Test-Path $Path)) { return $values }
    foreach ($line in Get-Content -Path $Path -Encoding utf8) {
        $line = $line.Trim()
        if ($line -eq '' -or $line.StartsWith('#')) { continue }
        $idx = $line.IndexOf('=')
        if ($idx -lt 1) { continue }
        $values[$line.Substring(0, $idx).Trim()] = $line.Substring($idx + 1).Trim()
    }
    return $values
}

function Test-DockerOllama {
    try {
        $name = & docker compose -f $composeFile ps --status running --format '{{.Name}}' 2>$null
        return [bool]($name -match 'ollama')
    } catch {
        return $false
    }
}

if (-not $Model) {
    $envValues = Read-DotEnv -Path (Join-Path $projectRoot '.env')
    $Model = $envValues['MODEL_NAME']
}
if (-not $Model) { $Model = 'qwen2.5:7b' }

if ($Mode -eq 'auto') {
    if (Test-DockerOllama) { $Mode = 'docker' } else { $Mode = 'native' }
}

Write-Host "=== 拉取模型：$Model（模式：$Mode）===" -ForegroundColor Cyan

if ($Mode -eq 'docker') {
    Push-Location $projectRoot
    try {
        & docker compose exec -T ollama ollama pull $Model
        if ($LASTEXITCODE -ne 0) { throw "拉取失败：$Model" }
    } finally {
        Pop-Location
    }
} else {
    if (-not (Get-Command ollama -ErrorAction SilentlyContinue)) {
        throw '未找到 ollama 命令，请先安装：winget install Ollama.Ollama'
    }
    & ollama pull $Model
    if ($LASTEXITCODE -ne 0) { throw "拉取失败：$Model" }
}

Write-Host '正在校验...' -ForegroundColor DarkGray
if ($Mode -eq 'docker') {
    Push-Location $projectRoot
    try {
        $listing = & docker compose exec -T ollama ollama list
    } finally {
        Pop-Location
    }
} else {
    $listing = & ollama list
}

$line = $listing | Where-Object { $_ -match [regex]::Escape($Model) } | Select-Object -First 1
if ($line) {
    Write-Host "已就绪：$line" -ForegroundColor Green
} else {
    Write-Host "命令执行完成，但列表中未匹配到 $Model，请手动执行 ollama list 确认。" -ForegroundColor Yellow
}

Write-Host "测试调用：python examples/chat.py --model $Model --prompt 你好" -ForegroundColor DarkGray
