import test from "node:test";
import assert from "node:assert/strict";
import { validatePayload } from "../src/render.js";

test("accepts a sanitized workout and content plan", () => {
  const result = validatePayload({ workout: { startedAt: "2026-09-15T06:30:00Z", distanceKilometers: 5, durationSeconds: 1500, averagePaceSeconds: 300, splits: [] }, plan: { xiaohongshu: { title: "标题", body: "正文", hashtags: [] }, douyin: { title: "标题", body: "正文", hashtags: [] }, cards: { cover: "封面", closing: "结尾" } } });
  assert.equal(result.workout.distanceKilometers, 5);
  assert.equal(result.plan.cards.cover, "封面");
});

test("rejects invalid workout metrics", () => {
  assert.throws(() => validatePayload({ workout: { distanceKilometers: -1 }, plan: {} }), /缺少|无效/);
});
