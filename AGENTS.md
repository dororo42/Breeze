# Breeze — Agent 开发指南

> 本文档面向 AI 编程助手。若你第一次接触本项目，请先阅读本文件再修改代码。项目的主要注释、文档与发布日志均为中文，因此本文档也使用中文撰写。

---

## 1. 项目概述

**Breeze**（包名 `zephyr`）是一个使用 Flutter 开发的跨平台漫画阅读应用，支持第三方图源插件。当前主要支持：

- **Android**（APK 分发）
- **iOS / iPadOS**（未签名 IPA，需侧载）
- **Windows**（Tauri 安装器）
- **macOS**（DMG / Homebrew Cask）
- **Linux**（Flatpak）

### 1.1 核心定位

- 应用本身不包含具体漫画内容，漫画数据通过**插件**获取。
- 插件运行在技术栈 `Dart → Flutter Rust Bridge → Rust → QuickJS` 的 Rust 侧运行时中。
- 默认内置插件（Bika、禁漫等）在 `rust/build.rs` 编译时从 CDN 下载并打包进二进制。

### 1.2 主要仓库

- **Dart/Flutter 应用**：`lib/`
- **Rust FFI 库**：`rust/`（crate 名 `windcore`）
- **QuickJS 运行时封装**：`rust/rquickjs_playground/`（独立子 crate，可整体抽离）
- **Windows 安装器前端**：`windows-installer/`（SvelteKit + Tauri v2）
- **构建/发布脚本**：`script/`
- **CI/CD**：`.github/workflows/`

---

## 2. 技术栈

### 2.1 Flutter / Dart

- **Flutter 版本**：`3.47.5`（通过 `.fvmrc` 与 `.puro.json` 锁定，建议使用 FVM / Puro；对应 Dart `3.13.4`）
- **Dart SDK**：`^3.12.0`（`pubspec.yaml` 约束；`.fvmrc` 锁定的 Flutter 3.47.5 自带 3.13.4）
- **应用包名**：`zephyr`

### 2.2 Rust

- **主库 crate**：`rust/` 下的 `windcore`
- **Rust edition**：2024
- **Flutter Rust Bridge**：`2.12.0`（Rust 侧通过 `=2.12.0` 精确锁定）
- **rquickjs**：`0.11.0`，用于执行 JS 插件

### 2.3 状态管理与路由

- **状态管理**：`flutter_bloc` + `bloc` + `bloc_concurrency`
  - 复杂业务使用 `Bloc`（事件驱动）
  - 轻量/局部状态使用 `Cubit`
- **路由**：`auto_route`，页面使用 `@RoutePage()` 注解

### 2.4 数据持久化与网络

- **本地数据库**：`objectbox` + `objectbox_flutter_libs`
- **HTTP 客户端**：Rust `reqwest`（经 FRB 暴露为 `HttpClient` / Dart `WindHttp`）
- **图片加载/缓存**：`photo_view`
- **后台下载**：自研下载队列（`lib/service/download/`）
- **WebDAV / S3 同步**：Rust 侧 `reqwest_dav`、Dart 侧 `minio`

### 2.5 监控与异常上报

- **Sentry**：`sentry_flutter`，崩溃、性能剖析、会话回放
- 通过 `sentry_dsn` dart-define 在 Release 构建中启用

---

## 3. 仓库结构

