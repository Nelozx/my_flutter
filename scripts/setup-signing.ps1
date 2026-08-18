# scripts/setup-signing.ps1
# 在你的 Windows 机器上运行一次，生成发布签名 keystore。
# 用法：  powershell -ExecutionPolicy Bypass -File scripts\setup-signing.ps1

$ErrorActionPreference = "Stop"
$ProjectDir = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
Set-Location $ProjectDir

Write-Host "=== Flutter Android 签名配置 ===" -ForegroundColor Cyan
Write-Host "将在本地生成发布签名密钥，不会提交到 git 仓库。"
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

$StorePass = Read-MaskedPassword "请输入 keystore 密码"
$KeyPass   = Read-MaskedPassword "请输入 key 密码（可与上面相同）"
$KeyAlias  = Read-Host -Prompt "key 别名 [upload]"
if ([string]::IsNullOrWhiteSpace($KeyAlias)) { $KeyAlias = "upload" }

# 定位 keytool：先查 PATH，再找 Android Studio 自带 JDK（JBR）
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
    Write-Host "错误：找不到 keytool.exe" -ForegroundColor Red
    Write-Host "请安装 Android Studio（自带 JDK），或把 JDK 加入 PATH 后重试。"
    exit 1
}
$KeytoolExe = $Keytool.Source
Write-Host ""
Write-Host "使用的 keytool：$KeytoolExe"

$KeystoreDir = Join-Path $ProjectDir "android\app"
New-Item -ItemType Directory -Force -Path $KeystoreDir | Out-Null
$Keystore = Join-Path $KeystoreDir "upload-keystore.jks"

Write-Host "正在生成 keystore..."
& $KeytoolExe -genkey -v `
    -keystore $Keystore `
    -keyalg RSA -keysize 2048 -validity 10000 `
    -alias $KeyAlias `
    -storepass $StorePass -keypass $KeyPass `
    -dname "CN=Flutter App, OU=Dev, O=Example, L=Shenzhen, ST=Guangdong, C=CN"
if ($LASTEXITCODE -ne 0) { Write-Host "keytool 执行失败。" -ForegroundColor Red; exit 1 }

# 写入 key.properties（供 build.gradle.kts 读取，已被 gitignore）
$KeyProps = "storePassword=$StorePass`nkeyPassword=$KeyPass`nkeyAlias=$KeyAlias`nstoreFile=upload-keystore.jks"
[IO.File]::WriteAllText((Join-Path $ProjectDir "android\key.properties"), $KeyProps)

Write-Host ""
Write-Host "=== 完成！已生成文件（均已 gitignore，不会入库）：===" -ForegroundColor Green
Write-Host "  android\app\upload-keystore.jks"
Write-Host "  android\key.properties"
Write-Host ""
Write-Host "=== 验证 release 签名构建：==="
Write-Host "  flutter build apk --release"
Write-Host ""
Write-Host "=== GitHub Secrets（仓库 > Settings > Secrets and variables > Actions）：==="
Write-Host "  ANDROID_KEYSTORE_PASSWORD = <你刚输入的 keystore 密码>"
Write-Host "  ANDROID_KEY_PASSWORD      = <你刚输入的 key 密码>"
Write-Host "  ANDROID_KEY_ALIAS         = $KeyAlias"
Write-Host ""

# keystore 转单行 base64，直接复制到剪贴板
$Base64 = [Convert]::ToBase64String([IO.File]::ReadAllBytes($Keystore))
try {
    Set-Clipboard -Value $Base64
    Write-Host "  ANDROID_KEYSTORE_BASE64  = <已复制到剪贴板，去 GitHub 直接粘贴即可>" -ForegroundColor Yellow
} catch {
    Write-Host "  ANDROID_KEYSTORE_BASE64  = （复制下面这段 base64）" -ForegroundColor Yellow
    Write-Host $Base64
}
Write-Host ""
Write-Host "下一步：如需打 tag 自动上传 Play Store，"
Write-Host "再创建 Google Play 服务账号 JSON 并填入 PLAY_SERVICE_ACCOUNT_JSON 即可。"
