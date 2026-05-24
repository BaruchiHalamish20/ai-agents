# watch-and-convert.ps1
# FileSystemWatcher service for the ai-agents project. Watches the two
# source folders and, after a quiet period, fires the matching skill via
# `claude -p` (headless).
#
#   to-convert-word-files/   -> /word-to-pdf-suite:convert-to-pdf
#   converted-pdf-files/     -> /markdown-suite:convert-to-md
#
# Designed to run as a Windows scheduled task at logon. See
# install-watcher-task.ps1 for registration.

$ErrorActionPreference = 'Stop'

$ProjectRoot = 'C:\softech\MaarachHadigital\roi-course\RoiTeachme\work\ai-agents'
$LogDir      = Join-Path $ProjectRoot '.claude\hooks'
$LogFile     = Join-Path $LogDir 'watch-and-convert.log'
$SentinelDir = Join-Path $LogDir 'watch-sentinels'
$QuietSec    = 8   # wait this long after the last event before firing the skill
$TickSec     = 2

New-Item -ItemType Directory -Force -Path $LogDir, $SentinelDir | Out-Null

function Write-Log($msg) {
    $line = '{0:yyyy-MM-dd HH:mm:ss}  {1}' -f (Get-Date), $msg
    Add-Content -Path $LogFile -Value $line
}

$watchers = @(
    [pscustomobject]@{
        Key        = 'word'
        Folder     = Join-Path $ProjectRoot 'to-convert-word-files'
        Extensions = @('.doc', '.docx')
        Skill      = '/word-to-pdf-suite:convert-to-pdf'
        Sentinel   = Join-Path $SentinelDir 'word.sentinel'
    },
    [pscustomobject]@{
        Key        = 'pdf'
        Folder     = Join-Path $ProjectRoot 'converted-pdf-files'
        Extensions = @('.pdf', '.html', '.htm')
        Skill      = '/markdown-suite:convert-to-md'
        Sentinel   = Join-Path $SentinelDir 'pdf.sentinel'
    }
)

$action = {
    $w    = $Event.MessageData
    $path = $Event.SourceEventArgs.FullPath
    $name = Split-Path $path -Leaf
    if ($name -like '~$*') { return }                        # Word lock files
    $ext = [IO.Path]::GetExtension($name).ToLower()
    if ($w.Extensions -notcontains $ext) { return }
    Set-Content -Path $w.Sentinel -Value (Get-Date -Format o) -Force
    Add-Content -Path $w.LogFile -Value (
        '{0:yyyy-MM-dd HH:mm:ss}  event {1} {2}' -f (Get-Date), $Event.SourceEventArgs.ChangeType, $path
    )
}

$fsws = @()
foreach ($w in $watchers) {
    if (-not (Test-Path $w.Folder)) {
        New-Item -ItemType Directory -Force -Path $w.Folder | Out-Null
    }
    $fsw = New-Object System.IO.FileSystemWatcher $w.Folder, '*.*'
    $fsw.IncludeSubdirectories = $true
    $fsw.EnableRaisingEvents    = $true

    $msg = [pscustomobject]@{
        Key        = $w.Key
        Sentinel   = $w.Sentinel
        Extensions = $w.Extensions
        LogFile    = $LogFile
    }
    Register-ObjectEvent -InputObject $fsw -EventName Created -Action $action -MessageData $msg | Out-Null
    Register-ObjectEvent -InputObject $fsw -EventName Changed -Action $action -MessageData $msg | Out-Null
    Register-ObjectEvent -InputObject $fsw -EventName Renamed -Action $action -MessageData $msg | Out-Null

    $fsws += $fsw
    Write-Log "watcher armed: $($w.Key) on $($w.Folder)"
}

Write-Log "watcher service started (quiet=${QuietSec}s, tick=${TickSec}s)"

try {
    while ($true) {
        Start-Sleep -Seconds $TickSec
        foreach ($w in $watchers) {
            if (-not (Test-Path $w.Sentinel)) { continue }
            $raw = (Get-Content $w.Sentinel -Raw).Trim()
            if (-not $raw) { continue }
            $stamp = [datetime]::Parse($raw)
            $age   = (Get-Date) - $stamp
            if ($age.TotalSeconds -lt $QuietSec) { continue }

            Remove-Item $w.Sentinel -Force
            Write-Log "-> firing $($w.Skill)"
            $stdoutFile = Join-Path $env:TEMP "claude-watch-$([Guid]::NewGuid()).out"
            $stderrFile = Join-Path $env:TEMP "claude-watch-$([Guid]::NewGuid()).err"
            try {
                # Use cmd.exe /c to give claude.cmd a real console attached to a
                # disposable conhost, then redirect to files. Running `& claude`
                # directly from a hidden pwsh kills the process tree with
                # STATUS_CONTROL_C_EXIT when claude.cmd tries to attach to a
                # missing console. --dangerously-skip-permissions because the
                # watcher is unattended.
                $proc = Start-Process -FilePath 'cmd.exe' `
                    -ArgumentList '/d', '/c', 'claude', '-p', $w.Skill, '--dangerously-skip-permissions' `
                    -WorkingDirectory $ProjectRoot `
                    -RedirectStandardOutput $stdoutFile `
                    -RedirectStandardError  $stderrFile `
                    -WindowStyle Hidden `
                    -PassThru -Wait
                Write-Log "<- done $($w.Skill) (exit=$($proc.ExitCode))"
                foreach ($f in @($stdoutFile, $stderrFile)) {
                    if ((Test-Path $f) -and (Get-Item $f).Length -gt 0) {
                        Get-Content $f | ForEach-Object { Write-Log "   $_" }
                    }
                }
            }
            catch {
                Write-Log "   ERROR: $_"
            }
            finally {
                Remove-Item $stdoutFile, $stderrFile -Force -ErrorAction SilentlyContinue
            }
        }
    }
}
finally {
    foreach ($fsw in $fsws) { $fsw.Dispose() }
    Get-EventSubscriber | Unregister-Event -ErrorAction SilentlyContinue
    Write-Log 'watcher service stopped'
}
