<p align="center">
  <img src="docs/assets/applefleets-hero.svg" alt="AppleFleets：把 Apple Watch 跑步数据变成可发布内容" width="100%">
</p>

<p align="center">Apple Watch 记录，iPhone 读取，Linux 上的 Codex 写文案并生成图片和视频，成品回到手机。</p>

<p align="center">
  <a href="https://github.com/JosephJagger/applefleets/actions/workflows/build.yml"><img alt="构建状态" src="https://github.com/JosephJagger/applefleets/actions/workflows/build.yml/badge.svg"></a>
  <a href="LICENSE"><img alt="MIT 开源协议" src="https://img.shields.io/badge/license-MIT-3d72ff.svg"></a>
  <img alt="iOS 17 及以上" src="https://img.shields.io/badge/iOS-17%2B-0b2044.svg">
</p>

<p align="center"><a href="README.md">English</a> · <strong>简体中文</strong></p>

---

## 日常使用不需要 Mac

```mermaid
flowchart LR
    A[Apple Watch<br/>体能训练] --> B[iPhone<br/>健康数据]
    B -->|HTTPS| C[agentfleets.cn<br/>AgentFleet]
    C --> D[Linux 主机<br/>Codex]
    D --> G[/root/iwatch<br/>媒体生成器]
    G -->|下载成品| B
    B --> E[小红书<br/>4 张图片]
    B --> F[抖音<br/>竖屏视频]
```

- 手表继续使用苹果自带的“体能训练”，不用安装 Watch App。
- Linux 主机负责运行 AgentFleet 和 Codex，可以一直在线。
- `/root/iwatch` 负责生成 4 张图片和竖屏视频，所有设备使用同一套版式。
- iPhone 负责读取健康数据、下载预览和打开分享菜单；网络异常时可在手机本地备用生成。
- Mac 只在第一次通过 Xcode 安装原型，以及以后重新编译升级时使用。
- 如果以后发布到 TestFlight 或 App Store，安装更新也不需要连接 Mac。

## 能生成什么

| 平台 | 内容 |
| --- | --- |
| 小红书 | 4 张 1080 × 1440 PNG、标题、正文、话题 |
| 抖音 | 1 个 1080 × 1920 竖屏 MP4、标题、正文、话题 |

Codex 返回的封面文字和收尾文字会进入图片和视频。发布前仍由你检查并点击分享，项目不会自动登录或操作社交账号。

## 第一次安装

需要准备：

- Apple Watch 和 iPhone，跑步记录能正常出现在 iPhone“健康”中；
- iOS 17 或更新版本；
- 已经运行在 `https://agentfleets.cn` 的 AgentFleet；
- AgentFleet 中已连接并登录 Codex 的 Linux 主机；
- 一台装有 Xcode 的 Mac，仅用于把原型 App 安装到 iPhone。

### 第 1 步：更新 Linux 上的 AgentFleet

登录 Linux 主机，进入当前 AgentFleet 项目目录：

```bash
git status
git pull
```

如果 `git status` 显示有自己修改过但未提交的文件，先保存这些改动，不要直接拉取。

### 第 2 步：准备 Codex 项目

1. 浏览器打开 `https://agentfleets.cn` 并登录。
2. 确认 Linux 主机显示“在线”。
3. 在这台主机下面添加项目，名称填写 `iwatch`。
4. 项目目录填写宿主机上的 `/root/iwatch`。
5. 打开该项目的“内容同步”。iPhone 需要它来读取 Codex 的最终文案。

如果使用已有项目，下一步填写它的实际名称。项目名称必须唯一。

### 第 3 步：生成 iPhone 连接令牌

在 Linux 终端运行：

```bash
openssl rand -hex 32
```

复制终端显示的 64 位字符。不要把它发到聊天、截图或提交到 GitHub。

编辑 AgentFleet 项目目录中的 `.env`，在末尾加入：

```dotenv
APPLEFLEETS_API_TOKEN=这里粘贴刚生成的64位字符
APPLEFLEETS_PROJECT=iwatch
```

`APPLEFLEETS_PROJECT` 必须和网页中的项目名称完全一致。

### 第 4 步：启动图片和视频生成器

本项目的 `Server` 文件夹就是媒体生成器。在 Linux 运行：

```bash
mkdir -p /root/iwatch
git clone https://github.com/JosephJagger/applefleets.git /root/iwatch/source
cp -R /root/iwatch/source/Server /root/iwatch/server
cd /root/iwatch/server
cp .env.example .env
nano .env
```

如果 `/root/iwatch/source` 已经存在，进入该目录运行 `git pull`，再重新复制 `Server` 文件夹。

把 `.env` 中的 `APPLEFLEETS_API_TOKEN` 改成第 3 步的同一个令牌，然后运行：

```bash
docker compose up -d --build
curl --fail http://127.0.0.1:3216/health
```

公网需要把 `https://你的域名/iwatch-api/` 反向代理到 `http://127.0.0.1:3216/`。当前 `agentfleets.cn` 已经设置完成。

### 第 5 步：重启 AgentFleet

在 AgentFleet 项目目录运行：

```bash
docker compose up -d --build
curl --fail http://127.0.0.1:3215/ready
```

第二条命令正常结束后，再打开 `https://agentfleets.cn`，确认网页和 Linux 主机仍然在线。

