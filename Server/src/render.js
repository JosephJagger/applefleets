import { mkdir, writeFile } from "node:fs/promises";
import { spawn } from "node:child_process";
import path from "node:path";

const kinds = ["cover", "splits", "heart", "finish"];

export function validatePayload(input) {
  if (!input || typeof input !== "object") throw new Error("请求内容为空");
  const { workout, plan } = input;
  if (!workout || !plan?.xiaohongshu || !plan?.douyin || !plan?.cards) throw new Error("缺少跑步数据或文案");
  const positive = [workout.distanceKilometers, workout.durationSeconds, workout.averagePaceSeconds];
  if (positive.some((value) => typeof value !== "number" || !Number.isFinite(value) || value <= 0)) throw new Error("跑步数据无效");
  return {
    workout: {
      startedAt: String(workout.startedAt ?? new Date().toISOString()),
      distanceKilometers: Math.min(workout.distanceKilometers, 500),
      durationSeconds: Math.min(workout.durationSeconds, 172800),
      averagePaceSeconds: Math.min(workout.averagePaceSeconds, 3600),
      averageHeartRate: optionalNumber(workout.averageHeartRate, 30, 250),
      maximumHeartRate: optionalNumber(workout.maximumHeartRate, 30, 250),
      activeEnergyKcal: optionalNumber(workout.activeEnergyKcal, 0, 20000),
      splits: Array.isArray(workout.splits) ? workout.splits.slice(0, 100).map((split, index) => ({
        kilometer: Number.isInteger(split.kilometer) ? split.kilometer : index + 1,
        durationSeconds: clampNumber(split.durationSeconds, 1, 3600)
      })) : []
    },
    plan: {
      xiaohongshu: platform(plan.xiaohongshu),
      douyin: platform(plan.douyin),
      cards: { cover: text(plan.cards.cover, 40), closing: text(plan.cards.closing, 100) }
    }
  };
}

function optionalNumber(value, min, max) {
  return typeof value === "number" && Number.isFinite(value) ? Math.min(max, Math.max(min, value)) : null;
}
function clampNumber(value, min, max) {
  if (typeof value !== "number" || !Number.isFinite(value)) throw new Error("公里分段数据无效");
  return Math.min(max, Math.max(min, value));
}
function text(value, max) {
  if (typeof value !== "string" || !value.trim()) throw new Error("文案内容无效");
  return value.trim().slice(0, max);
}
function platform(value) {
  return {
    title: text(value.title, 60), body: text(value.body, 1000),
    hashtags: Array.isArray(value.hashtags) ? value.hashtags.slice(0, 12).map((tag) => text(tag, 40)) : []
  };
}

export async function renderPackage({ id, payload, outputRoot, chromiumBin, ffmpegBin, publicBaseURL }) {
  const safe = validatePayload(payload);
  const folder = path.join(outputRoot, id);
  await mkdir(folder, { recursive: true });
  const postFiles = [];
  const storyFiles = [];
  for (let index = 0; index < kinds.length; index += 1) {
    const kind = kinds[index];
    const postHTML = path.join(folder, `${kind}-post.html`);
    const storyHTML = path.join(folder, `${kind}-story.html`);
    const postPNG = path.join(folder, `xiaohongshu-${index + 1}.png`);
    const storyPNG = path.join(folder, `douyin-${index + 1}.png`);
    await writeFile(postHTML, cardHTML(safe, kind, index, "post"));
    await writeFile(storyHTML, cardHTML(safe, kind, index, "story"));
    await screenshot(chromiumBin, postHTML, postPNG, 1080, 1440);
    await screenshot(chromiumBin, storyHTML, storyPNG, 1080, 1920);
    postFiles.push(path.basename(postPNG));
    storyFiles.push(path.basename(storyPNG));
  }
  const videoFile = "douyin-vertical.mp4";
  await video(ffmpegBin, storyFiles.map((file) => path.join(folder, file)), path.join(folder, videoFile));
  const base = `${publicBaseURL.replace(/\/$/, "")}/assets/${id}`;
  const manifest = {
    id,
    createdAt: new Date().toISOString(),
    xiaohongshu: { images: postFiles.map((file) => `${base}/${file}`), ...safe.plan.xiaohongshu },
    douyin: { video: `${base}/${videoFile}`, ...safe.plan.douyin }
  };
  await writeFile(path.join(folder, "manifest.json"), JSON.stringify(manifest, null, 2));
  return manifest;
}

