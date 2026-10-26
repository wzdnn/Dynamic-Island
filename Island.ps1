param([switch]$SelfTest, [switch]$IntegrationTest, [string]$SettingsPath = "$PSScriptRoot\settings.local.json")
$ErrorActionPreference = 'Stop'
$instanceMutex = $null
$ownsMutex = $false
if (-not ($SelfTest -or $IntegrationTest)) {
    $account = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
    $instanceMutex = New-Object Threading.Mutex($false, "Local\DynamicIsland.$account")
    try { $ownsMutex = $instanceMutex.WaitOne(0) }
    catch [Threading.AbandonedMutexException] { $ownsMutex = $true }
    if (-not $ownsMutex) { $instanceMutex.Dispose(); Write-Output 'Dynamic Island sudah berjalan.'; exit 0 }
}
try {
Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, System.Windows.Forms
Add-Type -Path "$PSScriptRoot\WhatsAppCalls.cs"
Add-Type -Path "$PSScriptRoot\AppVolume.cs"

function Read-IslandTopmost([string]$path) {
    if (-not [IO.File]::Exists($path)) { return $true }
    try {
        $settings = Get-Content -LiteralPath $path -Raw | ConvertFrom-Json
        if ($settings.AlwaysOnTop -isnot [bool]) { throw 'Invalid AlwaysOnTop value' }
        return $settings.AlwaysOnTop
    } catch {
        Write-Warning 'Pengaturan Always on top tidak dapat dibaca; memakai default aktif.'
        return $true
    }
}

function Save-IslandTopmost([string]$path, [bool]$enabled) {
    $temporaryPath = "$path.tmp"
    try {
        [IO.File]::WriteAllText($temporaryPath, (@{ AlwaysOnTop = $enabled } | ConvertTo-Json))
        if ([IO.File]::Exists($path)) { [IO.File]::Replace($temporaryPath, $path, [NullString]::Value) }
        else { [IO.File]::Move($temporaryPath, $path) }
    } finally {
        if ([IO.File]::Exists($temporaryPath)) { [IO.File]::Delete($temporaryPath) }
    }
}

function Get-BatteryLabel {
    $power = [System.Windows.Forms.SystemInformation]::PowerStatus
    if (($power.BatteryChargeStatus -band 128) -ne 0) { return 'Tanpa baterai' }
    $percent = [math]::Round($power.BatteryLifePercent * 100)
    if ($percent -lt 0 -or $percent -gt 100) { return 'Baterai tidak tersedia' }
    $suffix = if ($power.PowerLineStatus -eq 'Online') { ' · Terhubung listrik' } else { ' · Baterai' }
    return "$percent%$suffix"
}

[xml]$markup = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Dynamic Island" Width="420" Height="340" WindowStyle="None"
        AllowsTransparency="True" Background="Transparent" Topmost="True"
        ResizeMode="NoResize" ShowInTaskbar="False" WindowStartupLocation="Manual" UseLayoutRounding="True">
 <Window.Resources>
  <PathGeometry x:Key="PlayIcon">M 5,2 L 17,10 5,18 Z</PathGeometry>
  <PathGeometry x:Key="PauseIcon">M 4,3 H 8 V 17 H 4 Z M 12,3 H 16 V 17 H 12 Z</PathGeometry>
  <PathGeometry x:Key="PreviousIcon">M 3,3 H 6 V 17 H 3 Z M 17,3 L 7,10 17,17 Z</PathGeometry>
  <PathGeometry x:Key="NextIcon">M 14,3 H 17 V 17 H 14 Z M 3,3 L 13,10 3,17 Z</PathGeometry>
  <DataTemplate x:Key="MediaIconTemplate">
   <Grid Width="20" Height="20"><Path Data="{Binding}" Fill="{Binding Foreground, RelativeSource={RelativeSource AncestorType=Button}}"/></Grid>
  </DataTemplate>
  <Style x:Key="SliderRail" TargetType="RepeatButton">
   <Setter Property="Focusable" Value="False"/>
   <Setter Property="Template"><Setter.Value><ControlTemplate TargetType="RepeatButton">
    <Grid Background="Transparent"><Border Height="4" CornerRadius="2" Background="{TemplateBinding Background}" VerticalAlignment="Center"/></Grid>
   </ControlTemplate></Setter.Value></Setter>
  </Style>
  <Style TargetType="Slider">
   <Setter Property="Height" Value="28"/>
   <Setter Property="Foreground" Value="#E5E5E9"/>
   <Setter Property="Template"><Setter.Value><ControlTemplate TargetType="Slider">
    <Grid x:Name="SliderChrome" Background="Transparent">
     <Border x:Name="FocusRing" BorderBrush="#ADFF6B" BorderThickness="1" CornerRadius="7" Opacity="0"/>
     <Border Height="4" Margin="12,0" CornerRadius="2" Background="#343439" IsHitTestVisible="False"/>
     <Track x:Name="PART_Track">
      <Track.DecreaseRepeatButton><RepeatButton Style="{StaticResource SliderRail}" Background="{TemplateBinding Foreground}" Command="Slider.DecreaseLarge"/></Track.DecreaseRepeatButton>
      <Track.Thumb><Thumb Width="24" Height="28">
       <Thumb.Template><ControlTemplate TargetType="Thumb">
        <Grid Background="Transparent"><Ellipse x:Name="Dot" Width="10" Height="10" Fill="#F5F5F7"/>
        </Grid>
        <ControlTemplate.Triggers>
         <Trigger Property="IsMouseOver" Value="True"><Setter TargetName="Dot" Property="Fill" Value="#ADFF6B"/></Trigger>
         <Trigger Property="IsDragging" Value="True"><Setter TargetName="Dot" Property="Fill" Value="#ADFF6B"/></Trigger>
        </ControlTemplate.Triggers>
       </ControlTemplate></Thumb.Template>
      </Thumb></Track.Thumb>
      <Track.IncreaseRepeatButton><RepeatButton Style="{StaticResource SliderRail}" Background="#343439" Command="Slider.IncreaseLarge"/></Track.IncreaseRepeatButton>
     </Track>
    </Grid>
    <ControlTemplate.Triggers>
     <Trigger Property="IsKeyboardFocusWithin" Value="True"><Setter TargetName="FocusRing" Property="Opacity" Value="1"/></Trigger>
     <Trigger Property="IsEnabled" Value="False"><Setter TargetName="SliderChrome" Property="Opacity" Value="0.35"/></Trigger>
    </ControlTemplate.Triggers>
   </ControlTemplate></Setter.Value></Setter>
  </Style>
  <Style TargetType="Button">
   <Setter Property="Foreground" Value="White"/><Setter Property="Background" Value="#202022"/>
   <Setter Property="BorderThickness" Value="0"/><Setter Property="Padding" Value="12,8"/>
   <Setter Property="Margin" Value="4"/><Setter Property="Cursor" Value="Hand"/>
   <Setter Property="Template"><Setter.Value><ControlTemplate TargetType="Button">
    <Border x:Name="Chrome" Background="{TemplateBinding Background}" CornerRadius="14" Padding="{TemplateBinding Padding}">
     <ContentPresenter ContentTemplate="{TemplateBinding ContentTemplate}" HorizontalAlignment="Center" VerticalAlignment="Center"/>
    </Border>
    <ControlTemplate.Triggers>
     <Trigger Property="IsMouseOver" Value="True"><Setter TargetName="Chrome" Property="Background" Value="#38383C"/></Trigger>
     <Trigger Property="IsKeyboardFocused" Value="True"><Setter TargetName="Chrome" Property="Background" Value="#454550"/></Trigger>
     <Trigger Property="IsEnabled" Value="False"><Setter TargetName="Chrome" Property="Opacity" Value="0.35"/></Trigger>
    </ControlTemplate.Triggers>
   </ControlTemplate></Setter.Value></Setter>
  </Style>
 </Window.Resources>
 <Border x:Name="Pill" Width="380" Height="48" CornerRadius="25" Background="#080808"
         VerticalAlignment="Top" HorizontalAlignment="Center" BorderBrush="#252525" BorderThickness="1" ClipToBounds="True">
  <Grid Margin="12,0">
   <Grid.RowDefinitions><RowDefinition Height="46"/><RowDefinition Height="*"/></Grid.RowDefinitions>
   <Grid>
    <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="36"/><ColumnDefinition Width="40"/><ColumnDefinition Width="36"/></Grid.ColumnDefinitions>
    <Button x:Name="Toggle" Background="Transparent" Margin="0" Padding="0" AutomationProperties.Name="Buka atau tutup Dynamic Island">
     <Grid Width="232">
      <Grid x:Name="IdleHeader">
       <TextBlock Text="●" Foreground="#ADFF6B" FontSize="15" VerticalAlignment="Center"/>
       <TextBlock x:Name="Clock" HorizontalAlignment="Center" FontSize="14" FontWeight="SemiBold" VerticalAlignment="Center"/>
      </Grid>
      <Grid x:Name="MediaHeader" Visibility="Collapsed">
       <Grid.ColumnDefinitions><ColumnDefinition Width="40"/><ColumnDefinition Width="*"/></Grid.ColumnDefinitions>
       <Grid Width="30" Height="30" HorizontalAlignment="Left">
        <TextBlock Text="♫" Foreground="#ADFF6B" FontSize="22" HorizontalAlignment="Center" VerticalAlignment="Center" Visibility="{Binding Visibility, ElementName=CoverFallback}"/>
        <Image Source="{Binding Source, ElementName=AlbumCover}" Stretch="UniformToFill" AutomationProperties.Name="Cover album"/>
       </Grid>
       <TextBlock Grid.Column="1" Text="{Binding Text, ElementName=TrackTitle}" ToolTip="{Binding Text, ElementName=TrackTitle}" Foreground="White" FontSize="13" FontWeight="SemiBold" VerticalAlignment="Center" TextTrimming="CharacterEllipsis"/>
      </Grid>
     </Grid>
    </Button>
    <Button x:Name="CompactPrevious" ContentTemplate="{StaticResource MediaIconTemplate}" Grid.Column="1" Content="{StaticResource PreviousIcon}" Padding="4" Margin="0,5,0,5" Background="Transparent" IsEnabled="{Binding IsEnabled, ElementName=CompactNext}" ToolTip="Lagu sebelumnya" AutomationProperties.Name="Putar lagu sebelumnya"/>
    <Button x:Name="CompactPlay" ContentTemplate="{StaticResource MediaIconTemplate}" Grid.Column="2" Content="{StaticResource PlayIcon}" Padding="4" Margin="0,5,0,5" Background="Transparent" IsEnabled="{Binding IsEnabled, ElementName=CompactNext}" ToolTip="Putar musik" AutomationProperties.Name="Putar musik"/>
    <Button x:Name="CompactNext" ContentTemplate="{StaticResource MediaIconTemplate}" Grid.Column="3" Content="{StaticResource NextIcon}" Padding="4" Margin="0,5,0,5" Background="Transparent" IsEnabled="False" ToolTip="Lagu berikutnya" AutomationProperties.Name="Putar lagu berikutnya"/>
   </Grid>
   <StackPanel x:Name="Details" Grid.Row="1" Visibility="Collapsed" Opacity="0" Margin="12,4,12,14">
    <StackPanel x:Name="Notice" Visibility="Collapsed" Margin="0,10,0,0">
     <TextBlock x:Name="NoticeKind" Foreground="#ADFF6B" FontSize="12"/>
     <TextBlock x:Name="NoticeTitle" Foreground="White" FontSize="18" FontWeight="SemiBold" TextTrimming="CharacterEllipsis"/>
     <TextBlock x:Name="NoticeBody" Foreground="#CCCCD0" FontSize="13" TextWrapping="Wrap" MaxHeight="38"/>
     <Button x:Name="OpenWhatsApp" Content="Buka WhatsApp" AutomationProperties.Name="Buka WhatsApp untuk pesan atau panggilan"/>
    </StackPanel>
    <TextBlock x:Name="NotificationStatus" Text="WhatsApp · Menghubungkan notifikasi…" Visibility="Collapsed"/>
    <StackPanel x:Name="MusicPanel">
    <Grid Margin="0,8,0,4">
     <Grid.ColumnDefinitions><ColumnDefinition Width="88"/><ColumnDefinition Width="*"/></Grid.ColumnDefinitions>
     <Border Width="72" Height="72" Background="#242428" CornerRadius="12" HorizontalAlignment="Left">
      <Grid>
       <Grid.Clip><RectangleGeometry Rect="0,0,72,72" RadiusX="12" RadiusY="12"/></Grid.Clip>
       <TextBlock x:Name="CoverFallback" Text="♫" Foreground="#ADFF6B" FontSize="32" HorizontalAlignment="Center" VerticalAlignment="Center"/>
       <Image x:Name="AlbumCover" Width="72" Height="72" Stretch="UniformToFill" AutomationProperties.Name="Cover media yang sedang diputar"/>
      </Grid>
     </Border>
     <StackPanel Grid.Column="1" VerticalAlignment="Center">
      <Border x:Name="TitleViewport" ClipToBounds="True">
       <StackPanel Orientation="Horizontal">
        <TextBlock x:Name="TrackTitle" Text="Belum ada media" Foreground="White" FontSize="17" FontWeight="SemiBold">
         <TextBlock.RenderTransform><TranslateTransform/></TextBlock.RenderTransform>
        </TextBlock>
       </StackPanel>
      </Border>
      <TextBlock x:Name="TrackArtist" Text="Putar lagu dari aplikasi musik" Foreground="#A1A1A8" FontSize="13" TextTrimming="CharacterEllipsis" Margin="0,6,0,0" ToolTip="{Binding Text, RelativeSource={RelativeSource Self}}"/>
     </StackPanel>
    </Grid>
    <Slider x:Name="TrackProgress" Minimum="0" Maximum="1" Value="0" IsEnabled="False" IsMoveToPointEnabled="True" SmallChange="5" LargeChange="10" Margin="0,8,0,0" AutomationProperties.Name="Posisi lagu dalam detik"/>
    <Grid Margin="0,2,0,4">
     <TextBlock x:Name="TrackPosition" Text="0:00" Foreground="#929298" FontSize="11"/>
     <TextBlock x:Name="TrackDuration" Text="--:--" Foreground="#929298" FontSize="11" HorizontalAlignment="Right"/>
    </Grid>
    <TextBlock x:Name="SeekStatus" Foreground="#929298" FontSize="11" Height="16" TextTrimming="CharacterEllipsis" ToolTip="{Binding Text, RelativeSource={RelativeSource Self}}"/>
    <Grid Margin="0,8,0,0"><TextBlock Text="Volume aplikasi" Foreground="#929298" FontSize="12"/><TextBlock x:Name="VolumeLabel" Text="--" Foreground="#929298" FontSize="12" HorizontalAlignment="Right"/></Grid>
    <Slider x:Name="AppVolumeSlider" Minimum="0" Maximum="100" Value="0" SmallChange="5" LargeChange="10" IsMoveToPointEnabled="True" IsEnabled="False" Margin="0,4,0,0" AutomationProperties.Name="Volume aplikasi musik dalam persen"/>
    </StackPanel>
    <Border BorderBrush="#252525" BorderThickness="0,1,0,0" Margin="0,10,0,0" Padding="0,8,0,0">
     <TextBlock x:Name="Battery" Foreground="#929298" FontSize="11" HorizontalAlignment="Right"/>
    </Border>
   </StackPanel>
  </Grid>
 </Border>
</Window>
'@
$window = [Windows.Markup.XamlReader]::Load((New-Object System.Xml.XmlNodeReader $markup))
if (-not ($SelfTest -or $IntegrationTest)) { $window.Topmost = Read-IslandTopmost $settingsPath }
$pill = $window.FindName('Pill')
$details = $window.FindName('Details')
$battery = $window.FindName('Battery')
$clock = $window.FindName('Clock')
$script:expanded = $false
$notice = $window.FindName('Notice')
$notificationStatus = $window.FindName('NotificationStatus')
$script:noticeUntil = [datetime]::MinValue
$script:notificationTask = $null
$script:notificationStarted = [DateTimeOffset]::Now
$script:seenNotifications = @{}
$script:retryNotificationsAt = [datetime]::MinValue
$script:notificationReady = $false
$script:callWindow = [IntPtr]::Zero
$script:mediaWorker = $null
$script:mediaPending = $null
$script:nextMediaRead = [datetime]::MinValue
$script:lastCoverToken = $null
$script:lastCoverBytes = $null
$script:nextBatteryRead = [datetime]::MinValue
$script:mediaTimeline = $null
$script:seekDragging = $false
$script:seekSnapshot = $null
$script:queuedSeek = $null
$script:seeking = $false
$progress = $window.FindName('TrackProgress')
$volumeSlider = $window.FindName('AppVolumeSlider')
$script:volumeDragging = $false
$script:volumeSource = $null

function Update-Volume {
    if ($script:volumeDragging -or -not $script:expanded -or $notice.Visibility -eq 'Visible') { return }
    try {
        $level = [AppVolume]::Read($script:mediaTimeline.Source)
        $volumeSlider.IsEnabled = $level -ge 0
        $window.FindName('VolumeLabel').Text = if ($level -ge 0) { "$level%" } else { 'Tidak tersedia' }
        if ($level -ge 0) { $volumeSlider.Value = $level }
    } catch {
        $volumeSlider.IsEnabled = $false
        $window.FindName('VolumeLabel').Text = 'Tidak tersedia'
    }
}
function Begin-VolumeChange {
    if (-not $volumeSlider.IsEnabled -or $script:volumeDragging) { return }
    $script:volumeDragging = $true
    $script:volumeSource = $script:mediaTimeline.Source
}
function Complete-VolumeChange {
    if (-not $script:volumeDragging) { return }
    $script:volumeDragging = $false
    try {
        if ($script:volumeSource -cne $script:mediaTimeline.Source) { throw 'Pemutar sudah berganti' }
        $level = [AppVolume]::Set($script:volumeSource, $volumeSlider.Value)
        if ($level -lt 0) { throw 'Sesi audio tidak tersedia' }
        $window.FindName('VolumeLabel').Text = "$level%"
    } catch { $window.FindName('VolumeLabel').Text = 'Gagal mengubah volume' }
}
$volumeSlider.Add_PreviewMouseLeftButtonDown({ Begin-VolumeChange })
$volumeSlider.Add_PreviewMouseLeftButtonUp({ Complete-VolumeChange })
$volumeSlider.Add_LostMouseCapture({ Complete-VolumeChange })
$volumeSlider.Add_PreviewKeyDown({ if ($_.Key -in @('Left','Right','Up','Down','Home','End','PageUp','PageDown')) { Begin-VolumeChange } })
$volumeSlider.Add_PreviewKeyUp({ Complete-VolumeChange })
$volumeSlider.Add_ValueChanged({ if ($script:volumeDragging) { $window.FindName('VolumeLabel').Text = ('{0}%' -f [math]::Round($volumeSlider.Value)) } })

function Format-TrackTime([double]$seconds) {
    $total = [long][math]::Floor([math]::Max(0, $seconds))
    if ($total -ge 3600) { return '{0}:{1:00}:{2:00}' -f [long][math]::Floor($total / 3600), ([long][math]::Floor($total / 60) % 60), ($total % 60) }
    return '{0}:{1:00}' -f [long][math]::Floor($total / 60), ($total % 60)
}

function Update-Timeline {
    if ($script:seekDragging -or $script:seeking -or $null -ne $script:queuedSeek) { return }
    $media = $script:mediaTimeline
    $duration = if ($null -ne $media) { [double]$media.Duration } else { 0 }
    $progress.IsEnabled = $duration -gt 0 -and $media.CanSeek
    $progress.Maximum = [math]::Max(1, $duration)
    $position = if ($null -ne $media) { [double]$media.Position } else { 0 }
    if ($null -ne $media -and $media.Playing -and $null -ne $media.Updated) {
        $position += [math]::Max(0, ([DateTimeOffset]::Now - $media.Updated).TotalSeconds) * $media.Rate
    }
    $progress.Value = [math]::Max(0, [math]::Min($duration, $position))
    $window.FindName('TrackPosition').Text = Format-TrackTime $progress.Value
    $window.FindName('TrackDuration').Text = if ($duration -gt 0) { Format-TrackTime $duration } else { '--:--' }
}

function Begin-Seek {
    if (-not $progress.IsEnabled -or $script:seekDragging) { return }
    $script:seekDragging = $true
    $script:seekSnapshot = $script:mediaTimeline
}

function Complete-Seek {
    if (-not $script:seekDragging) { return }
    $script:seekDragging = $false
    $script:queuedSeek = @{ SeekSeconds = $progress.Value; ExpectedSource = $script:seekSnapshot.Source; ExpectedTitle = $script:seekSnapshot.Title; ExpectedArtist = $script:seekSnapshot.Artist }
    $script:nextMediaRead = [datetime]::MinValue
    $progress.IsEnabled = $false
    $window.FindName('SeekStatus').Text = 'Memindahkan posisi…'
}
$progress.Add_PreviewMouseLeftButtonDown({ Begin-Seek })
$progress.Add_PreviewMouseLeftButtonUp({ Complete-Seek })
$progress.Add_LostMouseCapture({ Complete-Seek })
$progress.Add_PreviewKeyDown({ if ($_.Key -in @('Left','Right','Up','Down','Home','End','PageUp','PageDown')) { Begin-Seek } })
$progress.Add_PreviewKeyUp({ Complete-Seek })
$progress.Add_ValueChanged({ if ($script:seekDragging) { $window.FindName('TrackPosition').Text = Format-TrackTime $progress.Value } })

function Get-CoverAccent([Windows.Media.Imaging.BitmapSource]$bitmap) {
    $small = New-Object Windows.Media.Imaging.TransformedBitmap($bitmap, (New-Object Windows.Media.ScaleTransform((8.0 / $bitmap.PixelWidth), (8.0 / $bitmap.PixelHeight))))
    $sample = New-Object Windows.Media.Imaging.FormatConvertedBitmap($small, [Windows.Media.PixelFormats]::Bgra32, $null, 0)
    $pixels = New-Object byte[] ($sample.PixelWidth * $sample.PixelHeight * 4)
    $sample.CopyPixels($pixels, ($sample.PixelWidth * 4), 0)
    $red = $green = $blue = $weight = 0.0
    for ($i = 0; $i -lt $pixels.Length; $i += 4) {
        $alpha = $pixels[$i + 3] / 255.0
        $blue += $pixels[$i] * $alpha
        $green += $pixels[$i + 1] * $alpha
        $red += $pixels[$i + 2] * $alpha
        $weight += $alpha
    }
    if ($weight -eq 0) { return [Windows.Media.BrushConverter]::new().ConvertFromString('#E5E5E9') }
    # A light, muted tint keeps even dark artwork readable against the slider rail.
    $color = [Windows.Media.Color]::FromRgb([byte](128 + 0.45 * $red / $weight), [byte](128 + 0.45 * $green / $weight), [byte](128 + 0.45 * $blue / $weight))
    $brush = New-Object Windows.Media.SolidColorBrush($color)
    $brush.Freeze()
    return $brush
}

function Update-TitleScroll {
    $title = $window.FindName('TrackTitle')
    $viewport = $window.FindName('TitleViewport')
    $transform = $title.RenderTransform
    $transform.BeginAnimation([Windows.Media.TranslateTransform]::XProperty, $null)
    $transform.X = 0
    $overflow = $title.ActualWidth - $viewport.ActualWidth
    if (-not $script:expanded -or $notice.Visibility -eq 'Visible' -or $viewport.ActualWidth -le 0 -or $overflow -le 1 -or -not [Windows.SystemParameters]::ClientAreaAnimation) { return }
    $animation = New-Object Windows.Media.Animation.DoubleAnimationUsingKeyFrames
    [void]$animation.KeyFrames.Add([Windows.Media.Animation.LinearDoubleKeyFrame]::new(0, [Windows.Media.Animation.KeyTime]::FromTimeSpan([TimeSpan]::FromSeconds(1.5))))
    [void]$animation.KeyFrames.Add([Windows.Media.Animation.LinearDoubleKeyFrame]::new(-$overflow, [Windows.Media.Animation.KeyTime]::FromTimeSpan([TimeSpan]::FromSeconds(1.5 + $overflow / 24))))
    [void]$animation.KeyFrames.Add([Windows.Media.Animation.LinearDoubleKeyFrame]::new(-$overflow, [Windows.Media.Animation.KeyTime]::FromTimeSpan([TimeSpan]::FromSeconds(2.5 + $overflow / 24))))
    $animation.AutoReverse = $true
    $animation.RepeatBehavior = [Windows.Media.Animation.RepeatBehavior]::Forever
    $transform.BeginAnimation([Windows.Media.TranslateTransform]::XProperty, $animation)
}
$window.FindName('TitleViewport').Add_SizeChanged({ Update-TitleScroll })
$window.FindName('TrackTitle').Add_SizeChanged({ Update-TitleScroll })

function Set-MediaPanel($media) {
    $script:mediaTimeline = $media
    Update-Timeline
    $hasMedia = $null -ne $media -and -not [string]::IsNullOrWhiteSpace($media.Title)
    $window.FindName('MediaHeader').Visibility = if ($hasMedia) { 'Visible' } else { 'Collapsed' }
    $window.FindName('IdleHeader').Visibility = if ($hasMedia) { 'Collapsed' } else { 'Visible' }
    $window.FindName('CompactNext').IsEnabled = $hasMedia
    $playButton = $window.FindName('CompactPlay')
    $playButton.Content = if ($hasMedia -and $media.Playing) { $window.Resources['PauseIcon'] } else { $window.Resources['PlayIcon'] }
    $playButton.ToolTip = if ($hasMedia -and $media.Playing) { 'Jeda musik' } else { 'Putar musik' }
    [Windows.Automation.AutomationProperties]::SetName($playButton, $playButton.ToolTip)
    $title = if ($null -ne $media -and -not [string]::IsNullOrWhiteSpace($media.Title)) { $media.Title } else { 'Belum ada media' }
    $titleChanged = $window.FindName('TrackTitle').Text -cne $title
    $window.FindName('TrackTitle').Text = $title
    if ($titleChanged) { Update-TitleScroll }
    $window.FindName('TrackTitle').ToolTip = $title
    $window.FindName('TrackArtist').Text = if ($null -ne $media) { $media.Artist } else { 'Putar lagu dari aplikasi musik' }
    $sameCover = if ($null -ne $media -and $media.CoverToken) {
        $media.CoverToken -ceq $script:lastCoverToken
    } else { [object]::ReferenceEquals($media.Cover, $script:lastCoverBytes) }
    if ($sameCover) { return }
    $progress.ClearValue([Windows.Controls.Control]::ForegroundProperty)
    $script:lastCoverToken = $media.CoverToken
    $script:lastCoverBytes = $media.Cover
    $window.FindName('AlbumCover').Source = $null
    $window.FindName('CoverFallback').Visibility = 'Visible'
    if ($null -ne $media -and $null -ne $media.Cover) {
        $memory = New-Object IO.MemoryStream(,$media.Cover)
        try {
            $bitmap = New-Object Windows.Media.Imaging.BitmapImage
            $bitmap.BeginInit()
            $bitmap.CacheOption = 'OnLoad'
            $bitmap.DecodePixelWidth = 144
            $bitmap.StreamSource = $memory
            $bitmap.EndInit()
            $bitmap.Freeze()
            $window.FindName('AlbumCover').Source = $bitmap
            $window.FindName('CoverFallback').Visibility = 'Collapsed'
            try { $progress.Foreground = Get-CoverAccent $bitmap } catch { $progress.ClearValue([Windows.Controls.Control]::ForegroundProperty) }
        } catch { $window.FindName('AlbumCover').Source = $null }
        finally { $memory.Dispose() }
    }
}

function Update-Media {
    if ($null -ne $script:mediaPending) {
        if (-not $script:mediaPending.IsCompleted) { return }
        try {
            $result = $script:mediaWorker.EndInvoke($script:mediaPending)
            if ($script:mediaWorker.HadErrors) { throw 'Media read failed' }
            if ($script:seeking) {
                if (-not ($result | Select-Object -Last 1).SeekSucceeded) { throw 'Seek failed' }
                $script:mediaTimeline.Position = ($result | Select-Object -Last 1).Position
                $script:mediaTimeline.Updated = ($result | Select-Object -Last 1).Updated
                $window.FindName('SeekStatus').Text = ''
            } elseif ($null -eq $script:queuedSeek) { Set-MediaPanel ($result | Select-Object -Last 1) }
        } catch {
            if ($script:seeking) { $window.FindName('SeekStatus').Text = 'Posisi gagal diubah. Lagu mungkin sudah berganti.' }
            else {
                Set-MediaPanel $null
                $window.FindName('TrackArtist').Text = 'Informasi media belum tersedia'
            }
        } finally {
            $script:mediaWorker.Commands.Clear()
            $script:mediaWorker.Streams.Error.Clear()
            $script:mediaPending = $null
            $script:nextMediaRead = if ($script:seeking -or $null -ne $script:queuedSeek) { [datetime]::MinValue } else { (Get-Date).AddSeconds(2) }
            $script:seeking = $false
        }
    }
    if ((Get-Date) -lt $script:nextMediaRead) { return }
    if ($null -eq $script:mediaWorker) {
        $script:mediaWorker = [PowerShell]::Create()
        $script:mediaWorker.Runspace = [RunspaceFactory]::CreateRunspace()
        $script:mediaWorker.Runspace.Open()
    }
    [void]$script:mediaWorker.AddCommand((Join-Path $PSScriptRoot 'Media.ps1'))
    if ($null -ne $script:queuedSeek) {
        [void]$script:mediaWorker.AddParameters($script:queuedSeek)
        $script:queuedSeek = $null
        $script:seeking = $true
    }
    $script:mediaPending = $script:mediaWorker.BeginInvoke()
}

function Update-CallPanel([IntPtr]$handle) {
    if ($handle -eq $script:callWindow) { return }
    $script:callWindow = $handle
    Clear-Notice
    if ($handle -eq [IntPtr]::Zero) {
        Set-Expanded $false
        return
    }
    $window.FindName('NoticeKind').Text = 'WhatsApp · Jendela panggilan terdeteksi'
    $window.FindName('NoticeTitle').Text = 'Panggilan WhatsApp'
    $window.FindName('NoticeBody').Text = 'Buka WhatsApp untuk melihat atau mengelola panggilan.'
    $window.FindName('OpenWhatsApp').Content = 'Buka panggilan'
    $notice.Visibility = 'Visible'
    $script:noticeUntil = [datetime]::MaxValue
    Set-Expanded $true
}

function Clear-Notice {
    $wasVisible = $notice.Visibility -eq 'Visible'
    $notice.Visibility = 'Collapsed'
    $window.FindName('MusicPanel').Visibility = 'Visible'
    $window.FindName('NoticeTitle').Text = ''
    $window.FindName('NoticeBody').Text = ''
    $window.FindName('OpenWhatsApp').Content = 'Buka WhatsApp'
    $script:noticeUntil = [datetime]::MinValue
    if ($wasVisible -and $script:expanded) { Set-Expanded $true }
}

function Update-Notifications {
    if ((Get-Date) -lt $script:retryNotificationsAt) { return }
    try {
        if (-not $script:notificationReady) {
            . "$PSScriptRoot\Notifications.ps1"
            $script:notificationReady = $true
        }
        if ($null -eq $script:notificationTask) {
            $script:notificationTask = Start-NotificationRead
            return
        }
        if (-not $script:notificationTask.IsCompleted) { return }
        $task = $script:notificationTask
        $script:notificationTask = $null
        if ($task.IsFaulted -or $task.IsCanceled) { throw 'Pembacaan notifikasi gagal.' }
        if ($script:notificationListener.GetAccessStatus().ToString() -ne 'Allowed') { throw 'Izin dicabut.' }
        $current = @{}
        $newest = $null
        foreach ($item in $task.Result) {
            $entry = Convert-WhatsAppNotification $item
            if ($null -eq $entry) { continue }
            $key = '{0}:{1}' -f $entry.Id, $entry.Created.UtcTicks
            $current[$key] = $true
            if (-not $script:seenNotifications.ContainsKey($key) -and $entry.Created -ge $script:notificationStarted) {
                if ($null -eq $newest -or $entry.Created -gt $newest.Created) { $newest = $entry }
            }
        }
        $script:seenNotifications = $current
        $notificationStatus.Text = 'WhatsApp · Notifikasi terhubung'
        if ($null -ne $newest -and $script:callWindow -eq [IntPtr]::Zero) {
            $window.FindName('NoticeKind').Text = if ($newest.IsCall) { 'WhatsApp · Kemungkinan panggilan masuk' } else { 'WhatsApp · Notifikasi baru' }
            $window.FindName('NoticeTitle').Text = $newest.Title
            $window.FindName('NoticeBody').Text = $newest.Body
            $notice.Visibility = 'Visible'
            $script:noticeUntil = (Get-Date).AddSeconds(15)
            Set-Expanded $true
        }
    } catch {
        if ($script:callWindow -eq [IntPtr]::Zero) { Clear-Notice }
        $notificationStatus.Text = 'WhatsApp · Akses notifikasi gagal. Periksa izin Windows.'
        $script:notificationTask = $null
        $script:retryNotificationsAt = (Get-Date).AddSeconds(30)
    }
}

function Set-Expanded([bool]$value) {
    $script:expanded = $value
    $details.IsEnabled = $value
    if (-not $value -and $details.IsKeyboardFocusWithin) { [void]$window.FindName('Toggle').Focus() }
    if ($value) { $details.Visibility = 'Visible' }
    $window.FindName('MusicPanel').Visibility = if ($notice.Visibility -eq 'Visible') { 'Collapsed' } else { 'Visible' }
    Update-TitleScroll
    $height = 48
    if ($value) {
        $details.Measure((New-Object Windows.Size(354, [double]::PositiveInfinity)))
        $height = [math]::Ceiling(48 + $details.DesiredSize.Height)
    }
    $opacity = if ($value) { 1.0 } else { 0.0 }
    if (-not [Windows.SystemParameters]::ClientAreaAnimation) {
        $pill.BeginAnimation([Windows.FrameworkElement]::HeightProperty, $null)
        $details.BeginAnimation([Windows.UIElement]::OpacityProperty, $null)
        $pill.Height = $height
        $details.Opacity = $opacity
        $details.Visibility = if ($value) { 'Visible' } else { 'Collapsed' }
        return
    }
    foreach ($entry in @(
        @($pill, [Windows.FrameworkElement]::HeightProperty, $pill.Height, $height, $(if ($value) { 320 } else { 240 })),
        @($details, [Windows.UIElement]::OpacityProperty, $details.Opacity, $opacity, $(if ($value) { 200 } else { 120 }))
    )) {
        $animation = New-Object Windows.Media.Animation.DoubleAnimation
        $animation.From = $entry[2]
        $animation.To = $entry[3]
        $animation.Duration = [TimeSpan]::FromMilliseconds($entry[4])
        $animation.EasingFunction = New-Object Windows.Media.Animation.CubicEase
        $animation.EasingFunction.EasingMode = if ($value) { 'EaseOut' } else { 'EaseInOut' }
        if (-not $value -and $entry[0] -eq $pill) {
            $animation.Add_Completed({ if (-not $script:expanded) { $details.Visibility = 'Collapsed' } })
        }
        $entry[0].BeginAnimation($entry[1], $animation)
    }
}
function Update-Island {
    $clock.Text = Get-Date -Format 'HH:mm'
    if ((Get-Date) -ge $script:nextBatteryRead) {
        $battery.Text = Get-BatteryLabel
        $script:nextBatteryRead = (Get-Date).AddSeconds(30)
    }
    $area = [Windows.SystemParameters]::WorkArea
    $window.Left = $area.Left + ($area.Width - $window.Width) / 2
    $window.Top = $area.Top + 10
    if ($notice.Visibility -eq 'Visible' -and (Get-Date) -ge $script:noticeUntil) {
        Clear-Notice
        Set-Expanded $false
    }
}

Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class IslandMedia {
    [DllImport("user32.dll")]
    private static extern void keybd_event(byte key, byte scan, uint flags, UIntPtr extra);
    public static void Send(byte key) {
        keybd_event(key, 0, 0, UIntPtr.Zero);
        keybd_event(key, 0, 2, UIntPtr.Zero);
    }
}
'@
$window.FindName('Toggle').Add_Click({ Set-Expanded (-not $script:expanded) })
$window.FindName('CompactNext').Add_Click({ [IslandMedia]::Send(176) })
$window.FindName('CompactPrevious').Add_Click({ [IslandMedia]::Send(177) })
$window.FindName('CompactPlay').Add_Click({ [IslandMedia]::Send(179); $script:nextMediaRead = [datetime]::MinValue })
$window.FindName('OpenWhatsApp').Add_Click({
    try {
        if ($script:callWindow -ne [IntPtr]::Zero) {
            if (-not [WhatsAppCalls]::Open($script:callWindow)) { throw 'Cannot open call window' }
        } else {
            Start-Process explorer.exe -ArgumentList 'shell:AppsFolder\5319275A.WhatsAppDesktop_cv1g1gvanyjgm!App'
            Clear-Notice
        }
        Set-Expanded $false
    }
    catch { $notificationStatus.Text = 'WhatsApp tidak dapat dibuka.' }
})
$window.Add_KeyDown({ if ($_.Key -eq 'Escape') { if ($script:callWindow -eq [IntPtr]::Zero) { Clear-Notice }; Set-Expanded $false } })
$menu = New-Object Windows.Controls.ContextMenu
$topmostItem = New-Object Windows.Controls.MenuItem
$topmostItem.Header = 'Always on top'
$topmostItem.IsCheckable = $true
$topmostBinding = New-Object Windows.Data.Binding('Topmost')
$topmostBinding.Source = $window
$topmostBinding.Mode = [Windows.Data.BindingMode]::TwoWay
[void]$topmostItem.SetBinding([Windows.Controls.MenuItem]::IsCheckedProperty, $topmostBinding)
$topmostItem.Add_Click({
    try { Save-IslandTopmost $settingsPath $topmostItem.IsChecked }
    catch { [void][Windows.MessageBox]::Show($window, 'Pilihan berlaku sekarang, tetapi gagal disimpan. Pastikan folder pengaturan dapat ditulis.', 'Dynamic Island') }
})
[void]$menu.Items.Add($topmostItem)
$statusItem = New-Object Windows.Controls.MenuItem
$statusItem.IsEnabled = $false
$statusBinding = New-Object Windows.Data.Binding('Text')
$statusBinding.Source = $notificationStatus
[void]$statusItem.SetBinding([Windows.Controls.HeaderedItemsControl]::HeaderProperty, $statusBinding)
[void]$menu.Items.Add($statusItem)
$exitItem = New-Object Windows.Controls.MenuItem
$exitItem.Header = 'Keluar Dynamic Island'
$exitItem.Add_Click({ $window.Close() })
[void]$menu.Items.Add($exitItem)
$pill.ContextMenu = $menu
$timer = New-Object Windows.Threading.DispatcherTimer
$timer.Interval = [TimeSpan]::FromSeconds(1)
$timer.Add_Tick({
    try { Update-CallPanel ([WhatsAppCalls]::Find()) }
    catch { $notificationStatus.Text = 'Deteksi jendela panggilan gagal.' }
    Update-Island
    Update-Notifications
    Update-Media
    if ($script:expanded -and $notice.Visibility -ne 'Visible') { Update-Timeline }
    Update-Volume
})
$window.Add_Closed({
    $timer.Stop()
    if ($null -ne $script:mediaWorker) {
        $script:mediaWorker.Stop()
        $script:mediaWorker.Runspace.Dispose()
        $script:mediaWorker.Dispose()
    }
})
Update-Island
if ($SelfTest -or $IntegrationTest) {
    $testSettingsPath = Join-Path $PSScriptRoot ('island-settings-test-' + [guid]::NewGuid() + '.json')
    try {
        if (-not (Read-IslandTopmost $testSettingsPath)) { throw 'Missing settings default failed' }
        foreach ($enabled in @($false, $true, $false)) {
            Save-IslandTopmost $testSettingsPath $enabled
            if ((Read-IslandTopmost $testSettingsPath) -ne $enabled) { throw 'Always on top persistence failed' }
        }
        foreach ($invalid in @('{broken', '{"AlwaysOnTop":"false"}')) {
            [IO.File]::WriteAllText($testSettingsPath, $invalid)
            if (-not (Read-IslandTopmost $testSettingsPath)) { throw 'Invalid settings fallback failed' }
        }
    } finally { if ([IO.File]::Exists($testSettingsPath)) { [IO.File]::Delete($testSettingsPath) } }
    Write-Output 'PASS: always on top persistence, overwrite and invalid settings fallback.'
    if (-not $topmostItem.IsCheckable -or -not $topmostItem.IsChecked -or -not $window.Topmost) { throw 'Always on top default failed' }
    $topmostItem.SetCurrentValue([Windows.Controls.MenuItem]::IsCheckedProperty, $false)
    if ($window.Topmost) { throw 'Always on top disable failed' }
    Set-Expanded $true
    Set-Expanded $false
    if ($window.Topmost -or $topmostItem.IsChecked) { throw 'Expand/collapse reset always on top' }
    $topmostItem.SetCurrentValue([Windows.Controls.MenuItem]::IsCheckedProperty, $true)
    if (-not $window.Topmost) { throw 'Always on top enable failed' }
    Write-Output 'PASS: always on top default, disable, expand/collapse and enable.'
    if (-not $battery.Text -or $clock.Text -notmatch '^\d{2}:\d{2}$') { throw 'Status initialization failed' }
    Set-Expanded $true
    if ($details.Visibility -ne 'Visible') { throw 'Expand failed' }
    if ($details.DesiredSize.Height + 48 -gt 320) { throw 'Music panel is not compact' }
    foreach ($slider in @($progress, $volumeSlider)) {
        [void]$slider.ApplyTemplate()
        $slider.Measure((New-Object Windows.Size(320, 28)))
        $slider.Arrange((New-Object Windows.Rect(0, 0, 320, 28)))
        $track = $slider.Template.FindName('PART_Track', $slider)
        if ($null -eq $track -or $track.Thumb.ActualHeight -lt 24) { throw 'Slider template or hit area failed' }
        if ($track.Maximum -ne $slider.Maximum -or $track.Value -ne $slider.Value) { throw 'Slider track binding failed' }
        if ($track.DecreaseRepeatButton.Command -ne [Windows.Controls.Slider]::DecreaseLarge -or $track.IncreaseRepeatButton.Command -ne [Windows.Controls.Slider]::IncreaseLarge) { throw 'Slider commands failed' }
    }
    Write-Output 'PASS: slider templates, hit areas, range bindings and commands.'
    Set-Expanded $false
    if ($details.IsEnabled) { throw 'Closing panel remains interactive' }
    function Wait-TestAnimation([int]$milliseconds = 400) {
        $frame = New-Object Windows.Threading.DispatcherFrame
        $waitTimer = New-Object Windows.Threading.DispatcherTimer
        $waitTimer.Interval = [TimeSpan]::FromMilliseconds($milliseconds)
        $waitTimer.Add_Tick({ $waitTimer.Stop(); $frame.Continue = $false }.GetNewClosure())
        $waitTimer.Start()
        [Windows.Threading.Dispatcher]::PushFrame($frame)
    }
    Wait-TestAnimation
    if ($details.Visibility -ne 'Collapsed' -or $pill.Height -ne 48 -or $details.Opacity -ne 0) { throw 'Collapse failed' }
    Set-Expanded $true
    Wait-TestAnimation
    $openHeight = $pill.Height
    if ($details.Opacity -ne 1 -or $openHeight -le 48) { throw 'Open animation failed' }
    Set-Expanded $false
    Wait-TestAnimation 80
    $closingHeight = $pill.Height
    if ([Windows.SystemParameters]::ClientAreaAnimation -and ($closingHeight -le 48 -or $closingHeight -ge $openHeight)) { throw 'Missing intermediate animation frame' }
    Set-Expanded $true
    if ([Windows.SystemParameters]::ClientAreaAnimation -and [math]::Abs($pill.Height - $closingHeight) -gt 1) { throw 'Animation jumped on reversal' }
    Wait-TestAnimation
    if ($details.Visibility -ne 'Visible' -or -not $details.IsEnabled -or $pill.Height -ne $openHeight -or $details.Opacity -ne 1) { throw 'Rapid reopen failed' }
    Set-Expanded $false
    Wait-TestAnimation
    Write-Output 'PASS: animated open/close, fade, disabled closing controls and rapid reversal.'
    $scrollMedia = [pscustomobject]@{ Title='A long song title that must scroll completely inside the expanded music panel'; Artist='Test'; Cover=$null }
    Set-MediaPanel $scrollMedia
    Set-Expanded $true
    $viewport = $window.FindName('TitleViewport')
    $viewport.Measure((New-Object Windows.Size(220, 30)))
    $viewport.Arrange((New-Object Windows.Rect(0, 0, 220, 30)))
    Update-TitleScroll
    $titleTransform = $window.FindName('TrackTitle').RenderTransform
    if ([Windows.SystemParameters]::ClientAreaAnimation) {
        if (-not $titleTransform.HasAnimatedProperties) { throw 'Long title did not animate' }
        Wait-TestAnimation 1800
        if ($titleTransform.X -ge 0) { throw 'Long title did not move after initial pause' }
        $scrollPosition = $titleTransform.X
        Set-MediaPanel $scrollMedia
        if ([math]::Abs($titleTransform.X - $scrollPosition) -gt 1) { throw 'Media polling restarted title scroll' }
    }
    Set-Expanded $false
    if ($titleTransform.HasAnimatedProperties -or $titleTransform.X -ne 0) { throw 'Closed panel kept scrolling' }
    Set-MediaPanel ([pscustomobject]@{ Title='Short'; Artist='Test'; Cover=$null })
    Set-Expanded $true
    $viewport.Measure((New-Object Windows.Size(220, 30)))
    $viewport.Arrange((New-Object Windows.Rect(0, 0, 220, 30)))
    Update-TitleScroll
    if ($titleTransform.HasAnimatedProperties) { throw 'Short title should stay still' }
    Set-Expanded $false
    Write-Output 'PASS: long title scroll, polling continuity, close reset and stationary short title.'
    $notice.Visibility = 'Visible'
    $window.FindName('NoticeTitle').Text = 'Test only'
    $script:noticeUntil = (Get-Date).AddSeconds(-1)
    Update-Island
    if ($notice.Visibility -ne 'Collapsed' -or $window.FindName('NoticeTitle').Text) { throw 'Notification expiry failed' }
    if (-not [WhatsAppCalls]::Matches('Voice call', '5319275A.WhatsAppDesktop_cv1g1gvanyjgm')) { throw 'Call match failed' }
    if ([WhatsAppCalls]::Matches('Voice call', 'OtherApp') -or [WhatsAppCalls]::Matches('WhatsApp', '5319275A.WhatsAppDesktop_cv1g1gvanyjgm')) { throw 'Non-call window matched' }
    Update-CallPanel ([IntPtr]123)
    Update-Island
    if ($notice.Visibility -ne 'Visible' -or $script:noticeUntil -ne [datetime]::MaxValue) { throw 'Call panel expired' }
    if ($window.FindName('MusicPanel').Visibility -ne 'Collapsed' -or $details.DesiredSize.Height + 48 -gt 240) { throw 'Call panel layout failed' }
    Set-Expanded $false
    Update-CallPanel ([IntPtr]123)
    if ($script:expanded) { throw 'Same call reopened dismissed panel' }
    Update-CallPanel ([IntPtr]::Zero)
    if ($notice.Visibility -ne 'Collapsed' -or $script:expanded) { throw 'Call panel did not clear' }
    Write-Output 'PASS: call window filter, lifetime, dismissal and closure.'
    $pixels = [byte[]]@(40,100,180,255)
    $testBitmap = [Windows.Media.Imaging.BitmapSource]::Create(1,1,96,96,[Windows.Media.PixelFormats]::Bgra32,$null,$pixels,4)
    $encoder = New-Object Windows.Media.Imaging.PngBitmapEncoder
    $encoder.Frames.Add([Windows.Media.Imaging.BitmapFrame]::Create($testBitmap))
    $testStream = New-Object IO.MemoryStream
    $encoder.Save($testStream)
    Set-MediaPanel ([pscustomobject]@{ Title = 'Test song'; Artist = 'Test artist'; Cover = $testStream.ToArray() })
    $testStream.Dispose()
    if ($null -eq $window.FindName('AlbumCover').Source -or $window.FindName('CoverFallback').Visibility -ne 'Collapsed') { throw 'Valid cover not displayed' }
    $accent = $progress.Foreground
    if ($accent.Color.R -le $accent.Color.G -or $accent.Color.G -le $accent.Color.B -or $accent.Color.B -lt 128) { throw 'Cover accent hue or brightness failed' }
    if ($volumeSlider.Foreground.Color.ToString() -ne '#FFE5E5E9') { throw 'Cover accent leaked to volume' }
    foreach ($rgba in @([byte[]]@(0,0,0,255), [byte[]]@(255,255,255,255), [byte[]]@(255,0,0,0))) {
        $edgeBitmap = [Windows.Media.Imaging.BitmapSource]::Create(1,1,96,96,[Windows.Media.PixelFormats]::Bgra32,$null,$rgba,4)
        $edgeAccent = Get-CoverAccent $edgeBitmap
        if ($edgeAccent.Color.R -lt 128 -or $edgeAccent.Color.R -ne $edgeAccent.Color.G) { throw 'Dark, light or transparent accent failed' }
    }
    $cachedBitmap = $window.FindName('AlbumCover').Source
    $cachedMedia = $script:mediaTimeline
    Set-MediaPanel $cachedMedia
    if (-not [object]::ReferenceEquals($cachedBitmap, $window.FindName('AlbumCover').Source)) { throw 'Unchanged cover was decoded again' }
    if (-not [object]::ReferenceEquals($accent, $progress.Foreground)) { throw 'Unchanged cover accent was recalculated' }
    Set-Expanded $false
    if ($window.FindName('MediaHeader').Visibility -ne 'Visible' -or -not $window.FindName('CompactNext').IsEnabled) { throw 'Compact media unavailable' }
    Set-MediaPanel ([pscustomobject]@{ Title = 'Test song'; Artist = 'Test artist'; Cover = [byte[]]@(0,1,2) })
    if ($window.FindName('TrackTitle').Text -ne 'Test song' -or $null -ne $window.FindName('AlbumCover').Source) { throw 'Invalid cover fallback failed' }
    if ($progress.Foreground.Color.ToString() -ne '#FFE5E5E9') { throw 'Invalid cover accent did not reset' }
    Write-Output 'PASS: cover accent hue, brightness, transparency, cache and neutral fallback.'
    Set-MediaPanel $null
    if ($window.FindName('TrackTitle').Text -ne 'Belum ada media' -or $null -ne $window.FindName('AlbumCover').Source) { throw 'Media reset failed' }
    if ($window.FindName('IdleHeader').Visibility -ne 'Visible' -or $window.FindName('CompactNext').IsEnabled) { throw 'Compact idle reset failed' }
    Write-Output 'PASS: media title, invalid cover fallback and empty session.'
    if ((Format-TrackTime 65) -ne '1:05' -or (Format-TrackTime 3661) -ne '1:01:01') { throw 'Timeline format failed' }
    $sample = [pscustomobject]@{ Title='Timeline test'; Artist='Test'; Source='Test'; Cover=$null; Duration=120; Position=30; Updated=[DateTimeOffset]::Now.AddSeconds(-5); Playing=$false; Rate=1; CanSeek=$true }
    Set-Expanded $true
    Set-MediaPanel $sample
    if ($progress.Value -ne 30 -or $window.FindName('TrackDuration').Text -ne '2:00') { throw 'Paused timeline failed' }
    if ($window.FindName('CompactPlay').Content -ne $window.Resources['PlayIcon'] -or $window.FindName('CompactPlay').ToolTip -ne 'Putar musik') { throw 'Paused playback icon failed' }
    $sample.Playing = $true
    Set-MediaPanel $sample
    if ($window.FindName('CompactPlay').Content -ne $window.Resources['PauseIcon'] -or $window.FindName('CompactPlay').ToolTip -ne 'Jeda musik') { throw 'Playing playback icon failed' }
    if ($progress.Value -lt 35 -or $progress.Value -gt 38) { throw 'Playing timeline failed' }
    Begin-Seek
    $progress.Value = 70
    Update-Timeline
    if ($progress.Value -ne 70) { throw 'Polling overwrote drag' }
    Complete-Seek
    if ($script:queuedSeek.SeekSeconds -ne 70 -or $script:queuedSeek.ExpectedTitle -ne 'Timeline test') { throw 'Seek request failed' }
    $script:queuedSeek = $null
    $sample.Position = 500
    Update-Timeline
    if ($progress.Value -ne 120) { throw 'Timeline clamp failed' }
    Set-MediaPanel $null
    if ($progress.IsEnabled -or $progress.Value -ne 0) { throw 'Missing timeline reset failed' }
    $window.FindName('SeekStatus').Text = ''
    Write-Output 'PASS: timeline duration, pause/play, drag, seek request, clamp and reset.'
    if ([AppVolume]::ProcessName('Spotify.exe') -ne 'Spotify' -or $null -ne [AppVolume]::ProcessName('unknown-app')) { throw 'Volume source matching failed' }
    if ([AppVolume]::ProcessName('Brave') -ne 'brave' -or [AppVolume]::ProcessName('BRAVE') -ne 'brave' -or $null -ne [AppVolume]::ProcessName('Brave.Other')) { throw 'Browser volume source matching failed' }
    foreach ($invalid in @(-1, 101, [double]::NaN, [double]::PositiveInfinity)) {
        $rejected = $false
        try { [AppVolume]::Set('Spotify.exe', $invalid) | Out-Null } catch { $rejected = $true }
        if (-not $rejected) { throw 'Invalid volume accepted' }
    }
    $script:mediaTimeline = [pscustomobject]@{ Source='Spotify.exe' }
    $volumeSlider.IsEnabled = $true
    Begin-VolumeChange
    $volumeSlider.Value = 35
    Update-Volume
    if ($volumeSlider.Value -ne 35 -or $window.FindName('VolumeLabel').Text -ne '35%') { throw 'Volume drag preview failed' }
    $script:mediaTimeline.Source = 'Other.exe'
    Complete-VolumeChange
    if ($window.FindName('VolumeLabel').Text -ne 'Gagal mengubah volume') { throw 'Changed volume source not rejected' }
    $script:mediaTimeline = $null
    Write-Output 'PASS: volume range, source matching, drag and changed-source guard.'
    if ($IntegrationTest) {
        $deadline = (Get-Date).AddSeconds(10)
        do {
            Update-Notifications
            if ($notificationStatus.Text -eq 'WhatsApp · Notifikasi terhubung') { break }
            Start-Sleep -Milliseconds 100
        } while ((Get-Date) -lt $deadline)
        if ($notificationStatus.Text -ne 'WhatsApp · Notifikasi terhubung') { throw $notificationStatus.Text }
        Write-Output 'PASS: UI polling connected to Windows notification API.'
        $deadline = (Get-Date).AddSeconds(15)
        Update-Media
        do {
            Start-Sleep -Milliseconds 100
            Update-Media
        } while ($null -ne $script:mediaPending -and (Get-Date) -lt $deadline)
        if ($null -ne $script:mediaPending -or $window.FindName('TrackArtist').Text -eq 'Informasi media belum tersedia') { throw 'Media background read failed' }
        Write-Output ('PASS: background media reader; cover displayed: ' + ($null -ne $window.FindName('AlbumCover').Source))
        $firstWorker = $script:mediaWorker
        $firstBitmap = $window.FindName('AlbumCover').Source
        $firstToken = $script:mediaTimeline.CoverToken
        $script:nextMediaRead = [datetime]::MinValue
        $deadline = (Get-Date).AddSeconds(15)
        Update-Media
        do { Start-Sleep -Milliseconds 100; Update-Media } while ($null -ne $script:mediaPending -and (Get-Date) -lt $deadline)
        if ($null -ne $script:mediaPending -or -not [object]::ReferenceEquals($firstWorker, $script:mediaWorker)) { throw 'Worker reuse failed' }
        if ($firstToken -and $firstToken -ceq $script:mediaTimeline.CoverToken -and -not [object]::ReferenceEquals($firstBitmap, $window.FindName('AlbumCover').Source)) { throw 'Cover cache failed' }
        Write-Output 'PASS: persistent media worker and unchanged artwork cache.'
    }
    $window.Close()
    Write-Output 'PASS: XAML, battery, clock, expand/collapse and media interop initialization.'
    exit 0
}
$timer.Start()
[void]$window.ShowDialog()
} finally {
    if ($ownsMutex) { $instanceMutex.ReleaseMutex() }
    if ($null -ne $instanceMutex) { $instanceMutex.Dispose() }
}
