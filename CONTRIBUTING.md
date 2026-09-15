# Contributing / 参与贡献

Issues and pull requests are welcome. Please keep health data private: use the built-in demo workout in bug reports and tests.

欢迎提交 Issue 和 Pull Request。请勿在问题或测试中提交真实健康数据，请使用项目内置的示例跑步。

## Before opening a pull request

```bash
xcodegen generate
xcodebuild build -project AppleFleets.xcodeproj -scheme AppleFleets -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO
cd Mac && swift test
```

Explain what changed, why it changed, and how you tested it. Do not commit generated media, credentials, signing profiles, or real workout exports.

请说明改动内容、原因和测试方法。不要提交生成的媒体、登录信息、签名文件或真实跑步记录。
