$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\Notifications.ps1"
$binding = [pscustomobject]@{ Lines = @('Example caller', 'Incoming voice call') }
$binding | Add-Member ScriptMethod GetTextElements { @($this.Lines | ForEach-Object { [pscustomobject]@{ Text = $_ } }) }
$visual = [pscustomobject]@{ Binding = $binding }
$visual | Add-Member ScriptMethod GetBinding { param($name) $this.Binding }
$fake = [pscustomobject]@{
    Id = 1; CreationTime = [DateTimeOffset]::Now
    AppInfo = [pscustomobject]@{ PackageFamilyName = '5319275A.WhatsAppDesktop_cv1g1gvanyjgm'; DisplayInfo = [pscustomobject]@{ DisplayName = 'WhatsApp' } }
    Notification = [pscustomobject]@{ Visual = $visual }
}
if (-not (Convert-WindowsNotification $fake).IsCall) { throw 'English call detection failed' }
$binding.Lines = @('Example caller', 'Panggilan video masuk')
if (-not (Convert-WindowsNotification $fake).IsCall) { throw 'Indonesian call detection failed' }
$binding.Lines = @('Example sender', 'See you tomorrow')
if ((Convert-WindowsNotification $fake).IsCall) { throw 'Message classified as call' }
$fake.AppInfo.PackageFamilyName = 'OtherApp'
$fake.AppInfo.DisplayInfo.DisplayName = 'Google Chrome'
$binding.Lines = @('web.whatsapp.com', 'Incoming voice call')
$entry = Convert-WindowsNotification $fake
if ($entry.AppName -ne 'Google Chrome' -or $entry.Title -ne 'web.whatsapp.com' -or $entry.Body -ne 'Incoming voice call' -or $entry.IsCall -or $entry.IsWhatsApp) { throw 'Browser notification conversion failed' }
$fake.AppInfo.DisplayInfo.DisplayName = ''
$binding.Lines = @('Title only')
$entry = Convert-WindowsNotification $fake
if ($entry.AppName -ne 'Windows' -or $entry.Body -ne '') { throw 'Fallback or title-only conversion failed' }
$binding.Lines = @()
if ($null -ne (Convert-WindowsNotification $fake)) { throw 'Empty notification not ignored' }
$fake.AppInfo.PackageFamilyName = '5319275A.WhatsAppDesktop_cv1g1gvanyjgm'
$visual.Binding = $null
if ($null -ne (Convert-WindowsNotification $fake)) { throw 'Missing binding not ignored' }
Write-Output 'PASS: all applications, browser metadata, WA-only call hints, title-only, empty and missing binding.'
$task = Start-NotificationRead
if (-not $task.Wait(10000)) { throw 'Notification API timed out' }
if ($task.IsFaulted) { throw $task.Exception }
$count = @($task.Result).Count
$converted = @($task.Result | ForEach-Object { Convert-WindowsNotification $_ }).Count
Write-Output "PASS: Windows notification API read succeeded; Windows notifications available: $count. Content not logged."
Write-Output "PASS: real Windows notification conversion succeeded; readable notifications: $converted. Content not logged."
