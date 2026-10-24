$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\Notifications.ps1"
$binding = [pscustomobject]@{ Lines = @('Example caller', 'Incoming voice call') }
$binding | Add-Member ScriptMethod GetTextElements { @($this.Lines | ForEach-Object { [pscustomobject]@{ Text = $_ } }) }
$visual = [pscustomobject]@{ Binding = $binding }
$visual | Add-Member ScriptMethod GetBinding { param($name) $this.Binding }
$fake = [pscustomobject]@{
    Id = 1; CreationTime = [DateTimeOffset]::Now
    AppInfo = [pscustomobject]@{ PackageFamilyName = '5319275A.WhatsAppDesktop_cv1g1gvanyjgm' }
    Notification = [pscustomobject]@{ Visual = $visual }
}
if (-not (Convert-WhatsAppNotification $fake).IsCall) { throw 'English call detection failed' }
$binding.Lines = @('Example caller', 'Panggilan video masuk')
if (-not (Convert-WhatsAppNotification $fake).IsCall) { throw 'Indonesian call detection failed' }
$binding.Lines = @('Example sender', 'See you tomorrow')
if ((Convert-WhatsAppNotification $fake).IsCall) { throw 'Message classified as call' }
$fake.AppInfo.PackageFamilyName = 'OtherApp'
if ($null -ne (Convert-WhatsAppNotification $fake)) { throw 'Other app passed WhatsApp filter' }
$fake.AppInfo.PackageFamilyName = '5319275A.WhatsAppDesktop_cv1g1gvanyjgm'
$visual.Binding = $null
if ($null -ne (Convert-WhatsAppNotification $fake)) { throw 'Missing binding not ignored' }
Write-Output 'PASS: WhatsApp filter, call hints, ordinary messages, missing binding.'
$task = Start-NotificationRead
if (-not $task.Wait(10000)) { throw 'Notification API timed out' }
if ($task.IsFaulted) { throw $task.Exception }
$count = @($task.Result | Where-Object { $_.AppInfo.PackageFamilyName -eq '5319275A.WhatsAppDesktop_cv1g1gvanyjgm' }).Count
Write-Output "PASS: Windows notification API read succeeded; WhatsApp notifications available: $count. Content not logged."
