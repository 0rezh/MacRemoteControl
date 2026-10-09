// Captures d'écran du README, au format iPhone 16 Pro, dans le mockup docs/mockup/iphone-16-pro.svg.
//
//   1. Lancer l'app Mac : ./scripts/build.sh && open "build/Mac Remote Control.app"
//   2. node scripts/screenshots.mjs  → docs/screenshots/*.png (un iPhone par capture + hero.png)
//
// Utilise Google Chrome sans fenêtre (profil temporaire, votre Chrome n'est pas touché).
// Rien n'est envoyé au Mac pendant les captures : la saisie est interceptée dans la page.
import { execFileSync, spawn } from "node:child_process";
import { mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

const ROOT = join(dirname(fileURLToPath(import.meta.url)), "..");
const OUT = join(ROOT, "docs/screenshots");
const MOCKUP = readFileSync(join(ROOT, "docs/mockup/iphone-16-pro.svg"), "utf8");
const CHROME = process.env.CHROME ?? "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome";
const PORT = 9333;
const TOKEN = execFileSync("defaults", ["read", "dev.lukas.macremote", "token"]).toString().trim();
const APP_URL = `http://127.0.0.1:8765/#t=${TOKEN}`;

/** Écran du mockup (1300 × 2642) : la capture y est placée, légèrement rognée en haut et en bas. */
const SCREEN = { left: 32, top: 22, width: 1236, height: 2598, radius: 188, cropTop: 20 };

/** Zones réservées de l'iPhone 16 Pro (Dynamic Island, barre du bas) et une app réaliste au premier plan. */
const STAGE = `(() => {
  const style = document.createElement("style");
  style.textContent = \`
    .screen { padding-top: 78px !important; padding-bottom: 103px !important; }
    .tab-bar { height: 83px !important; padding-bottom: 34px !important; }
    :root { --key: min(calc((var(--deck-width) - 2 * var(--deck-pad) - 2 * var(--gap)) / 3), calc((100dvh - 500px) / 3)) !important; }
    * { animation: none !important; transition: none !important; }
  \`;
  document.head.appendChild(style);
  const pin = () => {
    const title = document.querySelector(".large-title");
    const subtitle = document.querySelector(".subtitle");
    if (title && title.textContent !== "Safari") title.textContent = "Safari";
    if (subtitle && subtitle.textContent !== "Raccourcis navigateur") subtitle.textContent = "Raccourcis navigateur";
  };
  pin();
  new MutationObserver(pin).observe(document.body, { subtree: true, childList: true, characterData: true });
  const realSend = WebSocket.prototype.send;
  WebSocket.prototype.send = function (data) {
    if (!["text", "key", "modifiers"].includes(JSON.parse(data).type)) realSend.call(this, data);
  };
})()`;

const SHOTS = [
  { name: "touches-sombre", scheme: "dark", mode: "remote" },
  { name: "touches-clair", scheme: "light", mode: "remote" },
  {
    name: "clavier-sombre",
    scheme: "dark",
    mode: "remote",
    type: "Hunger Games",
    script: `document.querySelectorAll(".keycap--modifier")[4]
      .dispatchEvent(new PointerEvent("pointerdown", { bubbles: true, button: 0, pointerType: "touch" }))`,
  },
  {
    name: "trackpad-sombre",
    scheme: "dark",
    mode: "mouse",
    script: `(() => { const s = document.querySelector(".trackpad__surface");
      s.dataset.active = "single"; s.style.setProperty("--x", "62%"); s.style.setProperty("--y", "40%"); })()`,
  },
];
const HERO = ["clavier-sombre", "touches-sombre", "trackpad-sombre"];

/** Un iPhone : la capture sous l'écran, le mockup par-dessus (barre d'état en noir pour le mode clair). */
function phone(image, scheme) {
  return `<div class="phone ${scheme}">
    <div class="screen"><img src="${image}"></div>
    <div class="frame">${MOCKUP}</div>
  </div>`;
}

function page(content, padding) {
  return `<!doctype html><html><head><meta charset="utf-8"><style>
    html, body { margin: 0; background: transparent; }
    body { display: flex; gap: 140px; padding: ${padding}px; width: max-content; }
    .phone { position: relative; width: 1300px; height: 2642px; filter: drop-shadow(0 40px 60px rgba(0, 0, 0, 0.28)); }
    .screen {
      position: absolute; left: ${SCREEN.left}px; top: ${SCREEN.top}px;
      width: ${SCREEN.width}px; height: ${SCREEN.height}px;
      border-radius: ${SCREEN.radius}px; overflow: hidden; background: #000;
    }
    .screen img { display: block; width: 100%; margin-top: -${SCREEN.cropTop}px; }
    .frame { position: absolute; inset: 0; }
    .light .frame g[clip-path] [fill="white"] { fill: #000; }
    .light .frame g[clip-path] [stroke="white"] { stroke: #000; }
  </style></head><body>${content}</body></html>`;
}

const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

async function connect() {
  for (let attempt = 0; attempt < 50; attempt++) {
    try {
      const targets = await (await fetch(`http://127.0.0.1:${PORT}/json/list`)).json();
      const target = targets.find((candidate) => candidate.type === "page");
      if (target) return new WebSocket(target.webSocketDebuggerUrl);
    } catch {}
    await sleep(200);
  }
  throw new Error("Chrome ne répond pas");
}

const work = mkdtempSync(join(tmpdir(), "mac-remote-shots-"));
const chrome = spawn(CHROME, [
  "--headless=new",
  `--remote-debugging-port=${PORT}`,
  `--user-data-dir=${join(work, "profile")}`,
  "--no-first-run",
  "--no-default-browser-check",
  "--hide-scrollbars",
  "--allow-file-access-from-files",
  "about:blank",
]);

try {
  const socket = await connect();
  await new Promise((resolve) => socket.addEventListener("open", resolve, { once: true }));
  let nextId = 0;
  const pending = new Map();
  socket.addEventListener("message", (event) => {
    const message = JSON.parse(event.data);
    pending.get(message.id)?.(message);
    pending.delete(message.id);
  });
  const send = (method, params = {}) =>
    new Promise((resolve, reject) => {
      const id = ++nextId;
      pending.set(id, (message) => (message.error ? reject(new Error(message.error.message)) : resolve(message.result)));
      socket.send(JSON.stringify({ id, method, params }));
    });
  const evaluate = (expression) => send("Runtime.evaluate", { expression, awaitPromise: true });
  const capture = async (file) => {
    const { data } = await send("Page.captureScreenshot", { format: "png" });
    writeFileSync(file, Buffer.from(data, "base64"));
  };

  mkdirSync(OUT, { recursive: true });

  // 1. Captures de l'interface, à la résolution de l'iPhone 16 Pro (402 × 874 pt, ×3).
  await send("Emulation.setDeviceMetricsOverride", { width: 402, height: 874, deviceScaleFactor: 3, mobile: true });
  for (const shot of SHOTS) {
    await send("Emulation.setEmulatedMedia", { features: [{ name: "prefers-color-scheme", value: shot.scheme }] });
    await send("Page.navigate", { url: "about:blank" });
    await send("Page.navigate", { url: APP_URL });
    await sleep(800);
    await evaluate(`localStorage.setItem("macremote.mode", "${shot.mode}"); location.reload()`);
    await sleep(1800);
    await evaluate(STAGE);
    if (shot.type) {
      await evaluate(`document.querySelector(".type-area__input").focus()`);
      await send("Input.insertText", { text: shot.type });
    }
    if (shot.script) await evaluate(shot.script);
    await sleep(300);
    await capture(join(work, `${shot.name}.png`));
  }

  // 2. Chaque capture dans le mockup, puis l'image principale avec trois iPhone.
  await send("Emulation.setEmulatedMedia", { features: [] });
  await send("Emulation.setDefaultBackgroundColorOverride", { color: { r: 0, g: 0, b: 0, a: 0 } });
  const compose = async (name, html, width, height, scale) => {
    const file = join(work, `${name}.html`);
    writeFileSync(file, html);
    await send("Emulation.setDeviceMetricsOverride", { width, height, deviceScaleFactor: scale, mobile: false });
    await send("Page.navigate", { url: pathToFileURL(file).href });
    await sleep(700);
    await capture(join(OUT, `${name}.png`));
    console.log(`✓ docs/screenshots/${name}.png`);
  };

  const padding = 120;
  for (const shot of SHOTS) {
    const html = page(phone(`${shot.name}.png`, shot.scheme), padding);
    await compose(shot.name, html, 1300 + 2 * padding, 2642 + 2 * padding, 0.5);
  }
  const hero = page(HERO.map((name) => phone(`${name}.png`, "dark")).join(""), padding);
  await compose("hero", hero, HERO.length * 1300 + (HERO.length - 1) * 140 + 2 * padding, 2642 + 2 * padding, 0.36);

  socket.close();
} finally {
  chrome.kill();
  await sleep(300);
  rmSync(work, { recursive: true, force: true });
}
