(() => {
  "use strict";

  const $ = (id) => document.getElementById(id);

  const ua = navigator.userAgent;
  const isIos =
    /iPad|iPhone|iPod/.test(ua) || (navigator.platform === "MacIntel" && navigator.maxTouchPoints > 1);
  const isAndroid = /Android/i.test(ua);
  // LINE、Facebook、微信等 App 內建瀏覽器：擋下載與 itms-services
  const isInAppBrowser = /Line\/|FBAN|FBAV|Instagram|MicroMessenger|MQQBrowser/i.test(ua);

  function formatSize(bytes) {
    return bytes >= 1024 * 1024
      ? `${(bytes / 1024 / 1024).toFixed(1)} MB`
      : `${Math.max(1, Math.round(bytes / 1024))} KB`;
  }

  function formatDate(iso) {
    const d = new Date(iso);
    const pad = (n) => String(n).padStart(2, "0");
    return `${d.getFullYear()}/${pad(d.getMonth() + 1)}/${pad(d.getDate())} ${pad(d.getHours())}:${pad(d.getMinutes())}`;
  }

  function describe(info, version) {
    return info.exists
      ? `v${version} · ${formatSize(info.size)} · 更新於 ${formatDate(info.updatedAt)}`
      : "尚未上傳安裝檔";
  }

  function enable(button, href) {
    button.href = href;
    button.removeAttribute("aria-disabled");
  }

  function showNotice(messages) {
    const box = $("notice");
    box.textContent = messages.join(" ");
    box.hidden = messages.length === 0;
  }

  /** 以目前網址產生 QR code（SVG，向量縮放不會模糊） */
  function renderQr(url) {
    $("qrUrl").textContent = url;
    try {
      qrcode.stringToBytes = qrcode.stringToBytesFuncs["UTF-8"]; // 預設編碼不是 UTF-8，含中文時會掃不出來
      const qr = qrcode(0, "M");
      qr.addData(url);
      qr.make();
      $("qrBox").innerHTML = qr.createSvgTag({ cellSize: 4, margin: 0, scalable: true });
    } catch (err) {
      $("qrBox").textContent = "無法產生 QR code";
      console.error(err);
    }
  }

  async function copyUrl(url, button) {
    const original = button.textContent;
    try {
      await navigator.clipboard.writeText(url);
      button.textContent = "已複製";
    } catch {
      // 非 https 或權限不足時改用 prompt，讓使用者手動複製
      window.prompt("請複製網址", url);
    }
    setTimeout(() => (button.textContent = original), 1500);
  }

  async function init() {
    const pageUrl = `${location.origin}/`;
    renderQr(pageUrl);
    $("btnCopy").addEventListener("click", () => copyUrl(pageUrl, $("btnCopy")));

    if (isIos) $("cardIos").classList.add("is-current");
    else if (isAndroid) $("cardAndroid").classList.add("is-current");

    let info;
    try {
      const res = await fetch("/api/info", { cache: "no-store" });
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      info = await res.json();
    } catch (err) {
      showNotice(["無法取得 App 資訊，請稍後重新整理。"]);
      $("androidMeta").textContent = "—";
      $("iosMeta").textContent = "—";
      console.error(err);
      return;
    }

    document.title = `${info.appName} 安裝`;
    $("appName").textContent = info.appName;
    $("appDesc").textContent = info.description || "";
    $("appVersion").textContent = `版本 ${info.version}（${info.build}）`;
    $("appVersion").hidden = false;

    const notices = [];
    if (isInAppBrowser) {
      notices.push(
        isIos
          ? "偵測到 App 內建瀏覽器，請點右上角選單改用 Safari 開啟。"
          : "偵測到 App 內建瀏覽器，請改用 Chrome 或系統瀏覽器開啟，否則可能無法下載。"
      );
    }

    // Android：直接下載 APK
    $("androidMeta").textContent = describe(info.android, info.version);
    if (info.android.exists) {
      enable($("btnAndroid"), `/files/${encodeURIComponent(info.android.name)}`);
      $("btnAndroid").setAttribute("download", info.android.name);
    }

    // iOS：未簽署 IPA，直接下載後用 Sideloadly 側載（不使用 itms-services）
    $("iosMeta").textContent = describe(info.ios, info.version);
    if (info.ios.exists) {
      enable($("btnIos"), `/files/${encodeURIComponent(info.ios.name)}`);
      $("btnIos").setAttribute("download", info.ios.name);
      if (isIos) {
        notices.push("iPhone 無法直接安裝此檔案，請在電腦下載 IPA 後用 Sideloadly 側載。");
      }
    }

    showNotice(notices);
  }

  init();
})();
