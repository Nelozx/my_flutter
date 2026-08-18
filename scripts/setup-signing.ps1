# scripts/setup-signing.ps1
# Run this ONCE on your Windows machine to generate the release signing keystore.
# Usage:  powershell -ExecutionPolicy Bypass -File scripts\setup-signing.ps1

$ErrorActionPreference = "Stop"
$ProjectDir = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
Set-Location $ProjectDir

Write-Host "=== Flutter Android signing setup ===" -ForegroundColor Cyan
Write-Host "Generates a release keystore locally. It will NOT be committed."
Write-Host ""

function Read-MaskedPassword($Prompt) {
    $sec = Read-Host -Prompt $Prompt -AsSecureString
    $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec)
    try {
        [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
    } finally {
        [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
    }
}

$StorePass = Read-MaskedPassword "Enter a keystore password"
$KeyPass   = Read-MaskedPassword "Enter a key password (can be same)"
$KeyAlias  = Read-Host -Prompt "Key alias [upload]"
if ([string]::IsNullOrWhiteSpace($KeyAlias)) { $KeyAlias = "upload" }

# Locate keytool: PATH first, then Android Studio's bundled JDK (JBR)
$Keytool = Get-Command keytool.exe -ErrorAction SilentlyContinue
if (-not $Keytool) {
    $candidates = @(
        "$env:ProgramFiles\Android\Android Studio\jbr\bin\keytool.exe",
        "$env:LOCALAPPDATA\Programs\Android Studio\jbr\bin\keytool.exe",
        "$env:ProgramFiles\Java\*\bin\keytool.exe"
    )
    foreach ($c in $candidates) {
        $found = Resolve-Path $c -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($found) { $Keytool = @{ Source = $found.Path }; break }
    }
}
if (-not $Keytool) {
    Write-Host "ERROR: keytool.exe not found." -ForegroundColor Red
    Write-Host "Install Android Studio (it bundles a JDK) or add a JDK to PATH, then rerun."
    exit 1
}
$KeytoolExe = $Keytool.Source
Write-Host ""
Write-Host "Using keytool: $KeytoolExe"

$KeystoreDir = Join-Path $ProjectDir "android\app"
New-Item -ItemType Directory -Force -Path $KeystoreDir | Out-Null
$Keystore = Join-Path $KeystoreDir "upload-keystore.jks"

Write-Host "Generating keystore..."
& $KeytoolExe -genkey -v `
    -keystore $Keystore `
    -keyalg RSA -keysize 2048 -validity 10000 `
    -alias $KeyAlias `
    -storepass $StorePass -keypass $KeyPass `
    -dname "CN=Flutter App, OU=Dev, O=Example, L=Shenzhen, ST=Guangdong, C=CN"
if ($LASTEXITCODE -ne 0) { Write-Host "keytool failed." -ForegroundColor Red; exit 1 }

# Write key.properties (read by build.gradle.kts, gitignored)
$KeyProps = "storePassword=$StorePass`nkeyPassword=$KeyPass`nkeyAlias=$KeyAlias`nstoreFile=upload-keystore.jks"
[IO.File]::WriteAllText((Join-Path $ProjectDir "android\key.properties"), $KeyProps)

Write-Host ""
Write-Host "=== Done. Files created (gitignored): ===" -ForegroundColor Green
Write-Host "  android\app\upload-keystore.jks"
Write-Host "  android\key.properties"
Write-Host ""
Write-Host "=== Verify a release build signs correctly: ==="
Write-Host "  flutter build apk --release"
Write-Host ""
Write-Host "=== GitHub Secrets (repo > Settings > Secrets and variables > Actions): ==="
Write-Host "  ANDROID_KEYSTORE_PASSWORD = <the keystore password you entered>"
Write-Host "  ANDROID_KEY_PASSWORD      = <the key password you entered>"
Write-Host "  ANDROID_KEY_ALIAS         = $KeyAlias"
Write-Host ""

# Base64 of keystore, single line, copied to clipboard
$Base64 = [Convert]::ToBase64String([IO.File]::ReadAllBytes($Keystore))
try {
    Set-Clipboard -Value $Base64
    Write-Host "  ANDROID_KEYSTORE_BASE64  = <already COPIED to your clipboard - paste it into GitHub>" -ForegroundColor Yellow
} catch {
    Write-Host "  ANDROID_KEYSTORE_BASE64  = (copy the base64 below)" -ForegroundColor Yellow
    Write-Host $Base64
}
Write-Host ""
Write-Host "Next: create a Google Play service account JSON for PLAY_SERVICE_ACCOUNT_JSON"
Write-Host "(only needed when you want auto-upload to Play Store on tags)."
