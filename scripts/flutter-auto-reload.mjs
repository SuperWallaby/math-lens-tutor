#!/usr/bin/env node
/**
 * flutter run --pid-file 과 함께 사용.
 * lib/*.dart 저장 감지 → SIGUSR1 hot reload (기본 2초 throttle).
 * main.dart / pubspec / assets 변경 → SIGUSR2 hot restart.
 *
 * macOS + Cursor 저장은 fs.watch 가 놓치는 경우가 많아 폴링을 기본으로 씀.
 */
import { existsSync, readdirSync, readFileSync, statSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const FLUTTER_DIR = path.join(ROOT, "flutter_app");
const FLUTTER_LIB = path.join(FLUTTER_DIR, "lib");
const PID_FILE =
  process.env.FLUTTER_PID_FILE || path.join(ROOT, ".flutter-run.pid");
const THROTTLE_MS = Number(process.env.FLUTTER_RELOAD_THROTTLE_MS || 2_000);
const POLL_MS = Number(process.env.FLUTTER_RELOAD_POLL_MS || 1_000);
const MODE = (process.env.FLUTTER_AUTO_RELOAD_MODE || "auto").toLowerCase();

let lastReloadAt = 0;
let scheduledTimer = null;
let pendingKind = null;
let watching = false;
const mtimes = new Map();

function readPid() {
  if (!existsSync(PID_FILE)) return null;
  const pid = readFileSync(PID_FILE, "utf8").trim();
  if (!/^\d+$/.test(pid)) return null;
  return Number(pid);
}

function isAlive(pid) {
  try {
    process.kill(pid, 0);
    return true;
  } catch {
    return false;
  }
}

function walkFiles(dir, matcher, out = []) {
  if (!existsSync(dir)) return out;
  for (const entry of readdirSync(dir, { withFileTypes: true })) {
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      walkFiles(full, matcher, out);
    } else if (matcher(full)) {
      out.push(full);
    }
  }
  return out;
}

function watchedFiles() {
  const dart = walkFiles(FLUTTER_LIB, (p) => p.endsWith(".dart"));
  const extras = [
    path.join(FLUTTER_DIR, "pubspec.yaml"),
    path.join(FLUTTER_DIR, "pubspec.lock"),
  ].filter((p) => existsSync(p));
  const assets = walkFiles(
    path.join(FLUTTER_DIR, "assets"),
    () => true,
  );
  return [...dart, ...extras, ...assets];
}

function needsRestart(changedPaths) {
  return changedPaths.some((file) => {
    const rel = path.relative(FLUTTER_DIR, file);
    return (
      rel === "pubspec.yaml" ||
      rel === "pubspec.lock" ||
      rel.startsWith(`assets${path.sep}`) ||
      rel === path.join("lib", "main.dart")
    );
  });
}

function sendSignal(restart, reason) {
  const pid = readPid();
  if (!pid) {
    console.warn("[flutter-watch] skip — pid file missing (flutter still starting?)");
    return false;
  }
  if (!isAlive(pid)) {
    console.warn(`[flutter-watch] skip — pid ${pid} not running`);
    return false;
  }

  const signal = restart ? "SIGUSR2" : "SIGUSR1";
  const label = restart ? "hot restart (R)" : "hot reload (r)";

  try {
    process.kill(pid, signal);
    lastReloadAt = Date.now();
    pendingKind = null;
    console.log(`[flutter-watch] ${label} (${reason}) → pid ${pid}`);
    return true;
  } catch (error) {
    console.warn(`[flutter-watch] ${label} failed: ${error.message}`);
    return false;
  }
}

function flushPending() {
  scheduledTimer = null;
  if (!pendingKind) return;
  sendSignal(pendingKind === "restart", "save (throttled)");
}

function queueReload(changedPaths, reason) {
  if (!watching) return;

  const restart =
    MODE === "restart" ||
    (MODE === "auto" && needsRestart(changedPaths));

  pendingKind = restart ? "restart" : "reload";

  const now = Date.now();
  const sinceLast = now - lastReloadAt;

  if (sinceLast >= THROTTLE_MS) {
    sendSignal(restart, reason);
    return;
  }

  if (scheduledTimer) return;
  scheduledTimer = setTimeout(flushPending, THROTTLE_MS - sinceLast);
}

function scanChanges() {
  const changed = [];
  for (const file of watchedFiles()) {
    let mtime;
    try {
      mtime = statSync(file).mtimeMs;
    } catch {
      continue;
    }
    const prev = mtimes.get(file);
    if (prev === undefined) {
      mtimes.set(file, mtime);
      continue;
    }
    if (mtime > prev) {
      mtimes.set(file, mtime);
      changed.push(file);
    }
  }
  return changed;
}

function startWatching() {
  if (watching) return;
  watching = true;

  for (const file of watchedFiles()) {
    try {
      mtimes.set(file, statSync(file).mtimeMs);
    } catch {
      // ignore
    }
  }

  const pid = readPid();
  console.log(
    `[flutter-watch] ready — pid ${pid}, poll ${POLL_MS}ms, throttle ${THROTTLE_MS}ms, mode ${MODE}`,
  );
  console.log("[flutter-watch] lib/*.dart → r | main/pubspec/assets → R");

  setInterval(() => {
    if (!readPid() || !isAlive(readPid())) return;
    const changed = scanChanges();
    if (changed.length === 0) return;
    const names = changed
      .map((f) => path.relative(ROOT, f))
      .slice(0, 3)
      .join(", ");
    queueReload(changed, `save: ${names}`);
  }, POLL_MS);
}

function waitForPidFile() {
  if (readPid() && isAlive(readPid())) {
    startWatching();
    return;
  }

  const interval = setInterval(() => {
    const pid = readPid();
    if (pid && isAlive(pid)) {
      clearInterval(interval);
      startWatching();
    }
  }, 400);
}

waitForPidFile();
