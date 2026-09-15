# AppleFleets 使用说明

跑步结束后，AppleFleets 会读取 Apple Watch 已同步到 iPhone 的跑步数据，再由 Mac 上的 Codex 编辑内容，生成：

- 4 张小红书图片
- 1 个抖音竖屏视频
- 小红书标题、正文和话题
- 抖音文案和话题

第一次安装大约需要 30～60 分钟。安装完成后，平时只要正常戴 Apple Watch 跑步即可。

## 开始前准备

请准备：

- Apple Watch 和 iPhone，已经可以使用系统“体能训练”记录跑步
- 一台 macOS 14 或更新版本的 Mac
- 一根可以连接 iPhone 和 Mac 的数据线
- Apple ID
- 可以正常使用的网络

下面所有灰色代码都在 Mac 的“终端”中运行。打开方法：按 `Command + 空格`，输入“终端”，按回车。

## 第一步：安装 Xcode

1. 在 Mac 打开 App Store。
2. 搜索 **Xcode** 并安装。
3. 安装完成后打开一次 Xcode。
4. 如果看到许可协议，点击同意。
5. 如果提示安装附加组件，点击安装，等待完成。

在终端中复制下面两行，按回车：

```bash
xcode-select -p
xcodebuild -version
```

第二条命令能显示 Xcode 版本，就说明安装成功。

## 第二步：把项目下载到 Mac

推荐使用 GitHub Desktop：

1. 打开项目私有仓库：<https://github.com/JosephJagger/applefleets>
2. 点击绿色 **Code** 按钮。
3. 点击 **Open with GitHub Desktop**。
4. 保存位置选择“文稿”文件夹，然后点击 **Clone**。

下载完成后，项目通常在：

```text
~/Documents/applefleets
```

如果你选择了其他位置，后面的 `~/Documents/applefleets` 要换成你的实际位置。

## 第三步：安装 Homebrew 和 XcodeGen

先在终端运行：

```bash
brew --version
```

如果能看到版本号，直接安装 XcodeGen：

```bash
brew install xcodegen
```

如果提示 `command not found: brew`：

1. 打开 <https://brew.sh/zh-cn/>。
2. 复制网页“安装 Homebrew”下面的命令。
3. 粘贴到终端并按回车。
4. 按网页或终端提示完成安装。
5. 再运行 `brew install xcodegen`。

## 第四步：生成并打开 iPhone App

在终端中逐行运行：

```bash
cd ~/Documents/applefleets
xcodegen generate
open AppleFleets.xcodeproj
```

执行后会自动打开 Xcode。

如果第一行提示文件夹不存在，请在 Finder 中找到 `applefleets` 文件夹，把它直接拖到终端窗口中。然后在路径前面输入 `cd `，按回车，再运行后面两行。

## 第五步：在 Xcode 中设置签名

按下面位置操作：

1. 用数据线连接 iPhone 和 Mac。
2. 解锁 iPhone；如果询问是否信任这台电脑，点击“信任”。
3. 在 Xcode 左侧点击最上方蓝色的 **AppleFleets** 项目图标。
4. 在中间的 **TARGETS** 下点击 **AppleFleets**。
5. 点击顶部 **Signing & Capabilities**。
6. 勾选 **Automatically manage signing**。
7. 在 **Team** 右侧选择你的 Apple ID。
8. 找到 **Bundle Identifier**，改成只有你使用的名称，例如：

```text
com.josephjagger.applefleets
```

如果 Team 中没有你的 Apple ID：

1. 点击 Xcode 顶部菜单 **Xcode → Settings → Accounts**。
2. 点击左下角 `+`。
3. 登录 Apple ID。
4. 回到 **Signing & Capabilities** 重新选择 Team。

## 第六步：把 App 安装到 iPhone

1. 在 Xcode 窗口顶部找到设备名称。
2. 把模拟器名称改成你连接的 iPhone。
3. 点击左上角三角形运行按钮，或者按 `Command + R`。
4. 等待 Xcode 编译并把 AppleFleets 安装到 iPhone。

如果 iPhone 提示需要“开发者模式”：

1. 打开 iPhone **设置 → 隐私与安全性 → 开发者模式**。
2. 开启开发者模式并按提示重启 iPhone。
3. 回到 Xcode，再按一次 `Command + R`。

第一次打开 AppleFleets 时：

1. 健康数据权限全部选择“允许”。
2. 局域网权限选择“允许”。
3. 首页显示“已读取真实跑步记录”或能看到示例页面，就说明 iPhone 端安装成功。

## 第七步：安装并登录 Codex 命令行

AppleFleets 的自动编辑需要 Mac 能运行 `codex` 命令。

先检查：

```bash
codex --version
```

如果能看到版本号，继续登录：

```bash
codex login
```

浏览器打开后，使用你的 ChatGPT 账号登录。然后检查：

```bash
codex login status
```

