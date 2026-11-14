#Requires -Version 5.1
<#
.SYNOPSIS
    启动本地 AI 服务（Docker Compose 或 Windows 原生 Ollama）。
.DESCRIPTION
    1. Docker 模式：拉起 ollama + open-webui 容器，等待健康检查通过，并确保模型已下载。
    2. Native 模式：确保 ollama serve 正在运行，并确保模型已下载。
.EXAMPLE
    .\scripts\start.ps1
.EXAMPLE
    .\scripts\start.ps1 -Mode native -Model qwen2.5:14b
.EXAMPLE
    .\scripts\start.ps1 -NoPull
#>
[CmdletBinding()]
param(
    [ValidateSet('docker', 'native')]
    [string]$Mode = 'docker',

    [string]$Model,

    [switch]$NoPull
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot

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

function Invoke-Compose {
    param([Parameter(ValueFromRemainingArguments = $true)][string[]]$Arguments)
    Push-Location $projectRoot
    try {
        & docker compose @Arguments
        if ($LASTEXITCODE -ne 0) { throw "docker compose 执行失败：$($Arguments -join ' ')" }
    } finally {
        Pop-Location
    }
}

function Wait-OllamaHealthy {
    param([int]$TimeoutSeconds = 180)
    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    while ((Get-Date) -lt $deadline) {
        try {
            Invoke-RestMethod -Uri 'http://127.0.0.1:11434/api/tags' -TimeoutSec 3 | Out-Null
            return $true
        } catch {
            Start-Sleep -Seconds 3
        }
    }
    return $false
}

function Get-InstalledModels {
    param([string]$Mode)
    try {
        if ($Mode -eq 'docker') {
            $raw = & docker compose -f (Join-Path $projectRoot 'docker-compose.yml') exec -T ollama ollama list 2>$null
        } else {
            $raw = & ollama list 2>$null
        }
        if (-not $raw) { return @() }
        return @($raw | Select-Object -Skip 1 | Where-Object { $_ -match '\S' } | ForEach-Object { ($_ -split '\s+')[0] })
    } catch {
        return @()
    }
}

function Ensure-Model {
    param([string]$Mode, [string]$ModelName)
    if (-not $ModelName) { return }
    $installed = Get-InstalledModels -Mode $Mode
    $present = $installed | Where-Object { $_ -eq $ModelName -or $_ -eq "$ModelName:latest" -or $ModelName -eq "$_:latest" }
    if ($present) {
        Write-Host "模型已存在：$ModelName" -ForegroundColor Green
        return
    }
    if ($NoPull) {
        Write-Host "模型未下载，但已指定 -NoPull，跳过：$ModelName" -ForegroundColor Yellow
        return
    }
    Write-Host "开始下载模型 $ModelName（首次约 4～5 GB，请耐心等待）..." -ForegroundColor Cyan
    if ($Mode -eq 'docker') {
        Invoke-Compose exec -T ollama ollama pull $ModelName
    } else {
        & ollama pull $ModelName
        if ($LASTEXITCODE -ne 0) { throw "ollama pull 失败：$ModelName" }
    }
    Write-Host "模型下载完成：$ModelName" -ForegroundColor Green
}

$envValues = Read-DotEnv -Path (Join-Path $projectRoot '.env')
if (-not $Model) { $Model = $envValues['MODEL_NAME'] }
if (-not $Model) { $Model = 'qwen2.5:7b' }

Write-Host "=== 本地 AI 启动（模式：$Mode，模型：$Model）===" -ForegroundColor Cyan

if ($Mode -eq 'docker') {
    if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
        throw '未找到 docker 命令。请安装 Docker Desktop，或改用：.\scripts\start.ps1 -Mode native'
    }
    try { & docker info 2>$null | Out-Null } catch { }
    if ($LASTEXITCODE -ne 0) {
        throw 'Docker 服务未启动，请先打开 Docker Desktop 并等待其就绪。'
    }

    Invoke-Compose up -d
    Write-Host '容器已启动，等待 Ollama 就绪...' -ForegroundColor DarkGray
    if (-not (Wait-OllamaHealthy -TimeoutSeconds 180)) {
        throw 'Ollama 在 180 秒内未就绪，请执行 docker compose logs ollama 查看日志。'
    }
    Write-Host 'Ollama 已就绪。' -ForegroundColor Green

    Ensure-Model -Mode 'docker' -ModelName $Model

    Write-Host ''
    Write-Host '启动完成：' -ForegroundColor Green
    Write-Host '  聊天界面  http://localhost:3000'
    Write-Host '  模型 API  http://localhost:11434'
    Write-Host '  停止服务  .\scripts\stop.ps1'
} else {
    if (-not (Get-Command ollama -ErrorAction SilentlyContinue)) {
        throw '未找到 ollama 命令。请先执行：winget install Ollama.Ollama'
    }

    $running = $false
    try {
        Invoke-RestMethod -Uri 'http://127.0.0.1:11434/api/tags' -TimeoutSec 3 | Out-Null
        $running = $true
    } catch { }

    if (-not $running) {
        Write-Host '正在后台启动 ollama serve ...' -ForegroundColor DarkGray
        Start-Process -FilePath 'ollama' -ArgumentList 'serve' -WindowStyle Hidden | Out-Null
        if (-not (Wait-OllamaHealthy -TimeoutSeconds 60)) {
            throw 'ollama serve 启动失败，请在终端手动执行 ollama serve 查看报错。'
        }
    }
    Write-Host 'Ollama 已就绪：http://127.0.0.1:11434' -ForegroundColor Green

    Ensure-Model -Mode 'native' -ModelName $Model
    Write-Host ''
    Write-Host '启动完成，可以开始对话：' -ForegroundColor Green
    Write-Host "  ollama run $Model"
    Write-Host "  python examples/chat.py --model $Model"
}