```text
.
├── lib/                        # Dart/Flutter 主代码
│   ├── main.dart               # 应用入口
│   ├── config/                 # 全局与业务配置（GlobalSetting、Bika/JM 设置等）
│   ├── cubit/                  # 全局轻量 Cubit
│   ├── debug/                  # 调试页面
│   ├── i18n/                   # slang 生成的翻译与 `t` 入口
│   ├── network/                # 网络层、插件调用、WebDAV/S3 同步
│   ├── object_box/             # ObjectBox 实体与生成文件
│   ├── page/                   # 页面/Feature 集合（最大模块）
│   ├── platform/               # 平台能力封装
│   ├── plugin/                 # 插件注册与服务
│   ├── service/                # 跨页面服务（下载队列、书架关注、启动快照等）
│   ├── src/rust/               # FRB 生成的 FFI 绑定
│   ├── type/                   # 通用枚举与类型工具
│   ├── util/                   # 工具类、路由、桌面端适配等
│   └── widgets/                # 通用 UI 组件
├── rust/                       # Rust FFI 主库（windcore）
│   ├── src/api/                # 暴露给 Dart 的 API
│   ├── src/compressed/         # 压缩/打包（tar/zip/brotli/zstd）
│   ├── src/decode/             # 禁漫图片反混淆
│   ├── src/memory/             # 内存统计
│   ├── src/qjs/                # QuickJS runtime 管理
│   ├── build.rs                # 编译时下载内置插件 bundle
│   ├── Cargo.toml
│   └── rquickjs_playground/    # QuickJS 宿主运行时封装 crate（独立子 crate）
├── windows-installer/          # Windows 安装器（SvelteKit + Tauri v2）
├── script/                     # 构建与代码生成脚本
│   ├── android_build_utils.py
│   ├── build_apk.dart
│   ├── build_linux_flatpak.dart
│   ├── build_ncnn_android.py
│   ├── build_ncnn_static_android.py
│   ├── build_waifu2x_cli_android.py
│   ├── build_windows.dart
│   ├── code_generate.dart
│   ├── download_android_ncnn_deps.dart
│   └── prepare_android_waifu2x_deps.py
├── hook/build.dart             # Dart Native Asset 构建钩子
├── flatpak/                    # Linux Flatpak 配置
├── android/                    # Android 工程
├── ios/ / macos/ / linux/ / windows/  # 各平台原生工程
├── .github/workflows/          # CI/CD
├── asset/                      # 字体、图片、内置资源
│   └── coreml_models/          # iOS/macOS CoreML 超分模型（随包分发）
├── test/                       # 测试（当前仅有一个注释掉的 widget_test.dart）
├── integration_test/             # 集成测试（如 Android RealSR / CoreML 超分端到端验证）
└── plugin-dev-docs/            # 插件开发文档（VitePress 站点）
```

### 3.1 典型 Feature 目录结构

`lib/page/` 下每个模块通常按职责分层：

```text
page/comic_info/
├── comic_info.dart           # barrel 文件
├── bloc/                     # BLoC（event/state）
├── cubit/                    # 可选 Cubit
├── method/                   # 业务方法
├── models/                   # 页面内模型
├── json/normal/              # JSON 数据类与反序列化
├── view/                     # 页面主体 Widget
└── widgets/                  # 页面私有组件
```

### 3.2 生成文件位置

以下文件由工具生成，**请勿手动修改**：

- **ObjectBox**：`lib/object_box/model.g.dart`、`lib/object_box/objectbox.g.dart`
- **flutter_rust_bridge**：`lib/src/rust/frb_generated*.dart`、`rust/src/frb_generated.rs`
- **auto_route**：`lib/util/router/router.gr.dart`
- **freezed / json_serializable**：各目录下的 `*.freezed.dart`、`*.g.dart`

---

## 4. 环境准备

### 4.1 必需工具链

- **Flutter SDK**：以仓库根目录 `.fvmrc` 为准（当前 `3.47.5`；推荐通过 FVM / Puro 安装）
- **Rust Toolchain**：通过 `rustup` 安装，并添加目标平台 target
- **LLVM / Clang**：`rustqjs` 等库需要解析 C 头，Windows 推荐 `choco install llvm`
- **Java 21**：Android / Windows / Linux 编译必需
- **Android SDK / NDK**：NDK 版本见 `android/app/build.gradle.kts` 中的 `ndkVersion`

### 4.2 推荐环境变量

| 变量名 | 说明 | 示例 |
|--------|------|------|
| `JAVA_HOME` | 编译 Android / Windows / Linux 必需 | `C:\Program Files\Android\Android Studio\jbr` |
| `ANDROID_NDK_HOME` | Rust 交叉编译 Android 库必需 | `...\Android\Sdk\ndk\29.0.14206865` |
| `LIBCLANG_PATH` | 供 `bindgen` 生成 FFI 绑定使用 | `C:\Program Files\LLVM\bin` |

