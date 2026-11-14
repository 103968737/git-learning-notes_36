#Requires -Version 5.1
<#
.SYNOPSIS
    本地 AI 部署环境自检。
.DESCRIPTION
    检查操作系统、内存、磁盘、显卡、Docker / Ollama 安装情况以及常用端口占用，
    最后给出「这台机器适合跑多大模型」的建议。
.EXAMPLE
    .\scripts\check-env.ps1
.EXAMPLE
    .\scripts\check-env.ps1 -MinDiskGB 30
#>
[CmdletBinding()]
param(
    [int]$MinDiskGB = 20
)

$ErrorActionPreference = 'Continue'
$rows = New-Object System.Collections.ArrayList

function Add-Row {
    param([string]$Item, [string]$Value, [string]$Status)
    [void]$rows.Add([pscustomobject]@{ Item = $Item; Value = $Value; Status = $Status })
}

function Get-DisplayWidth {
    param([string]$Text)
    $width = 0
    foreach ($ch in $Text.ToCharArray()) {
        if ([int][char]$ch -gt 0x2E80) { $width += 2 } else { $width += 1 }
    }
    return $width
}

function Format-Cell {
    param([string]$Text, [int]$Width)
    $pad = $Width - (Get-DisplayWidth $Text)
    if ($pad -lt 1) { $pad = 1 }
    return $Text + (' ' * $pad)
}

function Get-TotalMemoryGB {
    # 优先 WMI/CIM；受限环境或被策略禁用时退回 .NET 接口
    try {
        $cs = Get-CimInstance -ClassName Win32_ComputerSystem -ErrorAction Stop
        return [math]::Round($cs.TotalPhysicalMemory / 1GB, 1)
    } catch { }

    try {
        Add-Type -AssemblyName Microsoft.VisualBasic -ErrorAction Stop
        $info = New-Object Microsoft.VisualBasic.Devices.ComputerInfo
        return [math]::Round($info.TotalPhysicalMemory / 1GB, 1)
    } catch { }

    return $null
}

function Get-FreeDiskGB {
    $driveLetter = (Get-Location).Drive.Name

    try {
        $drive = New-Object System.IO.DriveInfo($driveLetter)
        if ($drive.IsReady) { return [math]::Round($drive.AvailableFreeSpace / 1GB, 1) }
    } catch { }

    try {
        $psDrive = Get-PSDrive -Name $driveLetter -ErrorAction Stop
        if ($psDrive.Free) { return [math]::Round($psDrive.Free / 1GB, 1) }
    } catch { }

    return $null
}

function Get-GpuInfo {
    $result = @()

    # nvidia-smi 给出的显存最准确
    if (Get-Command nvidia-smi -ErrorAction SilentlyContinue) {
        try {
            $lines = & nvidia-smi --query-gpu=name,memory.total --format=csv,noheader 2>$null
            foreach ($line in $lines) {
                if ([string]::IsNullOrWhiteSpace($line)) { continue }
                $parts = $line -split ','
                $name = $parts[0].Trim()
                $vramGB = 0.0
                if ($parts.Count -gt 1 -and $parts[1] -match '(\d+(?:\.\d+)?)\s*(MiB|GiB|MB|GB)') {
                    $value = [double]$Matches[1]
                    if ($Matches[2] -eq 'MiB' -or $Matches[2] -eq 'MB') { $value = $value / 1024 }
                    $vramGB = [math]::Round($value, 1)
                }
                $result += [pscustomobject]@{ Name = $name; VramGB = $vramGB }
            }
        } catch { }
    }
    if ($result.Count -gt 0) { return $result }

    # 兜底：WMI（AdapterRAM 在部分驱动上不可靠，仅作参考）
    try {
        $controllers = Get-CimInstance -ClassName Win32_VideoController -ErrorAction Stop
        foreach ($c in $controllers) {
            $vram = 0.0
            if ($c.AdapterRAM -and $c.AdapterRAM -gt 0) {
                $vram = [math]::Round($c.AdapterRAM / 1GB, 1)
                if ($vram -gt 256) { $vram = 0.0 }   # 明显失真的值不展示
            }
            $result += [pscustomobject]@{ Name = $c.Name; VramGB = $vram }
        }
    } catch { }

    return $result
}

function Test-PortOpen {
    param([int]$Port, [string]$HostName = '127.0.0.1', [int]$TimeoutMs = 400)
    $client = New-Object System.Net.Sockets.TcpClient
    try {
        $task = $client.ConnectAsync($HostName, $Port)
        if ($task.Wait($TimeoutMs) -and $client.Connected) { return $true }
        return $false
    } catch {
        return $false
    } finally {
        $client.Dispose()
    }
}

# ---------- 1. 操作系统 ----------
$os = try { (Get-CimInstance Win32_OperatingSystem -ErrorAction Stop).Caption } catch { [System.Environment]::OSVersion.VersionString }
Add-Row '操作系统' "$os  (PowerShell $($PSVersionTable.PSVersion))" '通过'

