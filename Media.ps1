param([double]$SeekSeconds = -1, [string]$ExpectedSource, [string]$ExpectedTitle, [string]$ExpectedArtist)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Runtime.WindowsRuntime
if (-not ('MediaReader' -as [type])) { Add-Type -Path "$PSScriptRoot\MediaReader.cs" }
$null = [Windows.Media.Control.GlobalSystemMediaTransportControlsSessionManager, Windows.Media.Control, ContentType=WindowsRuntime]
$null = [Windows.Media.Control.GlobalSystemMediaTransportControlsSessionMediaProperties, Windows.Media.Control, ContentType=WindowsRuntime]
$null = [Windows.Storage.Streams.IRandomAccessStreamWithContentType, Windows.Storage.Streams, ContentType=WindowsRuntime]
if ($null -eq $global:islandMediaAsTask) {
$global:islandMediaAsTask = [System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object {
    $_.Name -eq 'AsTask' -and $_.IsGenericMethod -and $_.GetGenericArguments().Count -eq 1 -and
    $_.GetParameters().Count -eq 1 -and $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1'
} | Select-Object -First 1
}
function Wait-MediaOperation($operation, [type]$type) {
    $task = $global:islandMediaAsTask.MakeGenericMethod($type).Invoke($null, @($operation))
    if (-not $task.Wait(3000)) { throw 'Media API timeout' }
    return $task.Result
}
if ($null -eq $global:islandMediaManager) {
    $global:islandMediaManager = Wait-MediaOperation ([Windows.Media.Control.GlobalSystemMediaTransportControlsSessionManager]::RequestAsync()) ([Windows.Media.Control.GlobalSystemMediaTransportControlsSessionManager])
}
try { $session = $global:islandMediaManager.GetCurrentSession() }
catch { $global:islandMediaManager = $null; throw }
if ($SeekSeconds -ne -1 -and $null -eq $session) { throw 'Sesi media sudah ditutup.' }
if ($null -eq $session) {
    $global:islandCoverCache = $null
    return [pscustomobject]@{ Title = ''; Artist = ''; Cover = $null }
}
$properties = Wait-MediaOperation ($session.TryGetMediaPropertiesAsync()) ([Windows.Media.Control.GlobalSystemMediaTransportControlsSessionMediaProperties])
$timeline = $session.GetTimelineProperties()
$playback = $session.GetPlaybackInfo()
if ($SeekSeconds -ne -1) {
    if ([double]::IsNaN($SeekSeconds) -or [double]::IsInfinity($SeekSeconds) -or $SeekSeconds -lt 0) { throw 'Posisi lagu tidak valid.' }
    if ($session.SourceAppUserModelId -cne $ExpectedSource -or $properties.Title -cne $ExpectedTitle -or $properties.Artist -cne $ExpectedArtist) { throw 'Lagu sudah berubah; geser kembali pada lagu baru.' }
    if (-not $playback.Controls.IsPlaybackPositionEnabled -or $timeline.EndTime -le $timeline.StartTime) { throw 'Pemutar tidak mendukung seek.' }
    $target = [math]::Max($timeline.MinSeekTime.TotalSeconds, [math]::Min($timeline.MaxSeekTime.TotalSeconds, $timeline.StartTime.TotalSeconds + $SeekSeconds))
    $success = Wait-MediaOperation ($session.TryChangePlaybackPositionAsync([TimeSpan]::FromSeconds($target).Ticks)) ([bool])
    if (-not $success) { throw 'Pemutar menolak perubahan posisi.' }
    return [pscustomobject]@{ SeekSucceeded = $true; Position = $target - $timeline.StartTime.TotalSeconds; Updated = [DateTimeOffset]::Now }
}
$coverKey = @($session.SourceAppUserModelId, $properties.Title, $properties.Artist, $properties.AlbumTitle, ($null -ne $properties.Thumbnail)) | ConvertTo-Json -Compress
if ($null -eq $global:islandCoverCache -or $global:islandCoverCache.Key -cne $coverKey -or [datetime]::UtcNow -ge $global:islandCoverCache.RefreshAt) {
$cover = $null
if ($null -ne $properties.Thumbnail) {
    $stream = $null
    try {
        $stream = Wait-MediaOperation ($properties.Thumbnail.OpenReadAsync()) ([Windows.Storage.Streams.IRandomAccessStreamWithContentType])
        $cover = [MediaReader]::ReadCover($stream)
    } catch { $cover = $null }
    finally {
        if ($null -ne $stream -and [Runtime.InteropServices.Marshal]::IsComObject($stream)) {
            [void][Runtime.InteropServices.Marshal]::ReleaseComObject($stream)
        }
    }
}
$token = 'none'
if ($null -ne $cover) {
    $hash = [Security.Cryptography.SHA256]::Create()
    try { $token = [Convert]::ToBase64String($hash.ComputeHash($cover)) }
    finally { $hash.Dispose() }
}
$global:islandCoverCache = [pscustomobject]@{
    Key=$coverKey; Cover=$cover; Token=$token
    RefreshAt=[datetime]::UtcNow.AddSeconds($(if ($null -eq $cover) { 5 } else { 30 }))
}
}
[pscustomobject]@{
    Title = $properties.Title; Artist = $properties.Artist
    Cover = $global:islandCoverCache.Cover; CoverToken = $global:islandCoverCache.Token
    Source = $session.SourceAppUserModelId
    Duration = ($timeline.EndTime - $timeline.StartTime).TotalSeconds
    Position = ($timeline.Position - $timeline.StartTime).TotalSeconds; Updated = $timeline.LastUpdatedTime
    Playing = $playback.PlaybackStatus.ToString() -eq 'Playing'
    Rate = if ($null -eq $playback.PlaybackRate) { 1.0 } else { [double]$playback.PlaybackRate }
    CanSeek = $playback.Controls.IsPlaybackPositionEnabled -and $timeline.EndTime -gt $timeline.StartTime
}
