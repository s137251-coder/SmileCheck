$ErrorActionPreference = 'Stop'

$flutterBin = 'C:\src\flutter\bin'
if (-not (($env:Path -split ';') -contains $flutterBin)) {
  $env:Path = "$flutterBin;$env:Path"
}

$androidSdk = "$env:LOCALAPPDATA\Android\Sdk"
Write-Host "Android SDK root: $androidSdk"
New-Item -ItemType Directory -Force -Path $androidSdk | Out-Null

$cmdToolsRoot = Join-Path $androidSdk 'cmdline-tools'
$cmdToolsLatest = Join-Path $cmdToolsRoot 'latest'
$cmdmanager = Join-Path $cmdToolsLatest 'bin\sdkmanager.bat'
$cmdZip = Join-Path $env:TEMP 'cmdline-tools.zip'

if (-not (Test-Path $cmdmanager)) {
    if (Test-Path $cmdToolsRoot) { Remove-Item $cmdToolsRoot -Recurse -Force -ErrorAction SilentlyContinue }
    Invoke-WebRequest -Uri 'https://dl.google.com/android/repository/commandlinetools-win-11076708_latest.zip' -OutFile $cmdZip -UseBasicParsing
    Expand-Archive -Path $cmdZip -DestinationPath $androidSdk -Force
    New-Item -ItemType Directory -Force -Path $cmdToolsLatest | Out-Null
    $extracted = Join-Path $androidSdk 'cmdline-tools'
    $items = Get-ChildItem $extracted -Force
    foreach ($item in $items) {
        Copy-Item $item.FullName $cmdToolsLatest -Recurse -Force
    }
}

if (-not (Test-Path $cmdmanager)) {
    throw "sdkmanager not found at $cmdmanager"
}

$env:ANDROID_HOME = $androidSdk
$env:ANDROID_SDK_ROOT = $androidSdk
$env:Path = "$androidSdk\platform-tools;$androidSdk\cmdline-tools\latest\bin;$env:Path"

Write-Host "Using sdkmanager: $cmdmanager"
& $cmdmanager --sdk_root="$androidSdk" --list | Select-Object -First 20 | Write-Host

Write-Host 'Installing required Android packages...'
& $cmdmanager --sdk_root="$androidSdk" 'platform-tools' 'platforms;android-34' 'build-tools;34.0.0' 'cmdline-tools;latest'

Write-Host 'Configuring Flutter SDK path...'
flutter config --android-sdk "$androidSdk"
Write-Host 'Running Flutter doctor...'
flutter doctor -v
