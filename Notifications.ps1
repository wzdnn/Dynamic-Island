Add-Type -AssemblyName System.Runtime.WindowsRuntime
$null = [Windows.UI.Notifications.Management.UserNotificationListener, Windows.UI.Notifications, ContentType=WindowsRuntime]
$null = [Windows.UI.Notifications.UserNotification, Windows.UI.Notifications, ContentType=WindowsRuntime]
$null = [Windows.UI.Notifications.NotificationKinds, Windows.UI.Notifications, ContentType=WindowsRuntime]
$script:notificationListener = [Windows.UI.Notifications.Management.UserNotificationListener]::Current
$script:asTask = [System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object {
    $_.Name -eq 'AsTask' -and $_.IsGenericMethod -and $_.GetGenericArguments().Count -eq 1 -and
    $_.GetParameters().Count -eq 1 -and $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1'
} | Select-Object -First 1

function script:Start-NotificationRead {
    if ($script:notificationListener.GetAccessStatus().ToString() -ne 'Allowed') {
        throw 'Akses notifikasi Windows belum diizinkan.'
    }
    $operation = $script:notificationListener.GetNotificationsAsync([Windows.UI.Notifications.NotificationKinds]::Toast)
    $type = [System.Collections.Generic.IReadOnlyList[Windows.UI.Notifications.UserNotification]]
    return $script:asTask.MakeGenericMethod($type).Invoke($null, @($operation))
}

function script:Convert-WindowsNotification($notification) {
    $isWhatsApp = $notification.AppInfo.PackageFamilyName -eq '5319275A.WhatsAppDesktop_cv1g1gvanyjgm'
    $appName = $notification.AppInfo.DisplayInfo.DisplayName
    if ([string]::IsNullOrWhiteSpace($appName)) { $appName = 'Windows' }
    $binding = $notification.Notification.Visual.GetBinding('ToastGeneric')
    if ($null -eq $binding) { return }
    $lines = @($binding.GetTextElements() | ForEach-Object { $_.Text })
    if ($lines.Count -eq 0) { return }
    $body = ($lines | Select-Object -Skip 1) -join ' · '
    # shortcut: notification text only hints at a call, use a WhatsApp API if one becomes available.
    $call = $isWhatsApp -and $body -match '(?i)(incoming (voice |video )?call|panggilan (suara |video )?masuk|calling you|sedang menelepon)'
    return [pscustomobject]@{ Id = $notification.Id; Created = $notification.CreationTime; AppName = $appName; Title = $lines[0]; Body = $body; IsCall = $call; IsWhatsApp = $isWhatsApp }
}
