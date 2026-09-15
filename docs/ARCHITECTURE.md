# AppleFleets 架构

## 数据流

```text
Apple Watch 体能训练
        │ HealthKit 系统同步
        ▼
iPhone AppleFleets
  ├─ HKObserverQuery 监听新 workout
  ├─ 读取距离、活动能量和关联心率样本
  ├─ 在本机读取 GPS 路线并计算公里分段
  ├─ 沙盒缓存最近一次 WorkoutSummary
  ├─ 带 Bearer Token 的只读局域网接口
  └─ 新摘要主动推送到已配对的 Mac
        │ GET /v1/latest-run 或 POST /v1/run
        ▼
Mac applefleets watch
  ├─ UUID 去重
  ├─ swift-render 生成四张 3:4 PNG
  ├─ swift-render 生成 12 秒 9:16 MP4
  ├─ 本地规则生成 caption.md
  └─ 可选：Codex 改写 caption.md
```

## 为什么不开发 watchOS App

第一期继续使用系统“体能训练”。系统已经负责传感器采样、训练保存和 Watch 到 iPhone 的 HealthKit 同步。自建 watchOS App 会增加训练状态管理、后台运行、电量、暂停恢复和传感器验证工作，却不会改善第一期的内容生成体验。

## 隐私边界

- GPS 坐标只在 iPhone 内存中用于计算公里分段，不进入 `WorkoutSummary`。
- iPhone 只开放最近一次跑步的只读接口。
- Mac Token 存于 `~/.applefleets/config.json`，权限设为 `0600`；iPhone Token 存于 Keychain。
- 未启用 `--codex` 时，全部内容在本地生成。
- 启用 `--codex` 时，只提交日期、距离、用时、配速、平均/最高心率和公里分段；界面和 README 都明确提示这一点。
- 不使用 CloudKit 或 iCloud Drive 保存健康记录及生成物。

## 后台行为

HealthKit 的后台通知只是“有更新”的信号，实际读取可能要等 iPhone 解锁。iPhone 在取得新摘要后主动推送给 Mac；Mac 常驻接收器同时每 15 秒轮询补偿，在下次 HealthKit 唤醒或打开 App 时补做。

若后续要作为正式上架产品，应继续把桥接层升级为：

1. 使用双向认证 TLS 或端到端加密消息；
2. 将待推送摘要放入持久失败队列；
3. 保存锚点查询位置，处理多次训练和删除事件；
4. 增加网络迁移后的 Bonjour 地址自动更新。

## 开源复用决策

- `healthkit-cli` 与需求最接近，但包含睡眠、血氧、文件库和训练计划等无关功能。AppleFleets 只吸收其配对、本地服务和后台桥接思路。
- `swift-render` 的 `Recorder` 是独立 Swift Package 公共 API，因此固定提交版本作为依赖，AppleFleets 自己实现所有跑步场景。
- `RUNSTR` 规模和业务依赖过大，只作为行为参考。
- `WorkoutExporter` 长期未维护，不纳入依赖。
