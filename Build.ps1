param()
$ErrorActionPreference = 'Stop'
$compiler = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
if (-not (Test-Path -LiteralPath $compiler)) { throw '.NET Framework C# compiler tidak ditemukan.' }
$package = Join-Path $PSScriptRoot 'dist\Dynamic-Island-v1.2.0-win-x64'
[void][IO.Directory]::CreateDirectory($package)
& $compiler /nologo /target:winexe /platform:x64 /optimize+ /reference:System.Windows.Forms.dll "/out:$package\Dynamic Island.exe" "$PSScriptRoot\Launcher.cs"
if ($LASTEXITCODE -ne 0) { throw 'Build launcher gagal.' }
$files = @('Island.ps1', 'Media.ps1', 'Notifications.ps1', 'MediaReader.cs', 'AppVolume.cs', 'WhatsAppCalls.cs', 'Test-Notifications.ps1', 'README.md')
foreach ($file in $files) { Copy-Item -LiteralPath (Join-Path $PSScriptRoot $file) -Destination $package -Force }
$test = Start-Process -FilePath "$package\Dynamic Island.exe" -ArgumentList '--self-test' -WindowStyle Hidden -PassThru -Wait
if ($test.ExitCode -ne 0) { throw 'SelfTest paket EXE gagal.' }
$archive = "$package.zip"
# Package only the allowlisted release files, never local settings or test leftovers.
Compress-Archive -LiteralPath (@("$package\Dynamic Island.exe") + @($files | ForEach-Object { Join-Path $package $_ })) -DestinationPath $archive -Force
$hash = (Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash.ToLowerInvariant()
"$hash  $([IO.Path]::GetFileName($archive))" | Set-Content -LiteralPath "$archive.sha256" -Encoding ASCII
Write-Output "PASS: EXE build and packaged SelfTest. Release: $archive"