确保 `PATH` 中包含 `javac` 与 `clang`。

#### Android native assets 构建的环境前提（2026-09 实测）

`windcore` 由 Dart native assets（`hook/build.dart` + `native_toolchain_rust`）编译，不经 Gradle，因此有以下三条硬要求：

1. **NDK 路径只能靠环境变量发现**。`hook/build.dart` 的 `_findNdkPath` 依次读 `ANDROID_NDK_HOME` → `ANDROID_SDK_ROOT` / `ANDROID_HOME` → Windows `LOCALAPPDATA` → `$HOME/Android/Sdk`，**不读 `android/local.properties` 的 `sdk.dir`**。SDK 不在默认位置时必须导出，例如：
   `ANDROID_HOME=$HOME/android-sdk ANDROID_NDK_HOME=$HOME/android-sdk/ndk/29.0.14206865`
   否则报 `Cannot find Android NDK`，且因为它发生在 `Target build_hooks failed` 里，Gradle 侧只会看到 `compileFlutterBuildDebug` 失败。
2. **这些变量必须进入 Gradle daemon**。Flutter 的 native assets 步骤是 Gradle 任务 `:app:compileFlutterBuildDebug` 拉起的子进程，daemon 常驻后会沿用启动时的环境。改完环境变量要先 `cd android && ./gradlew --stop`，否则新变量不生效（表现为同样含糊的 `Building native assets failed`）。
3. **`rust-toolchain.toml` 会触发全量 target 下载**。`native_toolchain_rust` 以空环境调用 `rustup show active-toolchain`，`RUSTUP_TOOLCHAIN` 被忽略；该文件写的是 `profile = "default"` 且列了 Android / iOS / Windows / macOS / Linux 共 12 个 target，所以 rustup 会尝试补齐所有 `rust-std`。若此前只装过 `--profile minimal`，补装可能撞上残留文件并报
   `error: failed to install component: 'rust-std-<target>', detected conflict: 'lib/rustlib/<target>/lib/libaddr2line-*.rlib'`
   —— 此时应 `rustup toolchain uninstall 1.96.1` 后在 `rust/` 目录内重新触发一次干净的 `rustup toolchain install 1.96.1`，而不是手工删文件。

另外：`~/.gradle/gradle.properties` 里的 `systemProp.http(s).proxyHost` 必须是 **HTTP 代理**。把 SOCKS 端口（例如常见的 `16492`）按 HTTP 代理填进去时，Gradle 的报错是误导性的
`The server may not support the client's requested TLS protocol versions … Remote host terminated the handshake`；
JVM 侧走 SOCKS 应改用 `systemProp.socksProxyHost` / `socksProxyPort`，或在本机用 `gost -L http://:18081 -F socks5h://<host>:<port>` 转成 HTTP 代理（远端解析必须用 `socks5h`，否则 `dl.google.com` 一类域名会 CONNECT 成功但 TLS 失败）。

### 4.3 依赖初始化

```bash
# 根项目 Flutter 依赖
flutter pub get

# 桥接层依赖（如存在 rust_builder 目录）
cd rust_builder
flutter pub get
```

### 4.4 Windows 下调试终端调用 Flutter / Dart（建议优先尝试）

项目使用 **Puro** 管理 Flutter SDK（`.puro.json` 锁定环境）。在 MSYS2 / Git Bash 等类 Unix Shell 中直接执行 `flutter` 或 `dart` 时，这两个脚本会调用 Windows 原生可执行文件 `puro.exe`，有时会因为路径/兼容层问题失败。

> 因此，**建议优先尝试**通过 `puro` 命令间接调用：

```bash
# 优先尝试
puro flutter --version
puro dart --version

# 示例
puro flutter pub get
puro dart ./script/code_generate.dart
```

