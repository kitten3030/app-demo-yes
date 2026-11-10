// App 安裝頁伺服器（無第三方套件，只需 Node.js 18+）
//
//   node server.js
//
// 提供：
//   /                  安裝頁（public/index.html）
//   /api/info          App 資訊與 apk / ipa 是否存在（給安裝頁使用）
//   /manifest.plist    iOS OTA 安裝用的 manifest，依「目前連線的網址」動態產生
//   /files/<檔名>      apk / ipa 下載（只開放 config.json 設定的兩個檔案）
//
// 為什麼 manifest.plist 要動態產生：itms-services 要求 manifest 內的 ipa 網址是
// 絕對的 https 網址，而 VS Code 連接埠轉送的網址每次都不同，靜態檔寫不死。

"use strict";

const http = require("node:http");
const fs = require("node:fs");
const path = require("node:path");

const ROOT = __dirname;
const PUBLIC_DIR = path.join(ROOT, "public");
const config = JSON.parse(fs.readFileSync(path.join(ROOT, "config.json"), "utf8"));
const PORT = Number(process.env.PORT) || config.port || 8080;

const MIME = {
  ".html": "text/html; charset=utf-8",
  ".css": "text/css; charset=utf-8",
  ".js": "text/javascript; charset=utf-8",
  ".json": "application/json; charset=utf-8",
  ".svg": "image/svg+xml",
  ".png": "image/png",
  ".ico": "image/x-icon",
  ".txt": "text/plain; charset=utf-8",
};

/** 可下載的檔案：網址上的檔名 → 實際路徑與標頭 */
const downloads = new Map();
function registerDownload(relPath, contentType) {
  if (!relPath) return;
  const abs = path.resolve(ROOT, relPath);
  downloads.set(path.basename(relPath), { abs, contentType });
}
registerDownload(config.android?.file, "application/vnd.android.package-archive");
registerDownload(config.ios?.file, "application/octet-stream");

/**
 * 取得對外網址（含 https），例如 https://xxxx-8080.asse.devtunnels.ms
 * 優先序：環境變數 PUBLIC_BASE_URL > 反向代理標頭 > 本機連線。
 * VS Code 連接埠轉送會帶 X-Forwarded-Proto / Host，不需額外設定。
 */
function getBaseUrl(req) {
  if (process.env.PUBLIC_BASE_URL) return process.env.PUBLIC_BASE_URL.replace(/\/+$/, "");
  const host = (req.headers["x-forwarded-host"] || req.headers.host || `localhost:${PORT}`)
    .toString()
    .split(",")[0]
    .trim();
  const proto = (req.headers["x-forwarded-proto"] || "http").toString().split(",")[0].trim();
  return `${proto}://${host}`;
}

