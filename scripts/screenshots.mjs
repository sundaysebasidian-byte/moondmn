// Captures the playground with a local headless Chrome.
//
//   scripts/build-web.sh && node scripts/screenshots.mjs [out-dir]
//
// Serves web/dist on a free port, drives Chrome over the DevTools protocol and
// writes playground-light.png and playground-dark.png (default: docs/assets).
// Set CHROME to the browser binary when it is not in the usual macOS location.
import { spawn } from "node:child_process";
import { createServer } from "node:http";
import { mkdirSync, mkdtempSync, readFileSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, extname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const here = dirname(fileURLToPath(import.meta.url));
const dist = resolve(here, "../web/dist");
const out = resolve(process.argv[2] ?? resolve(here, "../docs/assets"));
const chrome = process.env.CHROME ?? "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome";
const types = { ".html": "text/html", ".js": "text/javascript", ".css": "text/css" };

mkdirSync(out, { recursive: true });
const server = createServer((req, res) => {
  const name = req.url === "/" ? "/index.html" : req.url.split("?")[0];
  try {
    res.writeHead(200, { "content-type": types[extname(name)] ?? "application/octet-stream" });
    res.end(readFileSync(join(dist, name)));
  } catch {
    res.writeHead(404).end();
  }
});
await new Promise((ok) => server.listen(0, "127.0.0.1", ok));
const url = `http://127.0.0.1:${server.address().port}/`;

const port = 9300 + Math.floor(Math.random() * 500);
const profile = mkdtempSync(join(tmpdir(), "moondmn-chrome-"));
const browser = spawn(chrome, [`--remote-debugging-port=${port}`, `--user-data-dir=${profile}`, "--headless=new", "--disable-gpu", "--hide-scrollbars", "about:blank"], { stdio: "ignore" });

async function target() {
  for (let i = 0; i < 50; i++) {
    try {
      const list = await (await fetch(`http://127.0.0.1:${port}/json`)).json();
      const page = list.find((item) => item.type === "page");
      if (page) return page.webSocketDebuggerUrl;
    } catch {}
    await new Promise((ok) => setTimeout(ok, 200));
  }
  throw new Error("Chrome did not start");
}

const socket = new WebSocket(await target());
await new Promise((ok) => socket.addEventListener("open", ok));
let id = 0;
const pending = new Map();
const problems = [];
socket.addEventListener("message", ({ data }) => {
  const message = JSON.parse(data);
  if (message.id && pending.has(message.id)) pending.get(message.id)(message);
  if (message.method === "Runtime.exceptionThrown") problems.push(message.params.exceptionDetails.exception?.description ?? "exception");
  if (message.method === "Log.entryAdded" && message.params.entry.level === "error") problems.push(message.params.entry.text);
});
const send = (method, params = {}) =>
  new Promise((ok) => {
    const n = ++id;
    pending.set(n, ok);
    socket.send(JSON.stringify({ id: n, method, params }));
  });
const wait = (ms) => new Promise((ok) => setTimeout(ok, ms));
const evaluate = (expression) => send("Runtime.evaluate", { expression, awaitPromise: true, returnByValue: true });

await send("Runtime.enable");
await send("Log.enable");
await send("Page.enable");
await send("Emulation.setDeviceMetricsOverride", { width: 1440, height: 900, deviceScaleFactor: 2, mobile: false });

async function shot(name) {
  const { result } = await send("Page.captureScreenshot", { format: "png" });
  writeFileSync(join(out, name), Buffer.from(result.data, "base64"));
  console.log(`wrote ${join(out, name)}`);
}

for (const theme of ["light", "dark"]) {
  await send("Page.navigate", { url });
  await wait(800);
  await evaluate(`localStorage.setItem("theme", "${theme}"); document.documentElement.dataset.theme = "${theme}";`);
  await wait(300);
  await shot(`playground-${theme}.png`);
}

if (process.env.EXTRA) {
  for (const example of ["Insurance", "Dates"]) {
    await evaluate(`[...document.querySelectorAll("#examples button")].find((b) => b.textContent === "${example}").click()`);
    await wait(500);
    await shot(`extra-${example.toLowerCase()}.png`);
  }
  await evaluate(`document.querySelector('[data-mode="feel"]').click()`);
  await wait(400);
  await shot("extra-feel.png");
}

browser.kill();
server.close();
if (problems.length) {
  console.error(`page errors:\n${problems.join("\n")}`);
  process.exitCode = 1;
}