如果当前 Shell 的 `PATH` 中没有 `puro`，可使用其绝对路径（以本机默认安装位置为例）：

```bash
/c/Users/windy/.puro/bin/puro flutter pub get
/c/Users/windy/.puro/bin/puro dart ./script/code_generate.dart
```

> 这并非强制要求。若你的终端/IDE 已能直接调用 `flutter`/`dart`，或 `cmd.exe` / PowerShell 下工作正常，继续使用原有方式即可。只有在直接调用失败时，再切换到 `puro flutter` / `puro dart`。

---

## 5. 构建与运行

### 5.1 代码生成

修改涉及 `auto_route`、`freezed`、`json_serializable`、`objectbox`、FRB 的代码后，必须重新生成：

```bash
# 方式 1：使用项目脚本（推荐）
dart ./script/code_generate.dart

# 方式 2：手动执行
flutter pub run build_runner build --delete-conflicting-outputs
flutter_rust_bridge_codegen generate
dart format ./lib/
cargo fmt
```

### 5.2 本地运行

```bash
# 调试运行
flutter run

# 带 Sentry DSN 运行
flutter run --dart-define=sentry_dsn=YOUR_DSN
```

### 5.3 平台构建

项目提供 Dart 脚本统一处理构建：

| 平台 | 构建命令/脚本 | 产物 |
|------|---------------|------|
| Android | `dart ./script/build_apk.dart` | `build/app/outputs/flutter-apk/*.apk` |
| Linux | `dart ./script/build_linux_flatpak.dart` | `breeze.flatpak` |
| Windows | `dart ./script/build_windows.dart` | `windows-installer.exe` |
| macOS | `flutter build macos --release` + `create-dmg` | `Breeze-macOS.dmg` |
| iOS | `flutter build ios --release --no-codesign` + 打包 | `Breeze-iOS.ipa` |

`build_apk.dart` 无参数时默认构建 Release 并分 ABI；带任意参数时进入快速 Debug 构建（`--debug --target-platform=android-arm64,android-x64`）。

iOS 模拟器（`aarch64-apple-ios-sim`）构建时，`rquickjs-sys` 的 bindgen 会把 Rust target triple 直接传给 clang，但 clang 不识别 `-sim` 后缀。`hook/build.dart` 已针对该目标自动注入 `BINDGEN_EXTRA_CLANG_ARGS=--target=aarch64-apple-ios-simulator` 以绕过此问题。

Windows 安装器打包（`script/build_windows.dart`）会下载 7-Zip 的独立控制台版本 `7zr.exe`（约 590 KB）到 `script/bin/`，并用它将 Flutter Release 目录压缩为 `Release.7z`。Rust 安装器侧通过 `sevenz-rust2` crate 解压。该方案避免了 `package:archive` 生成的不规范 tar 头以及 GNU tar 在 Windows 上的 POSIX 兼容层路径问题。

RealSR 桌面端模型不再打包进安装包，首次使用需在设置页下载。模型下载后解压到 `getFilePath()/super_resolution/`，由 `RealSrSuperResolution` 自动调用。Linux / macOS 下载完成后会自动执行 `chmod +x` 授权。

Android 端已彻底从 JNI + ncnn 共享库方案切换到 **waifu2x CLI** 方案：APK 中以 native library 形式打包静态链接 ncnn / Vulkan / OpenCV / libwebp 的 `libwaifu2x_cli.so`；Dart 层通过 MethodChannel 获取它在 `nativeLibraryDir` 中的路径，直接通过 `Process.run` 调用。模型仍在首次使用时从 `https://github.com/deretame/breeze-binary/raw/main/realsr-android.7z` 下载并解压到 `getFilePath()/super_resolution/`。

相关脚本（默认仅 `arm64-v8a`）：

- 准备 OpenCV / libwebp 依赖：`python script/prepare_android_waifu2x_deps.py`
- 编译 ncnn 静态库：`python script/build_ncnn_static_android.py`（关闭 OpenMP，启用 Vulkan）
- 编译 waifu2x CLI：`python script/build_waifu2x_cli_android.py`（输出 `android/app/src/main/jniLibs/arm64-v8a/libwaifu2x_cli.so`；若 `third_party/RealSR-NCNN-Android` 不存在，脚本会自动从上游仓库克隆）

