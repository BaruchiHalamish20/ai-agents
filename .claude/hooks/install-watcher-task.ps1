# install-watcher-task.ps1
# Registers a Windows scheduled task that runs watch-and-convert.ps1
# at user logon. Idempotent — re-running replaces the existing task.

$ErrorActionPreference = 'Stop'

$TaskName   = 'ClaudeWatcher-AiAgents'
$ScriptPath = 'C:\softech\MaarachHadigital\roi-course\RoiTeachme\work\ai-agents\.claude\hooks\watch-and-convert.ps1'

if (-not (Test-Path $ScriptPath)) {
    throw "watcher script not found: $ScriptPath"
}

$Action = New-ScheduledTaskAction `
    -Execute 'pwsh.exe' `
    -Argument "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$ScriptPath`""

$Trigger = New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME

$Settings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -StartWhenAvailable `
    -RestartCount 3 `
    -RestartInterval (New-TimeSpan -Minutes 1)

$Principal = New-ScheduledTaskPrincipal `
    -UserId $env:USERNAME `
    -LogonType Interactive `
    -RunLevel Limited

Register-ScheduledTask `
    -TaskName $TaskName `
    -Action $Action `
    -Trigger $Trigger `
    -Settings $Settings `
    -Principal $Principal `
    -Force | Out-Null

Write-Host "Registered scheduled task: $TaskName"
Write-Host "Trigger: at logon for user $env:USERNAME"
Write-Host "Start it now without logging out:  Start-ScheduledTask -TaskName $TaskName"
Write-Host "Inspect logs:  Get-Content '$($PSScriptRoot)\watch-and-convert.log' -Tail 50 -Wait"
