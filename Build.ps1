param()
$ErrorActionPreference = 'Stop'
$compiler = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
if (-not (Test-Path -LiteralPath $compiler)) { throw '.NET Framework C# compiler tidak ditemukan.' }
$outputFolder = Join-Path $PSScriptRoot 'dist'
[void][IO.Directory]::CreateDirectory($outputFolder)
$exe = Join-Path $outputFolder 'Dynamic-Island-v1.3.0-win-x64.exe'
$files = @('Island.ps1', 'Media.ps1', 'Notifications.ps1', 'MediaReader.cs', 'AppVolume.cs', 'WhatsAppCalls.cs')
$resources = @($files | ForEach-Object { "/resource:$PSScriptRoot\$_,$_" })
& $compiler /nologo /target:winexe /platform:x64 /optimize+ /reference:System.Windows.Forms.dll "/out:$exe" @resources "$PSScriptRoot\Launcher.cs"
if ($LASTEXITCODE -ne 0) { throw 'Build launcher gagal.' }
& $compiler /nologo /target:exe /platform:x64 /reference:System.Windows.Forms.dll /main:LauncherTests "/out:$outputFolder\LauncherTests.exe" @resources "$PSScriptRoot\Launcher.cs" "$PSScriptRoot\LauncherTests.cs"
if ($LASTEXITCODE -ne 0) { throw 'Build launcher tests gagal.' }
& "$outputFolder\LauncherTests.exe" $outputFolder
if ($LASTEXITCODE -ne 0) { throw 'Launcher tests gagal.' }
$test = Start-Process -FilePath $exe -ArgumentList '--self-test' -WindowStyle Hidden -PassThru -Wait
if ($test.ExitCode -ne 0) { throw 'SelfTest EXE gagal.' }
$hash = (Get-FileHash -LiteralPath $exe -Algorithm SHA256).Hash.ToLowerInvariant()
"$hash  $([IO.Path]::GetFileName($exe))" | Set-Content -LiteralPath "$exe.sha256" -Encoding ASCII
Write-Output "PASS: single-file EXE build, launcher tests and SelfTest. Release: $exe"
