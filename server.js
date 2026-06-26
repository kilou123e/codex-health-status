import { createServer } from "node:http";
import { readFile } from "node:fs/promises";
import { extname, join } from "node:path";
import { execFile, spawn } from "node:child_process";
import { homedir } from "node:os";
import { URL } from "node:url";

const HOST = "127.0.0.1";
const UI_PORT = Number(process.env.PORT || 3333);
const APP_SERVER_PORT = Number(process.env.CODEX_APP_SERVER_PORT || 47891);
const CODEX_BIN = process.env.CODEX_BIN || "codex";
const REFRESH_MS = Number(process.env.REFRESH_MS || 30_000);
const ACTIVITY_POLL_MS = Number(process.env.ACTIVITY_POLL_MS || 2_000);
const ACTIVITY_ACTIVE_MS = Number(process.env.ACTIVITY_ACTIVE_MS || 45_000);
const CODEX_HOME = process.env.CODEX_HOME || join(process.env.HOME || homedir(), ".codex");
const STATE_DB = process.env.CODEX_STATE_DB || join(CODEX_HOME, "state_5.sqlite");
const SQLITE_BIN = process.env.SQLITE_BIN || "/usr/bin/sqlite3";

const root = new URL(".", import.meta.url).pathname;
const publicDir = join(root, "public");

let codexProcess = null;
let ws = null;
let nextId = 1;
let initialized = false;
let reconnectTimer = null;
let refreshTimer = null;
let activityTimer = null;
const activeTurnIds = new Set();
const activeThreadIds = new Set();
let lastSnapshot = {
  status: "starting",
  updatedAt: null,
  error: null,
  data: null,
  busy: false,
  activeTurns: 0,
  activeThreads: 0,
  activityDebug: null,
  appServerUrl: `ws://${HOST}:${APP_SERVER_PORT}`,
};
const pending = new Map();
const clients = new Set();

function startCodexAppServer() {
  if (codexProcess) return;

  codexProcess = spawn(
    CODEX_BIN,
    ["app-server", "--listen", `ws://${HOST}:${APP_SERVER_PORT}`],
    { stdio: ["ignore", "ignore", "pipe"] },
  );

  codexProcess.stderr.on("data", (chunk) => {
    const text = chunk.toString();
    if (text.includes("Address already in use")) {
      return;
    }
  });

  codexProcess.on("exit", (code, signal) => {
    codexProcess = null;
    if (ws && ws.readyState === WebSocket.OPEN) {
      return;
    }
    initialized = false;
    setError(`codex app-server exited${code === null ? "" : ` with code ${code}`}${signal ? ` (${signal})` : ""}.`);
    scheduleReconnect();
  });
}