function run(command, args) {
  return new Promise((resolve, reject) => {
    const child = spawn(command, args, { stdio: ["ignore", "ignore", "pipe"] });
    let error = "";
    child.stderr.on("data", (chunk) => { error += chunk.toString(); });
    child.on("error", reject);
    child.on("close", (code) => code === 0 ? resolve() : reject(new Error(`${path.basename(command)} 失败：${error.slice(-600)}`)));
  });
}

async function screenshot(bin, html, png, width, height) {
  await run(bin, ["--headless", "--no-sandbox", "--disable-gpu", "--hide-scrollbars", `--window-size=${width},${height}`, `--screenshot=${png}`, `file://${html}`]);
}

async function video(bin, images, output) {
  const concat = images.flatMap((file) => ["-loop", "1", "-t", "2.5", "-i", file]);
  const filters = images.map((_, i) => `[${i}:v]scale=1080:1920,setsar=1[v${i}]`).join(";") + ";" + images.map((_, i) => `[v${i}]`).join("") + `concat=n=${images.length}:v=1:a=0,format=yuv420p[v]`;
  await run(bin, ["-y", ...concat, "-filter_complex", filters, "-map", "[v]", "-r", "30", "-c:v", "libx264", "-movflags", "+faststart", output]);
}

function escape(value) {
  return String(value ?? "").replace(/[&<>\"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", "\"": "&quot;", "'": "&#39;" })[c]);
}
function pace(seconds) {
  const total = Math.round(seconds); return `${Math.floor(total / 60)}'${String(total % 60).padStart(2, "0")}\"`;
}
function clock(seconds) {
  const total = Math.round(seconds); const h = Math.floor(total / 3600); const m = Math.floor(total % 3600 / 60); const s = total % 60;
  return h ? `${h}:${String(m).padStart(2,"0")}:${String(s).padStart(2,"0")}` : `${String(m).padStart(2,"0")}:${String(s).padStart(2,"0")}`;
}
function cardHTML(data, kind, index, format) {
  const w = data.workout; const p = data.plan; const story = format === "story";
  const date = new Intl.DateTimeFormat("zh-CN", { month: "numeric", day: "numeric", timeZone: "Asia/Shanghai" }).format(new Date(w.startedAt));
  const splitRows = w.splits.slice(0, story ? 10 : 8).map((s) => {
    const times = w.splits.map(x => x.durationSeconds); const min = Math.min(...times); const max = Math.max(...times); const ratio = max === min ? 85 : 65 + (max - s.durationSeconds) / (max - min) * 35;
    return `<div class="split"><b>${String(s.kilometer).padStart(2,"0")} KM</b><i style="width:${ratio}%"></i><strong>${pace(s.durationSeconds)}</strong></div>`;
  }).join("");
  const content = {
    cover: `<div class="spacer"></div><h1>${escape(p.cards.cover)}</h1><div class="distance">${w.distanceKilometers.toFixed(2)}</div><div class="unit">KILOMETERS</div><div class="metrics"><div><small>用时</small><b>${clock(w.durationSeconds)}</b></div><div><small>平均配速</small><b>${pace(w.averagePaceSeconds)} /km</b></div></div>`,
    splits: `<label>SPLITS</label><h1>每一公里，<br>都有自己的脾气</h1><div class="splits">${splitRows || "<p>本次没有公里分段数据</p>"}</div>`,
    heart: `<label>HEART RATE</label><h1>这次跑步的<br>心率摘要</h1><div class="heart"><strong>${w.averageHeartRate ?? "--"}</strong><span>BPM 平均</span></div><div class="pulse">${Array.from({length: 22}, (_, i) => `<i style="height:${25 + ((i * 17) % 70)}%"></i>`).join("")}</div><div class="metrics"><div><small>最高心率</small><b>${w.maximumHeartRate ? `${w.maximumHeartRate} BPM` : "--"}</b></div><div><small>活动能量</small><b>${w.activeEnergyKcal ? `${Math.round(w.activeEnergyKcal)} KCAL` : "--"}</b></div></div>`,
    finish: `<label>RUN NOTE</label><h1>跑完以后，<br>数字才开始说话</h1><p class="closing">${escape(p.cards.closing)}</p><div class="spacer"></div><div class="tags"><span>${pace(w.averagePaceSeconds)}/km</span>${w.averageHeartRate ? `<span>${w.averageHeartRate} bpm</span>` : ""}</div><div class="bars"><i></i><b></b></div>`
  }[kind];
  return `<!doctype html><html><head><meta charset="utf-8"><style>
  *{box-sizing:border-box}html,body{margin:0;width:${story?1080:1080}px;height:${story?1920:1440}px;overflow:hidden}body{background:#f6f1e7;color:#172d2a;font-family:"WenQuanYi Zen Hei","Noto Sans CJK SC",sans-serif}.card{height:100%;padding:${story?102:84}px;display:flex;flex-direction:column}.head{display:flex;align-items:center;gap:28px;font-family:monospace;font-weight:800;font-size:30px;letter-spacing:3px;border-bottom:6px solid #dce7df;padding-bottom:30px}.head .dot{margin-left:auto;width:24px;height:24px;border-radius:50%;background:#f26b4d}.content{display:flex;flex:1;flex-direction:column;padding-top:${story?85:60}px}.spacer{flex:1}h1{font-size:${story?112:94}px;line-height:1.12;margin:18px 0 36px;font-weight:900;letter-spacing:-5px;white-space:pre-line}.distance{font-size:${story?250:210}px;line-height:1;font-weight:900;color:#087f6b;letter-spacing:-12px}.unit,label{font-family:monospace;font-size:32px;font-weight:800;letter-spacing:8px;color:#f26b4d}.metrics{display:flex;gap:100px;margin-top:55px}.metrics div{display:flex;flex-direction:column;gap:10px}.metrics small{font-size:28px;color:#64736f}.metrics b{font:700 46px monospace}.splits{margin-top:36px}.split{height:${story?105:82}px;display:grid;grid-template-columns:150px 1fr 145px;align-items:center;gap:25px}.split b{font:700 28px monospace;color:#64736f}.split strong{font:800 37px monospace}.split i{height:20px;background:#087f6b;border-radius:20px}.split:first-child i{background:#f26b4d}.heart{display:flex;align-items:baseline;gap:24px;margin-top:35px}.heart strong{font-size:180px;line-height:1;color:#f26b4d}.heart span{font:700 30px monospace;color:#64736f}.pulse{height:${story?420:285}px;display:flex;align-items:center;gap:14px;border-block:3px solid #dce7df;margin:45px 0 10px}.pulse i{width:26px;min-height:20px;background:#f26b4d;border-radius:14px}.closing{font-size:${story?72:62}px;line-height:1.55;font-weight:700;margin-top:55px}.tags{display:flex;gap:24px}.tags span{font:700 32px monospace;color:#087f6b;background:#dce7df;padding:18px 28px;border-radius:40px}.bars{margin-top:45px}.bars i,.bars b{display:block;height:25px}.bars i{background:#087f6b}.bars b{background:#f26b4d;width:28%;margin-top:16px}.foot{display:flex;font-size:25px;font-weight:700;color:#64736f;letter-spacing:2px}.foot span:last-child{margin-left:auto}
  </style></head><body><main class="card"><header class="head"><span>${escape(date)}</span><span>RUN / ${index+1}–4</span><i class="dot"></i></header><section class="content">${content}</section><footer class="foot"><span>RUN TAPE</span><span>由我的 Apple Watch 记录</span></footer></main></body></html>`;
}
