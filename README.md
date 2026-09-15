# AppleFleets

**English** | [简体中文](README.zh-CN.md)

AppleFleets turns Apple Watch running workouts into ready-to-review social content. After a workout syncs to Health on your iPhone, the project sends a private summary to your Mac. Codex edits the story, and the Mac creates:

- four Xiaohongshu images;
- one vertical Douyin video;
- a Xiaohongshu title, post, and hashtags;
- a Douyin hook, caption, and hashtags.

The first setup usually takes 30–60 minutes. Once it is installed, you can keep using Apple's built-in Workout app on the Watch.

## What you need

- An Apple Watch and iPhone that already record workouts in Apple Health
- A Mac running macOS 14 or later
- A cable to connect the iPhone to the Mac for the first installation
- An Apple ID
- An internet connection

All gray commands below run in Terminal on the Mac. Press `Command + Space`, type `Terminal`, and press Return to open it.

## Step 1: Install Xcode

1. Open the App Store on the Mac.
2. Search for **Xcode** and install it.
3. Open Xcode once after installation.
4. Accept the license if prompted.
5. Install any additional components that Xcode requests.

Run these commands in Terminal:

```bash
xcode-select -p
xcodebuild -version
```

This step is complete when the second command prints an Xcode version.

## Step 2: Download AppleFleets

The easiest option is GitHub Desktop:

1. Open <https://github.com/JosephJagger/applefleets>.
2. Click the green **Code** button.
3. Click **Open with GitHub Desktop**.
4. Choose the Documents folder and click **Clone**.

The project will normally be saved here:

```text
~/Documents/applefleets
```

If you chose another location, replace `~/Documents/applefleets` in later commands with that location.

You can also clone it from Terminal:

```bash
cd ~/Documents
git clone https://github.com/JosephJagger/applefleets.git
```

## Step 3: Install Homebrew and XcodeGen

Check whether Homebrew is already installed:

```bash
brew --version
```

If the command prints a version, install XcodeGen:

```bash
brew install xcodegen
```

If Terminal says `command not found: brew`:

1. Open <https://brew.sh/>.
2. Copy the installation command shown on that page.
3. Paste it into Terminal and press Return.
4. Follow the instructions printed by the installer.
5. Run `brew install xcodegen` again.

## Step 4: Generate and open the iPhone project

Run these commands one at a time:

```bash
cd ~/Documents/applefleets
xcodegen generate
open AppleFleets.xcodeproj
```

Xcode should open automatically.

If the first command says the folder does not exist, locate the `applefleets` folder in Finder. Type `cd ` in Terminal, drag the folder into Terminal, and press Return. Then run the last two commands again.

## Step 5: Configure signing in Xcode

1. Connect the iPhone to the Mac with a cable.
2. Unlock the iPhone and tap **Trust** if it asks whether to trust the computer.
3. In Xcode, click the blue **AppleFleets** project icon at the top of the left sidebar.
4. Under **TARGETS**, select **AppleFleets**.
5. Open **Signing & Capabilities**.
6. Enable **Automatically manage signing**.
7. Select your Apple ID under **Team**.
8. Change **Bundle Identifier** to a unique value, for example:

```text
com.josephjagger.applefleets
```

If your Apple ID is missing from the Team list:

1. Open **Xcode → Settings → Accounts**.
2. Click `+` in the bottom-left corner.
3. Sign in with your Apple ID.
4. Return to **Signing & Capabilities** and select the Team again.

## Step 6: Install the app on the iPhone

1. At the top of the Xcode window, click the current simulator or device name.
2. Select the connected iPhone.
3. Click the triangular Run button, or press `Command + R`.
4. Wait for Xcode to build and install AppleFleets.

If the iPhone asks for Developer Mode:

1. Open **Settings → Privacy & Security → Developer Mode** on the iPhone.
2. Enable it and restart the iPhone when asked.
3. Return to Xcode and press `Command + R` again.

When AppleFleets opens for the first time:

1. Allow all requested Health read permissions.
2. Allow Local Network access.
3. The iPhone setup is complete when the app shows a workout or lets you open the demo.

## Step 7: Install and sign in to Codex CLI

AppleFleets needs the `codex` command on the Mac. Check it first:

```bash
codex --version
```

If it prints a version, sign in:

```bash
codex login
```

Complete the browser sign-in with your ChatGPT account, then check the result:

```bash
codex login status
```

