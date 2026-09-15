import http from "node:http";
import { createReadStream } from "node:fs";
import { readFile, stat } from "node:fs/promises";
import path from "node:path";
import crypto from "node:crypto";
import { renderPackage } from "./render.js";

const port = Number(process.env.PORT ?? 3216);
const token = process.env.APPLEFLEETS_API_TOKEN ?? "";
const outputRoot = process.env.OUTPUT_DIR ?? path.resolve("output");
const publicBaseURL = process.env.PUBLIC_BASE_URL ?? `http://127.0.0.1:${port}`;
if (token.length < 32) throw new Error("APPLEFLEETS_API_TOKEN 至少需要 32 个字符");

const server = http.createServer(async (req, res) => {
  try {
    const url = new URL(req.url, `http://${req.headers.host ?? "localhost"}`);
    if (req.method === "GET" && url.pathname === "/health") return json(res, 200, { status: "ok" });
    if (!authorized(req)) return json(res, 401, { error: { message: "连接令牌不正确" } });
    if (req.method === "POST" && url.pathname === "/renders") {
      const body = await readJSON(req);
      const id = safeID(body.id) || `render_${crypto.randomUUID().replaceAll("-", "")}`;
      try {
        const existing = await readFile(path.join(outputRoot, id, "manifest.json"), "utf8");
        return raw(res, 200, "application/json; charset=utf-8", existing);
      } catch (error) {
        if (error?.code !== "ENOENT") throw error;
      }
      const manifest = await renderPackage({ id, payload: body, outputRoot, chromiumBin: process.env.CHROMIUM_BIN ?? "/usr/bin/chromium", ffmpegBin: process.env.FFMPEG_BIN ?? "/usr/bin/ffmpeg", publicBaseURL });
      return json(res, 201, manifest);
    }
    if (req.method === "GET" && url.pathname.startsWith("/renders/")) {
      const id = safeID(url.pathname.split("/")[2]);
      if (!id) return json(res, 404, { error: { message: "文件不存在" } });
      const data = await readFile(path.join(outputRoot, id, "manifest.json"), "utf8");
      return raw(res, 200, "application/json; charset=utf-8", data);
    }
    if (req.method === "GET" && url.pathname.startsWith("/assets/")) return asset(res, url.pathname);
    return json(res, 404, { error: { message: "接口不存在" } });
  } catch (error) {
    const status = error?.code === "ENOENT" ? 404 : 400;
    return json(res, status, { error: { message: error instanceof Error ? error.message : "生成失败" } });
  }
});

function authorized(req) {
  const supplied = req.headers.authorization?.replace(/^Bearer\s+/i, "") ?? "";
  if (supplied.length !== token.length) return false;
  return crypto.timingSafeEqual(Buffer.from(supplied), Buffer.from(token));
}
function safeID(value) { return typeof value === "string" && /^[a-zA-Z0-9_-]{8,100}$/.test(value) ? value : null; }
async function readJSON(req) {
  const chunks = []; let bytes = 0;
  for await (const chunk of req) { bytes += chunk.length; if (bytes > 128 * 1024) throw new Error("请求内容过大"); chunks.push(chunk); }
  return JSON.parse(Buffer.concat(chunks).toString("utf8"));
}
async function asset(res, pathname) {
  const parts = pathname.split("/").filter(Boolean); const id = safeID(parts[1]); const file = parts[2];
  if (!id || !/^(xiaohongshu-[1-4]|douyin-[1-4])\.png$|^douyin-vertical\.mp4$/.test(file ?? "")) return json(res, 404, { error: { message: "文件不存在" } });
  const full = path.join(outputRoot, id, file); const info = await stat(full);
  res.writeHead(200, { "Content-Type": file.endsWith(".mp4") ? "video/mp4" : "image/png", "Content-Length": info.size, "Cache-Control": "private, max-age=86400" });
  createReadStream(full).pipe(res);
}
function json(res, status, value) { raw(res, status, "application/json; charset=utf-8", JSON.stringify(value)); }
function raw(res, status, contentType, body) { res.writeHead(status, { "Content-Type": contentType, "Content-Length": Buffer.byteLength(body) }); res.end(body); }

server.listen(port, "0.0.0.0", () => console.log(`AppleFleets renderer listening on ${port}`));
