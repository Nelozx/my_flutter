# my_flutter_app

Flutter 项目，已内置 Android CI/CD（GitHub Actions）。开箱即用：质量门、签名构建、产物分发全自动。

## 项目结构（CI/CD 相关）

```
my_flutter_app/
├── .github/workflows/cicd.yml   # GitHub Actions 流水线
├── .gitignore                   # 已排除签名密钥
├── android/
│   ├── app/
│   │   └── build.gradle.kts      # 已配置 release 签名（读取 key.properties）
│   └── key.properties            # 本地生成，不入库
├── scripts/
│   └── setup-signing.sh          # 本地一键生成 keystore
└── lib/main.dart
```

## 一次性配置（约 5 分钟）

### 1. 本地生成签名密钥

Windows（PowerShell，推荐）：
```powershell
cd my_flutter_app
powershell -ExecutionPolicy Bypass -File scripts\setup-signing.ps1
```

macOS / Linux / Git Bash：
```bash
bash scripts/setup-signing.sh
```

按提示输入密码。脚本会：
- 生成 `android/app/upload-keystore.jks` 和 `android/key.properties`（都已 gitignore）
- 打印 4 个值，用于下一步填 GitHub Secrets（PowerShell 版会把 base64 直接复制到剪贴板）

验证本地能出 release 包：
```bash
flutter build apk --release   # 应显示 "Signed" 而非 debug 签名
```

### 2. 配置 GitHub Secrets

仓库 → Settings → Secrets and variables → Actions → New repository secret，添加：

| Secret 名 | 值 |
|-----------|-----|
| `ANDROID_KEYSTORE_BASE64` | 脚本打印的 base64 串 |
| `ANDROID_KEYSTORE_PASSWORD` | keystore 密码 |
| `ANDROID_KEY_PASSWORD` | key 密码 |
| `ANDROID_KEY_ALIAS` | `upload` |

### 3.（可选）接入 Play Store 自动上传

仅在打 tag 自动上架 Play Store 时需要：
1. Google Play Console → 设置 → API 权限 → 创建服务账号 → 下载 JSON
2. 添加 Secret `PLAY_SERVICE_ACCOUNT_JSON`，值为整个 JSON 文件内容

不需要的话，删掉 `cicd.yml` 末尾的 `Upload to Play Console` 步骤即可，用 artifact 下载做内测。

## 流水线触发规则

| 触发 | 跑什么 |
|------|--------|
| 提 PR 到 main | analyze + test（ubuntu 秒级，不花钱） |
| push 到 main | + 构建 APK/AAB，artifact 可下载 |
| 打 tag `v1.0.0` | + 自动上传 Play Console 内测轨道 |

## 日常使用

```bash
# 开发
flutter run

# 本地出 release 包（用本地 keystore 签名）
flutter build apk --release --split-per-abi

# 发布：打 tag 触发 CI 构建 + 上传
git tag v1.0.0
git push origin v1.0.0
```

## 修改 applicationId / 包名

默认 `com.example.my_flutter_app`。改包名需同步改：
- `android/app/build.gradle.kts` 的 `namespace` 和 `applicationId`
- `android/app/src/main/AndroidManifest.xml`（如用到）
- `android/app/src/main/kotlin/.../MainActivity.kt` 的目录结构