function xmlEscape(value) {
  return String(value).replace(/[<>&'"]/g, (c) => `&#${c.charCodeAt(0)};`);
}

function buildManifest(baseUrl) {
  const ipaName = path.basename(config.ios.file);
  const ipaUrl = `${baseUrl}/files/${encodeURIComponent(ipaName)}`;
  return `<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>items</key>
  <array>
    <dict>
      <key>assets</key>
      <array>
        <dict>
          <key>kind</key>
          <string>software-package</string>
          <key>url</key>
          <string>${xmlEscape(ipaUrl)}</string>
        </dict>
      </array>
      <key>metadata</key>
      <dict>
        <key>bundle-identifier</key>
        <string>${xmlEscape(config.ios.bundleId)}</string>
        <key>bundle-version</key>
        <string>${xmlEscape(config.version)}</string>
        <key>kind</key>
        <string>software</string>
        <key>title</key>
        <string>${xmlEscape(config.appName)}</string>
      </dict>
    </dict>
  </array>
</dict>
</plist>
`;
}

function fileStat(relPath) {
  if (!relPath) return { exists: false };
  try {
    const st = fs.statSync(path.resolve(ROOT, relPath));
    if (!st.isFile()) return { exists: false };
    return {
      exists: true,
      name: path.basename(relPath),
      size: st.size,
      updatedAt: st.mtime.toISOString(),
    };
  } catch {
    return { exists: false };
  }
}

function send(res, status, body, headers = {}) {
  res.writeHead(status, { "Cache-Control": "no-store", ...headers });
  res.end(body);
}

function sendJson(res, data) {
  send(res, 200, JSON.stringify(data), { "Content-Type": MIME[".json"] });
}

/** 串流送檔，支援 Range（手機下載大檔中斷後可續傳） */
function streamFile(req, res, abs, headers) {
  fs.stat(abs, (err, st) => {
    if (err || !st.isFile()) return send(res, 404, "Not Found", { "Content-Type": MIME[".txt"] });

    let start = 0;
    let end = st.size - 1;
    let status = 200;
    const range = /^bytes=(\d*)-(\d*)$/.exec(req.headers.range || "");
    if (range && (range[1] || range[2])) {
      if (range[1]) {
        start = Number(range[1]);
        if (range[2]) end = Math.min(Number(range[2]), st.size - 1);
      } else {
        start = Math.max(st.size - Number(range[2]), 0); // bytes=-N：最後 N 個位元組
      }
      if (start > end || start >= st.size) {
        return send(res, 416, "Range Not Satisfiable", { "Content-Range": `bytes */${st.size}` });
      }
      status = 206;
    }

    res.writeHead(status, {
      ...headers,
      "Accept-Ranges": "bytes",
      "Content-Length": end - start + 1,
      ...(status === 206 ? { "Content-Range": `bytes ${start}-${end}/${st.size}` } : {}),
    });
    if (req.method === "HEAD") return res.end();
    fs.createReadStream(abs, { start, end }).pipe(res);
  });
}

const server = http.createServer((req, res) => {
  if (req.method !== "GET" && req.method !== "HEAD") {
    return send(res, 405, "Method Not Allowed", { "Content-Type": MIME[".txt"], Allow: "GET, HEAD" });
  }

  let pathname;
  try {
    pathname = decodeURIComponent(new URL(req.url, "http://localhost").pathname);
  } catch {
    return send(res, 400, "Bad Request", { "Content-Type": MIME[".txt"] });
  }

  if (pathname === "/api/info") {
    return sendJson(res, {
      appName: config.appName,
      description: config.description,
      version: config.version,
      build: config.build,
      baseUrl: getBaseUrl(req),
      android: { ...fileStat(config.android?.file), packageId: config.android?.packageId },
      ios: { ...fileStat(config.ios?.file), bundleId: config.ios?.bundleId },
    });
  }

  if (pathname === "/manifest.plist") {
    return send(res, 200, buildManifest(getBaseUrl(req)), {
      "Content-Type": "application/xml; charset=utf-8",
    });
  }

  if (pathname.startsWith("/files/")) {
    const entry = downloads.get(pathname.slice("/files/".length));
    if (!entry) return send(res, 404, "Not Found", { "Content-Type": MIME[".txt"] });
    return streamFile(req, res, entry.abs, {
      "Content-Type": entry.contentType,
      "Content-Disposition": `attachment; filename="${path.basename(entry.abs)}"`,
      "Cache-Control": "no-store",
    });
  }

  // 靜態檔（public/）；擋掉 .. 與 PUBLIC_DIR 之外的路徑
  const rel = pathname === "/" ? "/index.html" : pathname;
  const abs = path.normalize(path.join(PUBLIC_DIR, rel));
  if (abs !== PUBLIC_DIR && !abs.startsWith(PUBLIC_DIR + path.sep)) {
    return send(res, 403, "Forbidden", { "Content-Type": MIME[".txt"] });
  }
  streamFile(req, res, abs, {
    "Content-Type": MIME[path.extname(abs).toLowerCase()] || "application/octet-stream",
    "Cache-Control": "no-cache",
  });
});

server.listen(PORT, () => {
  console.log(`安裝頁已啟動：http://localhost:${PORT}`);
  for (const [label, p] of [
    ["Android", config.android?.file],
    ["iOS", config.ios?.file],
  ]) {
    console.log(`  ${label}：${fileStat(p).exists ? "已找到 " + p : "尚未放置 " + p}`);
  }
  console.log("在 VS Code「連接埠」面板轉送此埠，並把可見度設為「公開」後，用公開網址開啟。");
});