### 第 6 步：在 Mac 打开 iPhone 项目

Mac 需要安装并打开过一次 Xcode。在“终端”运行：

```bash
cd ~/Documents
git clone https://github.com/JosephJagger/applefleets.git
cd applefleets
brew install xcodegen
xcodegen generate
open AppleFleets.xcodeproj
```

如果已经下载过项目：

```bash
cd ~/Documents/applefleets
git pull
xcodegen generate
open AppleFleets.xcodeproj
```

提示找不到 `brew` 时，先从 [Homebrew 中文官网](https://brew.sh/zh-cn/)安装。

### 第 7 步：设置 Xcode 签名

1. 用数据线连接并解锁 iPhone，手机询问时点击“信任”。
2. Xcode 左侧点击蓝色的 **AppleFleets** 项目。
3. 在 **TARGETS** 下点击 **AppleFleets**。
4. 打开 **Signing & Capabilities**。
5. 勾选 **Automatically manage signing**。
6. 在 **Team** 中选择自己的 Apple ID。
7. 把 **Bundle Identifier** 改成唯一值，例如 `com.yourname.applefleets`。

Team 中没有账号时，打开 **Xcode → Settings → Accounts**，点击左下角 `+` 登录。

### 第 8 步：安装到 iPhone

1. 在 Xcode 顶部设备菜单选择自己的 iPhone。
2. 点击左上角三角形运行按钮，或者按 `Command + R`。
3. 如果手机要求开发者模式，进入 **设置 → 隐私与安全性 → 开发者模式**，开启并重启。
4. 回到 Xcode 再运行一次。
5. AppleFleets 第一次打开时，允许读取健康数据。

### 第 9 步：连接 AgentFleet

1. 在 iPhone 打开 AppleFleets。
2. 在 **Linux Codex** 卡片中，地址填写 `https://agentfleets.cn`。
3. “连接令牌”粘贴第 3 步生成的字符。
4. 打开真实跑步，或者点击“查看示例”。
5. 点击“用 Linux 生成文案、卡片和视频”。
6. 等状态变成“成品已返回”。
7. 检查四张图以及标题、正文和话题。
8. 点击“生成小红书图文”或“生成抖音竖屏视频”，从 iPhone 分享菜单选择目标 App。

## 每次跑完怎么用

1. 在 Apple Watch 中结束体能训练。
2. 等待跑步出现在 iPhone“健身”或“健康”中。
3. 打开 AppleFleets。
4. App 自动提交给 Linux；Codex 写文案，`/root/iwatch` 生成图片和视频。
5. 如果没有自动开始，点击“刷新”，再点击“用 Linux 生成文案、卡片和视频”。
6. 状态显示“成品已返回”后，在手机上检查并分享。

任务送达 Linux 后，即使暂时切走 App，Codex 仍会继续。重新打开同一条跑步并再次点击时，会读取同一个任务，不会重复创建。

## 隐私和安全

- 发送：开始时间、距离、用时、平均配速、平均及最高心率、热量、公里分段。
- 不发送：GPS 坐标、完整心率时间序列、健康资料库中的其他记录。
- 只连接 HTTPS；令牌保存在 iPhone 钥匙串中。
- 生成文件保存在 Linux 的 `/root/iwatch/server/output`，下载时也必须携带令牌。
- 令牌只能提交固定格式的跑步任务并读取对应结果，不能用于管理员网页登录。

令牌可能泄露时，重新运行 `openssl rand -hex 32`，替换 `.env` 中的值，再运行 `docker compose up -d --build`。旧令牌会立即失效。

## 常见问题

<details>
<summary><strong>显示“需要设置”</strong></summary>

确认地址以 `https://` 开头，令牌是完整的 64 位字符，前后没有空格。

</details>

<details>
<summary><strong>提示项目不存在或需要内容同步</strong></summary>

确认 `APPLEFLEETS_PROJECT` 与网页项目名称完全一致、没有两个同名项目，并为该项目开启内容同步。

</details>

<details>
<summary><strong>一直显示“Codex 生成中”</strong></summary>

打开 AgentFleet，查看标题以 `AppleFleets` 开头的会话。确认 Linux 主机在线、Codex 已登录，并检查是否在等待批准或回答。

</details>

<details>
<summary><strong>文案有了，但服务器媒体生成失败</strong></summary>

在 Linux 运行 `docker ps --filter name=applefleets-renderer` 和 `curl http://127.0.0.1:3216/health`。即使服务器暂时失败，App 的分享按钮仍会使用 iPhone 本地生成作为备用。

</details>

<details>
<summary><strong>跑步没有出现</strong></summary>

先在 iPhone“健康”中确认记录已经同步，再回 AppleFleets 点击“刷新”。在 **设置 → 隐私与安全性 → 健康 → AppleFleets** 中确认读取权限已开启。

</details>

## 开发与编译

```bash
xcodegen generate
xcodebuild \
  -project AppleFleets.xcodeproj \
  -scheme AppleFleets \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  CODE_SIGNING_ALLOWED=NO build
```

原来的 Mac 局域网工具仍保留为可选方案：

```bash
cd Mac
swift test
swift build -c release
```

测试服务器代码：

```bash
node --test Server/test/*.test.js
```

## 开源协议

[MIT](LICENSE)