旧版 ncnn 共享库脚本 `script/build_ncnn_android.py` 与 `script/download_android_ncnn_deps.dart` 仍保留，但 CLI 方案已不再需要它们。

#### Android native 重定位约束（重要）

`libwindcore.so` 由 Dart native assets（`hook/build.dart` + `native_toolchain_rust`）交叉编译，**不经过 Gradle**。NDK r29 的 lld 默认输出 `DT_RELR` 压缩相对重定位，而 Android 10 以下的 linker 不认识该 tag，会**整表跳过**：`.init_array` / `.got` 保持未重定位的链接期地址，`MainActivity` 的 `System.loadLibrary("windcore")` 一执行就 SIGSEGV，表现为「安装成功但应用秒退」。

因此：

- `rust/build.rs` 对 android target 强制 `-Wl,--pack-dyn-relocs=android`（Android 传统压缩重定位，API 23+ 支持），请勿删除。
- 两个 Android 构建 job 在 `build_apk.dart` 之后运行 `python3 script/check_android_native_relocs.py build/app/outputs/flutter-apk/*.apk` 校验产物。
- 升级 NDK、更换链接参数或改用其它 Rust 构建方式后，必须重跑上述校验；在 Android 8.x/9 设备（如 Likebook T80D）上做一次冷启动回归。

### 5.4 调试代理

开发模式下应用会读取 `.env.proxy` 资源文件中的 `proxy=` 配置，自动探测并设置 HTTP 代理，方便调试网络请求。

---

## 6. 代码风格与约定

### 6.1 换行与编码

- 使用 `.editorconfig`：UTF-8、LF 换行、文件末尾保留空行、去除行尾空格。
- `.gitattributes` 会将文本文件规范化为 LF；Windows 批处理文件（`*.bat`、`*.cmd`）保持 CRLF。
- Git `pre-commit` 钩子会自动对暂存文件执行 `git add --renormalize`，仅包含换行符噪音的提交会被阻止。

### 6.2 Dart 规范

- `analysis_options.yaml` 继承 `package:flutter_lints/flutter.yaml`。
- `invalid_annotation_target` 错误级别设为 `ignore`，避免代码生成注解的误报。
- `build.yaml` 配置 `json_serializable` 的 `explicit_to_json: true`。

### 6.3 命名与组织

- Dart 包名 `zephyr`，导入使用 `package:zephyr/...`。
- 页面模块使用 barrel 文件统一 `export` 下层子模块。
- 复杂业务优先使用 `Bloc`，轻量状态使用 `Cubit`。
- 状态类优先使用 `freezed` 生成不可变数据；旧模块仍有手写 `copyWith` + `equatable`。

### 6.4 Rust 规范

- Rust 使用 edition 2024，`cargo fmt` 格式化。
- `rust-toolchain.toml` 指定工具链，请按项目配置使用。
- FRB 导出函数使用 `#[frb]`、`#[frb(sync)]`、`#[frb(init)]` 等宏标记。

---

## 7. 测试策略

