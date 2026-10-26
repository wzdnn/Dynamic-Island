param()
$ErrorActionPreference = 'Stop'
$compiler = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
if (-not (Test-Path -LiteralPath $compiler)) { throw '.NET Framework C# compiler tidak ditemukan.' }
$outputFolder = Join-Path $PSScriptRoot 'dist'
[void][IO.Directory]::CreateDirectory($outputFolder)
$exe = Join-Path $outputFolder 'Dynamic-Island-v1.4.1-win-x64.exe'
$files = @('Island.ps1', 'Media.ps1', 'Notifications.ps1', 'MediaReader.cs', 'AppVolume.cs', 'WhatsAppCalls.cs', 'WebBridge.cs')
$resources = @($files | ForEach-Object { "/resource:$PSScriptRoot\$_,$_" })
$extensionFiles = @('manifest.json', 'page.js', 'content.js', 'background.js', 'popup.html', 'popup.css', 'popup.js', 'README.md')
$resources += @($extensionFiles | ForEach-Object { "/resource:$PSScriptRoot\extension\$_,extension.$_" })
& $compiler /nologo /target:winexe /platform:x64 /optimize+ /reference:System.Windows.Forms.dll /reference:System.Web.Extensions.dll "/out:$exe" @resources "$PSScriptRoot\Launcher.cs" "$PSScriptRoot\WebBridge.cs"
if ($LASTEXITCODE -ne 0) { throw 'Build launcher gagal.' }
& $compiler /nologo /target:exe /platform:x64 /reference:System.Windows.Forms.dll /reference:System.Web.Extensions.dll /main:LauncherTests "/out:$outputFolder\LauncherTests.exe" @resources "$PSScriptRoot\Launcher.cs" "$PSScriptRoot\WebBridge.cs" "$PSScriptRoot\LauncherTests.cs"
if ($LASTEXITCODE -ne 0) { throw 'Build launcher tests gagal.' }
& "$outputFolder\LauncherTests.exe" $outputFolder $exe
if ($LASTEXITCODE -ne 0) { throw 'Launcher tests gagal.' }
node --test "$PSScriptRoot\extension\extension.test.cjs"
if ($LASTEXITCODE -ne 0) { throw 'Extension tests gagal. Node.js diperlukan untuk build/test, bukan untuk menjalankan EXE.' }
$test = Start-Process -FilePath $exe -ArgumentList '--self-test' -WindowStyle Hidden -PassThru -Wait
if ($test.ExitCode -ne 0) { throw 'SelfTest EXE gagal.' }
$hash = (Get-FileHash -LiteralPath $exe -Algorithm SHA256).Hash.ToLowerInvariant()
"$hash  $([IO.Path]::GetFileName($exe))" | Set-Content -LiteralPath "$exe.sha256" -Encoding ASCII
Write-Output "PASS: single-file EXE build, launcher tests and SelfTest. Release: $exe"