# ---------- 2. 内存 ----------
$memGB = Get-TotalMemoryGB
if ($null -eq $memGB) {
    Add-Row '物理内存' '无法读取' '跳过'
} elseif ($memGB -ge 32) {
    Add-Row '物理内存' "$memGB GB" '通过'
} elseif ($memGB -ge 15) {
    Add-Row '物理内存' "$memGB GB（16 GB 级，7B 模型可用，建议关闭其他大程序）" '通过'
} else {
    Add-Row '物理内存' "$memGB GB（建议只跑 1.5B～3B 小模型）" '警告'
}

# ---------- 3. 磁盘 ----------
$freeGB = Get-FreeDiskGB
if ($null -eq $freeGB) {
    Add-Row '磁盘剩余' '无法读取' '跳过'
} elseif ($freeGB -ge $MinDiskGB) {
    Add-Row '磁盘剩余' "$freeGB GB" '通过'
} else {
    Add-Row '磁盘剩余' "$freeGB GB（低于建议的 $MinDiskGB GB）" '警告'
}

# ---------- 4. 显卡 ----------
$gpus = @(Get-GpuInfo)
$maxVram = 0.0
if ($gpus.Count -eq 0) {
    Add-Row '显卡' '未检测到（将使用 CPU 推理）' '跳过'
} else {
    foreach ($gpu in $gpus) {
        if ($gpu.VramGB -gt $maxVram) { $maxVram = $gpu.VramGB }
        $desc = if ($gpu.VramGB -gt 0) { "$($gpu.Name)（约 $($gpu.VramGB) GB 显存）" } else { $gpu.Name }
        Add-Row '显卡' $desc '通过'
    }
    if ($maxVram -gt 0 -and $maxVram -lt 4) {
        Add-Row '显存结论' '偏小，建议 1.5B～3B 模型' '警告'
    }
}

# ---------- 5. Docker ----------
if (Get-Command docker -ErrorAction SilentlyContinue) {
    $dockerVersion = ''
    try { $dockerVersion = (& docker version --format '{{.Server.Version}}' 2>$null) } catch { }
    if ($dockerVersion) {
        Add-Row 'Docker' "Server $dockerVersion" '通过'
        $composeVersion = ''
        try { $composeVersion = (& docker compose version --short 2>$null) } catch { }
        if ($composeVersion) {
            Add-Row 'Docker Compose' "v$composeVersion" '通过'
        } else {
            Add-Row 'Docker Compose' '未安装 v2 插件' '警告'
        }
    } else {
        Add-Row 'Docker' '已安装但服务未启动，请先打开 Docker Desktop' '警告'
    }
} else {
    Add-Row 'Docker' '未安装（可改用 Windows 原生 Ollama）' '跳过'
}

# ---------- 6. Ollama ----------
if (Get-Command ollama -ErrorAction SilentlyContinue) {
    $ollamaVersion = ''
    try { $ollamaVersion = (& ollama --version 2>$null | Select-Object -First 1) } catch { }
    Add-Row 'Ollama' "$ollamaVersion" '通过'
} else {
    Add-Row 'Ollama' '未安装（winget install Ollama.Ollama）' '跳过'
}

# ---------- 7. 端口 ----------
foreach ($port in 11434, 3000) {
    if (Test-PortOpen -Port $port) {
        Add-Row "端口 $port" '已被占用（可能服务已启动）' '提示'
    } else {
        Add-Row "端口 $port" '空闲' '通过'
    }
}

# ---------- 输出（按显示宽度对齐，兼容中文） ----------
$itemWidth = 12
$valueWidth = 66
Write-Host ('检查项' + (' ' * 6) + '结果' + (' ' * ($valueWidth - 4)) + '状态') -ForegroundColor White
Write-Host ('-' * 100) -ForegroundColor DarkGray
foreach ($row in $rows) {
    $color = switch ($row.Status) {
        '警告' { 'Yellow' }
        '跳过' { 'DarkGray' }
        '提示' { 'Cyan' }
        default { 'Gray' }
    }
    $line = (Format-Cell $row.Item $itemWidth) + (Format-Cell $row.Value $valueWidth) + $row.Status
    Write-Host $line -ForegroundColor $color
}
Write-Host ('-' * 100) -ForegroundColor DarkGray

# ---------- 结论 ----------
if ($maxVram -ge 24) {
    $suggest = 'qwen2.5:32b（Q4）或 qwen2.5:14b'
} elseif ($maxVram -ge 12) {
    $suggest = 'qwen2.5:14b（Q4）或 qwen2.5:7b'
} elseif ($maxVram -ge 6) {
    $suggest = 'qwen2.5:7b（Q4_K_M）'
} elseif ($maxVram -gt 0) {
    $suggest = 'qwen2.5:1.5b / phi3.5:3.8b'
} else {
    $suggest = 'qwen2.5:1.5b（纯 CPU，速度较慢）'
}

Write-Host ''
Write-Host ('推荐模型：' + $suggest) -ForegroundColor Cyan
Write-Host '下一步：.\scripts\start.ps1   或   docker compose up -d' -ForegroundColor DarkGray