- `test/` 下有 12 个测试文件、102 个用例：书架漫画目录关联（`test/bookshelf/`）、下载队列/重试/任务 JSON/进度（`test/download_*`）、下载资产存储、WebDAV/S3 同步核心与同步载荷编解码 / 凭据剥离（`test/network/sync/`）、阅读页图片头部尺寸、QJS 图片下载结果、墨水屏设置开关语义与「旧 JSON 缺字段回落默认值」的持久化契约（`test/settings/`）。`test/widget_test.dart` 仍是模板示例（已注释）。
- 运行：`fvm flutter test`（未装 fvm 的环境直接用 §4 描述的仓库版本 SDK）。注意 `test/test_helper.dart` 会 `import 'package:zephyr/main.dart'` 并创建真实 ObjectBox，因此宿主机需要 **native assets 构建链**（Rust 工具链 + `libobjectbox`）就绪，否则会先在 `Building native assets` 阶段失败；`test/network/sync/comic_sync_core_test.dart` 目前就因缺 `libobjectbox.so` 在宿主机全红，与 CI 无关。
- **CI 现状**：`.github/workflows/pr-check.yml` 在 PR 上只跑 `flutter analyze`（当前全仓 0 issue）；`flutter test` 尚未纳入门禁。修改核心逻辑后仍需手动在目标平台验证。
- 如果你新增复杂业务，建议补充测试；`test/download_task_json_test.dart` 与 `test/bookshelf/` 是可直接参照的写法样板。
- Windows 安装器 Rust crate（`windows-installer/src-tauri`）包含一个 `sevenz_roundtrip_with_long_paths` 单元测试，用于验证长路径 7z 归档能被 `sevenz-rust2` 正确解压；可在该目录运行 `cargo test --lib sevenz_roundtrip_with_long_paths`。

---

## 8. 部署与发布

### 8.1 CI/CD 工作流

- **`.github/workflows/pr-check.yml`**：`pull_request` 到 `main` 时触发，只跑 `fvm flutter analyze`（静态分析门禁，不构建产物）。
- **`.github/workflows/push-build.yml`**：每次 `push` 到 `main` 触发，并行构建 Android / Linux / Windows / macOS / iOS 产物为 artifact，**不发布 Release**。Android 构建前会安装 CMake 3.22.1，运行 `script/prepare_android_waifu2x_deps.py` 准备 OpenCV / libwebp 依赖，再依次运行 `script/build_ncnn_static_android.py` 与 `script/build_waifu2x_cli_android.py` 生成 `libwaifu2x_cli.so`；NCNN 模型不再随包打包，改为首次运行时下载；APK 产出后运行 `script/check_android_native_relocs.py` 校验 native 重定位兼容性（见 §5.3）。
- **`.github/workflows/android-native-reloc-gate.yml`**：`pull_request` / `push` 到 `main` 触发，**不依赖任何 secret**——只构建 debug APK（`android/key.properties` 缺失时 Gradle 走默认调试签名，见 §8.3），跳过 waifu2x / ncnn 重型预编译，只产出交付用的两个 ABI，再跑 `script/check_android_native_relocs.py`。存在的意义：`push-build.yml` 的同一校验排在 git-crypt 解密之后，fork 与 PR 上没有 `GIT_CRYPT_KEY` 时根本走不到那一步，这条是它们唯一能拿到的 Android native 门禁。校验前会先断言 APK 内确有 `libwindcore.so`，因为检查脚本对不含 `.so` 的产物会打印成功、形成假性通过。
- **`.github/workflows/release.yml`**：手动触发，输入版本号后构建全平台产物，上传符号表到 Sentry，创建 GitHub Release，更新 Homebrew Cask，并发送 Telegram 通知。Android 构建前同样会准备 waifu2x CLI 依赖并编译 CLI。
- **`.github/workflows/release_to_telegram.yml`**：Release `published` 时触发，向 Telegram 发送版本消息与附件。
- **`.github/workflows/signpath-smoke.yml`**：签名通道冒烟测试，与正式构建解耦。

### 8.2 发布前准备

1. 更新 `pubspec.yaml` 中的 `version`。
2. 在 `CHANGELOG.md` 顶部按格式追加新版本日志（格式：`## [vX.Y.Z]`）。
3. 提交并推送后手动触发 `release.yml`。

### 8.3 敏感文件

- `android/key.properties` 与 `android/Breeze-key.keystore` 使用 **git-crypt** 加密。
- CI 中通过 `secrets.GIT_CRYPT_KEY` 解密。
- 未解密前请勿修改这些文件，避免破坏加密状态。
- `android/app/build.gradle.kts` 用 `keystorePropertiesFile.exists()` 判空读取，且只有 `release` buildType 挂 signingConfig，因此 **`flutter build apk --debug` 在完全没有密钥的检出下也能构建**；release 构建则必须有该文件。fork 上 `build-android` 失败若停在「解密敏感文件 (git-crypt)」这一步，就是缺 `GIT_CRYPT_KEY` secret，不是代码问题。

