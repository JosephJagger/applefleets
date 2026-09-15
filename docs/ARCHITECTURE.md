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
  └─ 通过 HTTPS 提交去除 GPS 的训练摘要
        │ 固定格式的 AgentFleet 集成接口
        ▼
Linux AgentFleet + /root/iwatch
  ├─ UUID 去重并交给 Codex 输出结构化编辑方案
  ├─ Chromium 生成四张 1080 × 1440 PNG
  ├─ FFmpeg 生成 1080 × 1920 MP4
  └─ iPhone 携带同一令牌下载、预览和分享
```

## 为什么不开发 watchOS App

第一期继续使用系统“体能训练”。系统已经负责传感器采样、训练保存和 Watch 到 iPhone 的 HealthKit 同步。自建 watchOS App 会增加训练状态管理、后台运行、电量、暂停恢复和传感器验证工作，却不会改善第一期的内容生成体验。

## 隐私边界

- GPS 坐标只在 iPhone 内存中用于计算公里分段，不进入 `WorkoutSummary`。
- iPhone Token 存于 Keychain；服务器令牌只放在被 Git 忽略的 `.env`。
- 只提交日期、距离、用时、配速、平均/最高心率、热量和公里分段。
- 下载图片和视频也要求 Bearer Token；生成物放在 `/root/iwatch/server/output`。
- 服务器不可用时，iPhone 可使用原有的本地生成作为备用。
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