If Terminal says `command not found: codex`, follow the [official Codex CLI setup guide](https://help.openai.com/en/articles/11096431). After installing Node.js, you can install and sign in with:

```bash
npm install -g @openai/codex
codex login
```

## Step 8: Create sample content

This test uses the included demo workout, so it does not need iPhone data.

Run:

```bash
cd ~/Documents/applefleets/Mac
swift build -c release
.build/release/applefleets demo --codex
```

The first build may take a few minutes. These messages show that Codex is working:

```text
[Codex] 正在分析配速、心率和分段，编辑两套平台内容…
[Codex] 编辑完成
[渲染] 正在将 codex 编辑方案写入图卡和视频…
```

Finder opens the result folder when rendering finishes. It should contain:

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

Open the images and video to confirm they work.

## Step 9: Pair the iPhone and Mac

1. Connect the iPhone and Mac to the same Wi-Fi network.
2. Open AppleFleets on the iPhone and leave it visible.
3. Find the **连接 Mac** section.
4. Note the displayed address, such as `http://192.168.1.20:8765`.
5. Note the six-digit pairing code.
6. Return to Terminal on the Mac.

Run this command, replacing the example address and code with the values shown on your iPhone:

```bash
cd ~/Documents/applefleets/Mac
.build/release/applefleets pair http://192.168.1.20:8765 123456
```

After Terminal says `配对成功`, test the connection:

```bash
.build/release/applefleets fetch
```

Pairing works if Terminal prints text containing fields such as `distanceMeters` and `heartRate`.

## Step 10: Enable automatic generation

Run the installer from the project folder:

```bash
cd ~/Documents/applefleets
./scripts/install-mac-agent.sh --codex
```

Setup is complete when Terminal prints `AppleFleets 已安装并开始监听`. AppleFleets now starts automatically when you sign in to the Mac.

If macOS asks whether to allow incoming network connections, click **Allow**.

## Everyday use

After the first setup:

1. Start an indoor or outdoor run in Apple's Workout app on the Watch.
2. Finish and save the workout on the Watch.
3. Wait for the workout to appear in the Health app on the iPhone.
4. Open AppleFleets once and tap **刷新** in the top-right corner.
5. Keep the Mac awake and connected, then wait a few minutes.
6. Open **Movies → AppleFleets** on the Mac.
7. AirDrop the images, video, and captions to the iPhone.
8. Review the content and publish it in Xiaohongshu or Douyin.

Open the output folder directly with:

```bash
open ~/Movies/AppleFleets
```

Publishing still requires your confirmation. AppleFleets does not post directly to your social accounts.

## See exactly what Codex did

Every generated folder includes:

- `codex-input.md`: the workout summary and instructions sent to Codex;
- `codex-output.json`: Codex's raw structured response;
- `content-plan.json`: the content plan used by the image and video renderer;
- `xiaohongshu.md`: the Xiaohongshu post;
- `douyin.md`: the Douyin caption.

Open `content-plan.json`. This value means Codex edited the content:

```json
"editor": "codex"
```

If it says `local-template`, the Codex step failed and AppleFleets used its offline fallback template.

## Troubleshooting

### Xcode shows a red signing error

Open **AppleFleets → TARGETS → AppleFleets → Signing & Capabilities** and check that:

- your Apple ID is selected under Team;
- Automatically manage signing is enabled;
- Bundle Identifier is unique.

### AppleFleets cannot find the workout

1. Open **Health → Browse → Activity → Workouts** on the iPhone.
2. Confirm that the run appears there.
3. Return to AppleFleets and tap **刷新**.
4. If it still does not appear, open **Settings → Privacy & Security → Health → AppleFleets** and enable the requested permissions.

### Pairing fails

Check that:

- both devices use the same Wi-Fi;
- AppleFleets is open on the iPhone;
- Local Network access is enabled for AppleFleets;
- VPN is temporarily disabled;
- the address and current pairing code exactly match the iPhone screen.

### A workout does not generate content

Watch the agent log:

```bash
tail -f "$HOME/Library/Application Support/AppleFleets/logs/watch.log"
```

Tap **刷新** in AppleFleets. Press `Control + C` to stop viewing the log.

If needed, reinstall the background agent:

```bash
cd ~/Documents/applefleets
./scripts/uninstall-mac-agent.sh
./scripts/install-mac-agent.sh --codex
```

### Codex did not edit the content

Run:

```bash
codex login status
cd ~/Documents/applefleets/Mac
.build/release/applefleets demo --codex
```

Check the Terminal error and `content-plan.json` in the generated folder.

## Disable automatic generation

```bash
cd ~/Documents/applefleets
./scripts/uninstall-mac-agent.sh
```

## Privacy

- GPS coordinates never leave the iPhone and are not sent to Codex.
- The Mac receives only the date, distance, duration, pace, heart-rate data, and kilometer splits.
- Generated content stays in `~/Movies/AppleFleets` on the Mac.
- AppleFleets requests read-only Health access and does not modify Health data.

## Development

Generate and build the iPhone project:

```bash
brew install xcodegen
xcodegen generate
xcodebuild build -project AppleFleets.xcodeproj -scheme AppleFleets -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO
```

Build and test the Mac renderer:

```bash
cd Mac
swift build -c release
swift test
```

See [Architecture](docs/ARCHITECTURE.md), [Contributing](CONTRIBUTING.md), and [Third-party notices](THIRD_PARTY_NOTICES.md).

## License

AppleFleets is released under the [MIT License](LICENSE). Third-party components keep their respective licenses as listed in [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