### 8.4 Sentry 配置

- Release 构建通过 `--dart-define=sentry_dsn=...` 注入 DSN。
- 上传符号表需要 `SENTRY_AUTH_TOKEN`、`SENTRY_ORG`、`SENTRY_PROJECT` 环境变量。
- `pubspec.yaml` 中已配置 `sentry:` 段落。

---

## 9. 安全与合规注意事项

- **TLS 校验**：应用在初始化时调用 `setTlsVerifyEnabled(enabled: false)`（`lib/main.dart`），**数据面**默认关闭证书校验以兼容部分自签名证书图源；该开关写进 Rust 侧全局 HTTP 配置（`rust/src/qjs/mod.rs` 的 `disable_tls_verify`），凡走 `build_http_client_ex` / `WindHttp` 的流量都继承它，包括图源抓取、图片下载与 WebDAV 同步。**例外**：插件 bundle 属于「网络响应会被 QuickJS 当作可信代码直接执行」的路径，已单独强制校验 —— Rust 侧 `load_bundle_js_from_url`（`rust/src/qjs/mod.rs`）不跟随全局开关，Dart 侧统一走 `fetchBundle()`（`lib/network/http/wind_http.dart`，内部 `dangerAcceptInvalidCerts: false`），新增任何按 URL 拉取可执行 bundle 的入口都必须用它，不要用 `fetch()`。注意 `dart:io`（检查更新、Sentry）与系统 WebView 不受该全局开关影响。放宽校验前请评估影响，并优先考虑按 host 白名单而非全局关闭。
- **代理配置**：支持 HTTP / SOCKS5 代理，开发时通过 `.env.proxy` 配置，生产环境由用户在设置中配置。
- **插件系统**：插件运行在 QuickJS 沙箱中，但可执行网络请求与文件系统操作（取决于 feature）。新增宿主 API 时应注意权限边界。
- **第三方内容**：应用不直接托管漫画内容，内容由第三方插件提供。开发与发布时需遵守所在地区法律法规。
- **崩溃监控**：Release 构建启用 Sentry，会上报异常、性能样本与部分会话回放。注意保护用户隐私。
- **未签名桌面/macOS/iOS 包**：正式分发的包未进行 Apple / Windows 付费签名，首次安装可能需要用户手动放行。
- **云端同步载荷的加密契约**（`ComicSyncCore._encryptBytes` / `_decryptBytes`）：载荷头为 4 字节 magic + 16 字节 nonce，nonce 由 `HMAC(key, 明文)` 派生而不是随机。**不要把 nonce 改成随机**：上层用密文 MD5 同时做「内容是否变化」的判据和远端文件选择，随机化会让每次同步都判定为有变化并多写一个远端文件。旧版固定 nonce 的载荷必须继续可读（`settings_*.bin` / `comic_*.bin` 已在用户云端），回归由 `test/network/sync/sync_payload_codec_test.dart` 锁住。残余风险：AES 密钥硬编码在公开仓库里，只能挡住顺手翻看，挡不住有意解密；彻底修复需要用户口令派生密钥 + 迁移方案，属破坏性变更。
- **凭据的落点与出口**：`syncSetting` 里的 WebDAV 口令、S3 AK/SK 在上传云端前会被 `stripSyncCredentials` 清空（host / username / endpoint / bucket 保留，新设备需重填口令），`appLockSetting`、`customExportPath`、`cacheSetting` 同样不上传；该出口由 `test/network/sync/sync_settings_payload_test.dart` 锁住，新增同步载荷字段时不要绕过它。**接收端永远不会应用远端的 syncSetting**——同步只有 appearance / library / reader 三个 block，改动同步逻辑时不要把这条契约破坏。仍未解决：本地 ObjectBox（`UserSetting.globalSettingData`）以明文 JSON 保存这些凭据，迁移到系统安全存储需要密钥后端与备份/迁移方案，属破坏性变更；桌面端插件网页登录会拉起外部 Chromium 并开放 CDP 端口，`ExternalChromiumLoginSession.close()` 负责关浏览器与删除临时 profile（目录以 0700 创建），新增退出路径时不要漏掉它。
- **静态类型门禁**：`analysis_options.yaml` 已开启 `strict-casts`（2026-09 全仓 0 issue）。`strict-inference` 与 `strict-raw-types` 仍关闭，当时分别有约 35 / 45 条告警未清；开启前需先处理，否则 CI 会红。