function connectToCodex() {
  clearTimeout(reconnectTimer);
  reconnectTimer = null;

  if (ws && (ws.readyState === WebSocket.OPEN || ws.readyState === WebSocket.CONNECTING)) {
    return;
  }

  try {
    ws = new WebSocket(`ws://${HOST}:${APP_SERVER_PORT}`);
  } catch (error) {
    setError(error.message);
    scheduleReconnect();
    return;
  }

  ws.addEventListener("open", async () => {
    try {
      await request("initialize", {
        clientInfo: { name: "codex-usage-status", version: "0.1.0" },
        capabilities: {
          experimentalApi: false,
          requestAttestation: false,
          optOutNotificationMethods: [
            "thread/started",
            "item/started",
            "item/completed",
            "command/exec/outputDelta",
            "process/outputDelta",
          ],
        },
      });
      notify("initialized");
      initialized = true;
      lastSnapshot = { ...lastSnapshot, status: "connected", error: null };
      broadcast();
      await refreshRateLimits();
      startRefreshLoop();
      startActivityLoop();
    } catch (error) {
      setError(error.message);
    }
  });

  ws.addEventListener("message", (event) => {
    const raw = typeof event.data === "string" ? event.data : Buffer.from(event.data).toString();
    let message;
    try {
      message = JSON.parse(raw);
    } catch {
      return;
    }

    if ("id" in message) {
      const waiting = pending.get(message.id);
      if (!waiting) return;
      pending.delete(message.id);
      if (message.error) waiting.reject(new Error(message.error.message || JSON.stringify(message.error)));
      else waiting.resolve(message.result);
      return;
    }

    if (message.method === "turn/started") {
      const turnId = message.params?.turn?.id;
      if (turnId) activeTurnIds.add(turnId);
      updateBusyState();
      return;
    }

    if (message.method === "turn/completed") {
      const turnId = message.params?.turn?.id;
      if (turnId) activeTurnIds.delete(turnId);
      updateBusyState();
      return;
    }

    if (message.method === "thread/status/changed") {
      const threadId = message.params?.threadId;
      const statusType = message.params?.status?.type;
      if (threadId && statusType === "active") activeThreadIds.add(threadId);
      if (threadId && statusType !== "active") activeThreadIds.delete(threadId);
      updateBusyState();
      return;
    }

    if (message.method === "account/rateLimits/updated" && message.params?.rateLimits) {
      const existing = lastSnapshot.data ?? {};
      lastSnapshot = {
        ...lastSnapshot,
        status: "connected",
        updatedAt: new Date().toISOString(),
        error: null,
        busy: isBusy(),
        activeTurns: activeTurnIds.size,
        activeThreads: activeThreadIds.size,
        data: {
          ...existing,
          rateLimits: { ...(existing.rateLimits ?? {}), ...message.params.rateLimits },
        },
      };
      broadcast();
    }
  });

  ws.addEventListener("close", () => {
    initialized = false;
    stopRefreshLoop();
    stopActivityLoop();
    rejectPending(new Error("Codex app-server connection closed."));
    scheduleReconnect();
  });

  ws.addEventListener("error", () => {
    setError("Could not connect to Codex app-server yet.");
  });
}

function scheduleReconnect() {
  if (reconnectTimer) return;
  reconnectTimer = setTimeout(() => {
    startCodexAppServer();
    connectToCodex();
  }, 2000);
}

function startRefreshLoop() {
  stopRefreshLoop();
  refreshTimer = setInterval(refreshRateLimits, REFRESH_MS);
}

function stopRefreshLoop() {
  if (refreshTimer) clearInterval(refreshTimer);
  refreshTimer = null;
}

function startActivityLoop() {
  stopActivityLoop();
  pollRecentActivity();
  activityTimer = setInterval(pollRecentActivity, ACTIVITY_POLL_MS);
}

function stopActivityLoop() {
  if (activityTimer) clearInterval(activityTimer);
  activityTimer = null;
}

function request(method, params) {
  if (!ws || ws.readyState !== WebSocket.OPEN) {
    return Promise.reject(new Error("Codex app-server is not connected."));
  }

  const id = nextId++;
  const payload = params === undefined ? { id, method } : { id, method, params };
  ws.send(JSON.stringify(payload));

  return new Promise((resolve, reject) => {
    pending.set(id, { resolve, reject });
    setTimeout(() => {
      if (!pending.has(id)) return;
      pending.delete(id);
      reject(new Error(`${method} timed out.`));
    }, 10_000);
  });
}

function notify(method, params) {
  if (!ws || ws.readyState !== WebSocket.OPEN) return;
  ws.send(JSON.stringify(params === undefined ? { method } : { method, params }));
}

async function refreshRateLimits() {
  if (!initialized) return;
  try {
    const data = await request("account/rateLimits/read");
    lastSnapshot = {
      ...lastSnapshot,
      status: "connected",
      updatedAt: new Date().toISOString(),
      error: null,
      busy: isBusy(),
      activeTurns: activeTurnIds.size,
      activeThreads: activeThreadIds.size,
      data,
    };
    broadcast();
  } catch (error) {
    setError(error.message);
  }
}

function setError(error) {
  lastSnapshot = {
    ...lastSnapshot,
    status: "error",
    updatedAt: new Date().toISOString(),
    error,
    busy: isBusy(),
    activeTurns: activeTurnIds.size,
    activeThreads: activeThreadIds.size,
  };
  broadcast();
}