如果第一条命令提示 `command not found: codex`，按照 [OpenAI 官方的 Codex CLI 安装说明](https://help.openai.com/en/articles/11096431)先安装 Node.js，再运行：

```bash
npm install -g @openai/codex
codex login
```

## 第八步：先生成一次测试内容

这一步使用项目内置的示例跑步，不需要 iPhone 数据。

在终端逐行运行：

```bash
cd ~/Documents/applefleets/Mac
swift build -c release
.build/release/applefleets demo --codex
```

第一次编译可能需要几分钟。看到下面这些文字表示 Codex 正在工作：

```text
[Codex] 正在分析配速、心率和分段，编辑两套平台内容…
[Codex] 编辑完成
[渲染] 正在将 codex 编辑方案写入图卡和视频…
```

完成后 Finder 会自动打开结果文件夹。里面应该有：

```text
xiaohongshu-01.png
xiaohongshu-02.png
xiaohongshu-03.png
xiaohongshu-04.png
douyin-vertical.mp4
xiaohongshu.md
douyin.md
content-plan.json
codex-input.md
codex-output.json
workout.json
```

双击图片和视频，确认它们能正常打开。

## 第九步：连接 iPhone 和 Mac

1. 确认 iPhone 和 Mac 连接同一个 Wi-Fi。
2. 在 iPhone 打开 AppleFleets，并保持页面亮着。
3. 找到页面“连接 Mac”区域。
4. 记下页面显示的网址，例如 `http://192.168.1.20:8765`。
5. 记下六位配对码。
6. 回到 Mac 终端。

运行下面的命令，把示例网址和配对码替换成你手机上显示的内容：

```bash
cd ~/Documents/applefleets/Mac
.build/release/applefleets pair http://192.168.1.20:8765 123456
```

看到“配对成功”后，再运行：

```bash
.build/release/applefleets fetch
```

如果终端显示一段包含 `distanceMeters`、`heartRate` 的文字，说明连接成功。

## 第十步：开启自动生成

回到项目根目录并运行安装脚本：

```bash
cd ~/Documents/applefleets
./scripts/install-mac-agent.sh --codex
```

看到“AppleFleets 已安装并开始监听”就完成了。以后 Mac 开机后会自动运行，不需要一直打开终端。

如果 macOS 询问是否允许传入网络连接，请点击“允许”。

## 平时怎么使用

完成上面的首次安装后，每次只需要：

1. 戴 Apple Watch，使用系统“体能训练”开始户外跑步或室内跑步。
2. 跑完后在 Apple Watch 上结束并保存训练。
3. 回到 iPhone，等待数据出现在“健康”App 中。
4. 打开一次 AppleFleets，点击右上角“刷新”。
5. 保持 Mac 开机并联网，等待几分钟。
6. 在 Mac 打开 **影片 → AppleFleets** 文件夹查看结果。
7. 把图片、视频和文案 AirDrop 到 iPhone，检查后发布到小红书或抖音。

Mac 上也可以直接打开结果文件夹：

```bash
open ~/Movies/AppleFleets
```

目前最后的“发布”需要你自己确认和点击，程序不会直接替你发布账号内容。

## 怎么确认 Codex 做了什么

打开本次生成的文件夹：

- `codex-input.md`：AppleFleets 提交给 Codex 的跑步数据和要求
- `codex-output.json`：Codex 返回的原始编辑结果
- `content-plan.json`：图片和视频实际采用的内容方案
- `xiaohongshu.md`：可复制的小红书文案
- `douyin.md`：可复制的抖音文案

如果 `content-plan.json` 中显示：

```json
"editor": "codex"
```

说明这次内容由 Codex 编辑。如果显示 `local-template`，说明 Codex 当时没有成功运行，程序使用了备用模板。

## 遇到问题怎么办

### Xcode 显示红色 Signing 错误

回到 **AppleFleets → TARGETS → AppleFleets → Signing & Capabilities**，确认：

- Team 已选择你的 Apple ID
- Automatically manage signing 已勾选
- Bundle Identifier 已改成唯一名称

### AppleFleets 看不到跑步

1. 打开 iPhone 的 **健康 → 浏览 → 活动 → 体能训练**。
2. 确认刚才的跑步已经出现。
3. 回到 AppleFleets 点击“刷新”。
4. 仍然没有时，打开 **设置 → 隐私与安全性 → 健康 → AppleFleets**，把权限全部打开。

### Mac 配对失败

确认：

- iPhone 和 Mac 使用同一个 Wi-Fi
- iPhone 上 AppleFleets 保持打开
- iPhone 已允许 AppleFleets 使用局域网
- 暂时关闭 VPN 后重试
- 命令中的网址和六位配对码与手机当前显示的一致

### 跑完后没有自动生成

先运行：

```bash
tail -f "$HOME/Library/Application Support/AppleFleets/logs/watch.log"
```

然后在 iPhone 的 AppleFleets 中点击“刷新”。按 `Control + C` 可以退出日志查看。

如果仍然没有生成，重新安装自动任务：

```bash
cd ~/Documents/applefleets
./scripts/uninstall-mac-agent.sh
./scripts/install-mac-agent.sh --codex
```

### Codex 没有参与编辑

运行：

```bash
codex login status
cd ~/Documents/applefleets/Mac
.build/release/applefleets demo --codex
```

然后查看终端错误，以及结果文件夹中的 `content-plan.json`。

## 停止自动生成

```bash
cd ~/Documents/applefleets
./scripts/uninstall-mac-agent.sh
```

## 隐私说明

- GPS 坐标不会发送到 Mac 或 Codex。
- Mac 只收到跑步日期、距离、用时、配速、心率和公里分段。
- 生成内容保存在本机 `~/Movies/AppleFleets`。
- AppleFleets 不会写入或修改健康数据。

## 给开发者的资料

日常安装不需要阅读下面的文件：

- [系统架构](docs/ARCHITECTURE.md)
- [第三方开源许可](THIRD_PARTY_NOTICES.md)

Mac 渲染使用 [swift-render](https://github.com/skyblanket/swift-render)，局域网通信参考 [healthkit-cli](https://github.com/rakshith48/healthkit-cli)，iPhone HTTP 服务使用 [Swifter](https://github.com/httpswift/swifter)。
