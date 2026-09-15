# AppleFleets 跑步内容流水线

AppleFleets 从 iPhone 的 HealthKit 读取 Apple Watch「体能训练」保存的最近一次跑步，经配对鉴权的局域网连接交给 Mac 生成：

- 4 张 1080 × 1440 小红书图文卡片
- 1 个 1080 × 1920、约 12 秒的抖音竖屏 MP4
- 可直接复制的中文标题、正文和话题

健康数据不会写入 iCloud。GPS 坐标仅在 iPhone 上计算公里分段，不会传给 Mac。Mac 只接收距离、时间、配速、心率点和分段；生成物保存在 `~/Movies/AppleFleets`。

## 1. 安装 iPhone App

### 环境要求

- macOS 14 或更新版本，推荐 Apple Silicon Mac
- Xcode 16 或更新版本，并已执行首次启动组件安装
- iOS 17 或更新版本的 iPhone
- 已与 iPhone 配对、能够正常写入“健康”的 Apple Watch
- Apple ID；个人原型可以使用 Xcode 的 Personal Team 签名
- Homebrew，用于安装 XcodeGen

先确认命令行工具指向当前 Xcode：

```bash
xcode-select -p
xcodebuild -version
```

### 生成与编译

```bash
brew install xcodegen
xcodegen generate
open AppleFleets.xcodeproj
```

在 Xcode 中完成以下设置：

1. 选择项目中的 `AppleFleets` Target。
2. 打开 **Signing & Capabilities**，选择你的 Team。
3. 把 `com.local.applefleets` 改为唯一 Bundle Identifier，例如 `com.你的名字.applefleets`。
4. 确认 HealthKit 和 HealthKit Background Delivery 能力存在。
5. 在 iPhone 的“隐私与安全性 → 开发者模式”中启用开发者模式。
6. 用数据线或已配对的无线调试连接 iPhone，选择它作为运行设备。
7. 按 `⌘R` 编译安装。

也可以先验证模拟器编译：

```bash
xcodebuild build \
  -project AppleFleets.xcodeproj \
  -scheme AppleFleets \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO
```

首次打开时允许读取体能训练、路线、心率、步行与跑步距离、活动能量，并允许访问局域网。App 不会申请写入健康数据。

模拟器没有真实 HealthKit 后台数据，可点击首页的“查看示例”测试 iPhone 内生成流程。

## 2. 编译并配对 Mac

Mac 渲染器使用固定版本的 `swift-render`。第一次构建会从 GitHub 拉取依赖：

```bash
cd Mac
swift build -c release
.build/release/applefleets demo
.build/release/applefleets pair http://iPhone界面显示的地址:8765 六位配对码
.build/release/applefleets fetch
.build/release/applefleets render
```

`demo` 不需要 iPhone，先用它确认四张图片和竖屏视频能够正常生成。输出位于 `~/Movies/AppleFleets/`。

配对时保持 iPhone App 在前台，并确认两台设备连接同一 Wi-Fi。配对请求会让 iPhone 记录 Mac 的局域网地址；以后获得新跑步时，iPhone 会主动推送到 Mac 的 8766 端口。macOS 首次询问是否允许传入连接时请选择“允许”。

## 3. 自动监听

回到仓库根目录。基础模式使用固定模板文案：

```bash
./scripts/install-mac-agent.sh
```

让 Mac 上已经登录的 Codex 根据公开训练摘要改写文案：

```bash
./scripts/install-mac-agent.sh --codex
```

启用前先确认 Mac 上的 Codex 已登录：

```bash
codex login status
```

启用 `--codex` 后，日期、距离、时间、配速、平均/最高心率和公里分段会提交给 Codex；GPS 坐标和原始 HealthKit 文件不会提交。自动任务每 15 秒检查一次，使用 workout UUID 去重。

查看运行状态和日志：

```bash
launchctl print gui/$(id -u)/com.local.applefleets.watch
tail -f "$HOME/Library/Application Support/AppleFleets/logs/watch.log"
tail -f "$HOME/Library/Application Support/AppleFleets/logs/watch-error.log"
```

停止自动监听：

```bash
./scripts/uninstall-mac-agent.sh
```

## 当前流程

1. Apple Watch 结束并保存跑步。
2. 数据同步到 iPhone 的 HealthKit。
3. App 在收到 workout 更新后刷新最近一次跑步；系统可能延迟投递。
4. iPhone 主动推送摘要给 Mac；Mac 每 15 秒轮询作为补偿。
5. Finder 自动得到四张小红书图片、抖音视频、`caption.md` 和原始摘要副本。
6. 通过 AirDrop 或系统分享页发到 iPhone，检查后发布。

第一期使用系统分享页，避免依赖尚未获批的抖音投稿权限；后续拿到 `aweme.share` 能力后可接入抖音 OpenSDK。

## 项目结构

- `HealthKitManager`：授权、后台监听、读取跑步、心率和路线分段
- `WorkoutSummary`：与 UI、渲染器隔离的值类型数据模型
- `RunBridgeServer`：配对鉴权、Bonjour 和只读局域网接口
- `WorkoutCardView`：3:4 和 9:16 共用的内容模板
- `CardExporter`：SwiftUI → PNG
- `VideoExporter`：PNG → H.264 MP4
- `HomeView`：预览、文案编辑、隐私设置和分享
- `Mac/`：独立的 AppleFleets 命令、Mac 模板、Codex 文案步骤和监听器

## 已知边界

- Apple Watch 到 iPhone 的 HealthKit 同步由系统调度，结束训练后可能延迟。
- iOS 被用户从多任务界面强制退出后，不会继续接收 HealthKit 后台通知。
- 手机锁定时 HealthKit 数据可能暂时不可读；解锁或下次打开 App 后会补做。
- iPhone 被强制退出、低电量模式或系统后台预算不足时，生成时间会推迟。
- 抖音和小红书的最终发布仍由用户确认。

## 调试与常见问题

### 找不到跑步记录

打开 iPhone 的“健康 → 浏览 → 活动 → 体能训练”确认跑步已经从手表同步。回到 AppleFleets 点击“刷新”。如果健康授权曾被拒绝，到“设置 → 隐私与安全性 → 健康 → AppleFleets”重新开启。

### Mac 无法配对或 fetch

确认 iPhone App 在前台、两台设备在同一局域网，并先测试：

```bash
curl http://iPhone界面显示的地址:8765/pair
```

返回 HTTP 错误说明网络已经连通；连接超时通常是局域网权限、访客 Wi-Fi 隔离、VPN 或防火墙造成的。配对接口要求 POST，所以上面的 GET 只用于连通性检查。

### 自动任务没有生成内容

先在终端前台运行，以便直接查看错误：

```bash
cd Mac
.build/release/applefleets watch --interval 15
```

然后在 iPhone App 点击“刷新”。若前台模式可用而 LaunchAgent 不可用，检查上面的 `watch-error.log`，并重新运行安装脚本。

### Codex 失败

自动流程会保留本地模板生成的 `caption.md`，不会重复渲染视频。运行 `codex login status` 检查登录状态，再用 `applefleets demo --codex` 单独验证文案步骤。

## 开源来源

Mac 渲染使用固定提交版本的 [swift-render](https://github.com/skyblanket/swift-render)。局域网桥接参考 [healthkit-cli](https://github.com/rakshith48/healthkit-cli)，iPhone HTTP 服务使用 [Swifter](https://github.com/httpswift/swifter)。三者均按 MIT 许可使用，详情见 `THIRD_PARTY_NOTICES.md`。