---

## 10. 常见修改入口

| 你想做什么 | 从哪里开始 |
|-----------|-----------|
| 新增页面 / 路由 | `lib/page/`、`lib/util/router/router.dart`，然后运行代码生成 |
| 新增数据源/插件支持 | `lib/network/http/plugin/unified_comic_plugin.dart`、`rust/src/api/qjs.rs` |
| 修改数据库模型 | `lib/object_box/model.dart`，然后运行代码生成 |
| 修改全局设置 | `lib/config/global/global_setting.dart` |
| 修改墨水屏适配 | `lib/platform/eink/`（检测与整屏刷新）、`lib/page/setting/global/eink_setting_page.dart`、`global_setting.dart` 的 `EInkSettingState`；路由去动画走 `lib/config/router/router.dart` 的 `defaultRouteType`（`RouteType.material` 没有时长开关，只能用 `RouteType.custom` + 空 transitionsBuilder） |
| 在不持有 context 处取全局 Overlay / 弹窗 | `navigatorKey`（`lib/main.dart`）——它必须是 `appRouter.navigatorKey` 的别名。`MaterialApp.router` 会自建 Navigator，外部传入的独立 `GlobalKey` 挂不上去，`currentState` 恒为 null，取 overlay 的代码会**静默失效而不是报错** |
| 修改图片/下载逻辑 | `lib/service/download/`、`lib/network/http/picture/` |
| 修改 Rust 侧能力 | `rust/src/api/`、`rust/src/qjs/`，然后运行 FRB 生成 |
| 修改 Windows 安装器 | `windows-installer/src/`、`windows-installer/src-tauri/` |
| 修改 RealSR 超分逻辑 | `lib/page/setting/real_sr/service/real_sr_super_resolution.dart`、`lib/page/setting/real_sr/real_sr_setting_page.dart`、`rust/src/api/simple.dart` |
| 修改 Android RealSR 原生依赖 / waifu2x CLI | `script/prepare_android_waifu2x_deps.py`、`script/build_ncnn_static_android.py`、`script/build_waifu2x_cli_android.py`、`android/app/src/main/cpp/waifu2x_cli/`、`lib/page/setting/real_sr/service/real_sr_super_resolution.dart` |
| 修改桌面端 RealSR 策略/模型选择 | `lib/page/setting/real_sr/service/desktop_ncnn_model_config.dart`、`lib/page/setting/real_sr/service/real_sr_super_resolution.dart`、`lib/page/setting/real_sr/real_sr_setting_page.dart` |
| 修改 CoreML 超分（iOS/macOS） | `packages/coreml_upscale/`、`lib/debug/coreml_upscale_debug_page.dart`、`asset/coreml_models/`、`script/convert_realcugan_coreml.py` |
| 导入/导出应用数据 | `lib/page/setting/data_backup/`、`rust/src/api/data_backup.rs` |
| 修改 CI/CD | `.github/workflows/`、`script/` |

---

## 11. 延伸阅读

- **README.md**：用户安装指南与免责声明。
- **CHANGELOG.md**：版本发布日志。
- **plugin-dev-docs/**：插件开发文档（VitePress 站点），对外发布地址：<https://deretame.github.io/plugin-dev-docs/>
- **Android RealSR 构建文档**：`docs/android_realsr_build.md`
- **Flutter Rust Bridge 文档**：<https://cjycode.com/flutter_rust_bridge/>
