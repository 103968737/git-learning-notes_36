#Requires -Version 5.1
<#
.SYNOPSIS
    停止本地 AI 服务。
.DESCRIPTION
    Docker 模式下执行 docker compose down；原生模式下停止 ollama 进程。
    默认保留模型与对话数据，使用 -RemoveVolumes 才会删除数据卷。
.EXAMPLE
    .\scripts\stop.ps1
.EXAMPLE
    .\scripts\stop.ps1 -RemoveVolumes
.EXAMPLE
    .\scripts\stop.ps1 -Mode native
#>
[CmdletBinding()]
param(
    [ValidateSet('docker', 'native')]
    [string]$Mode = 'docker',

    [switch]$RemoveVolumes,

    [switch]$Force
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot

if ($Mode -eq 'docker') {
    if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
        throw '未找到 docker 命令。'
    }
    $arguments = @('compose', 'down')
    if ($RemoveVolumes) {
        $arguments += '-v'
        Write-Host '警告：-RemoveVolumes 会删除已下载的模型和 WebUI 对话数据。' -ForegroundColor Yellow
        if (-not $Force) {
            $answer = Read-Host '确认删除？输入 yes 继续'
            if ($answer -ne 'yes') {
                Write-Host '已取消。' -ForegroundColor DarkGray
                return
            }
        }
    }

    Push-Location $projectRoot
    try {
        & docker @arguments
        if ($LASTEXITCODE -ne 0) { throw 'docker compose down 执行失败。' }
    } finally {
        Pop-Location
    }
    Write-Host '容器已停止。' -ForegroundColor Green
    if (-not $RemoveVolumes) {
        Write-Host '模型与对话数据已保留，下次启动无需重新下载。' -ForegroundColor DarkGray
    }
} else {
    $processes = @(Get-Process -Name 'ollama' -ErrorAction SilentlyContinue)
    if ($processes.Count -eq 0) {
        Write-Host '未发现运行中的 ollama 进程。' -ForegroundColor DarkGray
        return
    }

    if (-not $Force) {
        $answer = Read-Host "发现 $($processes.Count) 个 ollama 进程，确认停止？输入 yes 继续"
        if ($answer -ne 'yes') {
            Write-Host '已取消。' -ForegroundColor DarkGray
            return
        }
    }

    $processes | Stop-Process -Force
    Write-Host 'ollama 进程已停止（模型文件仍保留在磁盘）。' -ForegroundColor Green
}