function updateBusyState() {
  lastSnapshot = {
    ...lastSnapshot,
    status: initialized ? "connected" : lastSnapshot.status,
    updatedAt: new Date().toISOString(),
    busy: isBusy(),
    activeTurns: activeTurnIds.size,
    activeThreads: activeThreadIds.size,
  };
  broadcast();
}

function isBusy() {
  return activeTurnIds.size > 0 || activeThreadIds.size > 0;
}

function pollRecentActivity() {
  execFile(
    SQLITE_BIN,
    [
      STATE_DB,
      "select max(updated_at_ms) from threads where archived = 0;",
    ],
    { timeout: 1500 },
    (error, stdout) => {
      if (error) {
        lastSnapshot = {
          ...lastSnapshot,
          activityDebug: { ok: false, error: error.message, checkedAt: new Date().toISOString() },
        };
        broadcast();
        return;
      }
      const latest = Number(String(stdout).trim());
      if (!Number.isFinite(latest) || latest <= 0) return;
      const age = Date.now() - latest;
      const active = age >= 0 && age <= ACTIVITY_ACTIVE_MS;
      const hadPollingThread = activeThreadIds.has("__sqlite_recent_activity__");
      if (active) activeThreadIds.add("__sqlite_recent_activity__");
      else activeThreadIds.delete("__sqlite_recent_activity__");
      lastSnapshot = {
        ...lastSnapshot,
        activityDebug: { ok: true, latest, age, active, checkedAt: new Date().toISOString() },
      };
      if (hadPollingThread !== active) updateBusyState();
      else broadcast();
    },
  );
}

function rejectPending(error) {
  for (const { reject } of pending.values()) reject(error);
  pending.clear();
}

function broadcast() {
  const payload = `data: ${JSON.stringify(lastSnapshot)}\n\n`;
  for (const res of clients) res.write(payload);
}

function contentType(file) {
  switch (extname(file)) {
    case ".html": return "text/html; charset=utf-8";
    case ".css": return "text/css; charset=utf-8";
    case ".js": return "text/javascript; charset=utf-8";
    case ".json": return "application/json; charset=utf-8";
    default: return "application/octet-stream";
  }
}

const server = createServer(async (req, res) => {
  const url = new URL(req.url, `http://${req.headers.host}`);

  if (url.pathname === "/api/status") {
    res.writeHead(200, { "content-type": "application/json; charset=utf-8" });
    res.end(JSON.stringify(lastSnapshot));
    return;
  }

  if (url.pathname === "/api/events") {
    res.writeHead(200, {
      "content-type": "text/event-stream",
      "cache-control": "no-cache",
      connection: "keep-alive",
    });
    clients.add(res);
    res.write(`data: ${JSON.stringify(lastSnapshot)}\n\n`);
    req.on("close", () => clients.delete(res));
    return;
  }

  if (url.pathname === "/api/refresh") {
    await refreshRateLimits();
    res.writeHead(200, { "content-type": "application/json; charset=utf-8" });
    res.end(JSON.stringify(lastSnapshot));
    return;
  }

  const pathname = url.pathname === "/" ? "/index.html" : url.pathname;
  const filePath = join(publicDir, pathname);
  if (!filePath.startsWith(publicDir)) {
    res.writeHead(403);
    res.end("Forbidden");
    return;
  }

  try {
    const body = await readFile(filePath);
    res.writeHead(200, { "content-type": contentType(filePath) });
    res.end(body);
  } catch {
    res.writeHead(404);
    res.end("Not found");
  }
});

server.listen(UI_PORT, HOST, () => {
  console.log(`Codex usage status: http://${HOST}:${UI_PORT}`);
  startCodexAppServer();
  setTimeout(connectToCodex, 500);
});

process.on("SIGINT", shutdown);
process.on("SIGTERM", shutdown);

function shutdown() {
  stopRefreshLoop();
  if (ws) ws.close();
  if (codexProcess) codexProcess.kill();
  process.exit(0);
}
