const base = process.env.RENDERER_URL ?? "http://127.0.0.1:3216";
const token = process.env.APPLEFLEETS_API_TOKEN;
if (!token) throw new Error("请设置 APPLEFLEETS_API_TOKEN");
const response = await fetch(`${base}/renders`, {
  method: "POST", headers: { Authorization: `Bearer ${token}`, "Content-Type": "application/json" },
  body: JSON.stringify({
    id: `smoke_${Date.now()}`,
    workout: { startedAt: "2026-09-15T06:30:00Z", distanceKilometers: 5.12, durationSeconds: 1610, averagePaceSeconds: 314, averageHeartRate: 146, maximumHeartRate: 168, activeEnergyKcal: 326, splits: [321,317,314,309,304].map((durationSeconds, i) => ({ kilometer: i + 1, durationSeconds })) },
    plan: { xiaohongshu: { title: "5公里，逐公里提速", body: "今天完成5.12公里，用时26分50秒。", hashtags: ["#跑步记录", "#五公里跑步"] }, douyin: { title: "5公里配速逐步加快", body: "记录一次稳定推进。", hashtags: ["#跑步", "#配速"] }, cards: { cover: "5公里逐步提速", closing: "把每一公里如实记下来" } }
  })
});
if (!response.ok) throw new Error(await response.text());
console.log(JSON.stringify(await response.json(), null, 2));
