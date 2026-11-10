// 掃描 QR code：相機即時掃描 + 從相簿選圖兩種方式，解碼用 jsQR（public/vendor/jsQR.js）。
// 掃到的內容一律以純文字顯示，只有 http(s) 網址才提供「開啟連結」，且需要使用者自己按。
(() => {
  "use strict";

  const $ = (id) => document.getElementById(id);

  const video = $("scanVideo");
  const canvas = $("scanCanvas");
  const ctx = canvas.getContext("2d", { willReadFrequently: true });

  const CAMERA_MAX_WIDTH = 640; // 相機畫面縮到這個寬度再解碼，速度與辨識率的折衷
  const IMAGE_MAX_SIDE = 1280; // 相簿圖片縮到這個邊長再解碼
  const SCAN_INTERVAL_MS = 120; // 約 8 fps，省電

  let stream = null;
  let timerId = 0;
  let scanning = false;
  let starting = false; // 正在等相機權限／影片開始播放
  let session = 0; // 每次 start / stop 遞增，用來辨識過期的非同步流程

  function setStatus(message) {
    $("scanStatus").textContent = message;
  }

  function describeCameraError(err) {
    switch (err && err.name) {
      case "NotAllowedError":
      case "SecurityError":
        return "沒有相機權限。請在瀏覽器設定允許使用相機，或改用「從相簿選擇圖片」。";
      case "NotFoundError":
      case "OverconstrainedError":
        return "找不到可用的相機。可以改用「從相簿選擇圖片」。";
      case "NotReadableError":
        return "相機正被其他 App 使用，請關閉後再試。";
      default:
        return "無法開啟相機，請改用「從相簿選擇圖片」。";
    }
  }

  function hideResult() {
    $("scanResult").hidden = true;
  }

  /** 顯示結果。內容只用 textContent，連結先驗證通訊協定才放進 href。 */
  function showResult(text) {
    $("scanText").textContent = text;
    const open = $("scanOpen");
    const warn = $("scanWarn");
    open.hidden = true;
    open.removeAttribute("href");
    warn.hidden = true;
    warn.textContent = "";

    let url = null;
    try {
      url = new URL(text.trim());
    } catch {
      /* 不是網址，維持純文字 */
    }

    if (url && (url.protocol === "https:" || url.protocol === "http:")) {
      open.href = url.href;
      open.hidden = false;
      if (url.protocol === "http:") {
        warn.textContent = "這個連結不是 https，傳輸內容不會加密，請確認來源可信。";
        warn.hidden = false;
      }
    } else {
      // 開頭像「xxx:」的內容（javascript:、itms-services:、WIFI:、tel: …）一律不提供開啟
      const scheme = /^\s*([a-z][a-z0-9+.-]*):/i.exec(text);
      if (scheme) {
        warn.textContent = `這不是網頁連結（開頭為「${scheme[1].toLowerCase()}:」），為了安全不提供直接開啟，請確認來源後自行處理。`;
        warn.hidden = false;
      }
    }

    $("scanResult").hidden = false;
    setStatus("掃描完成。");
    if (navigator.vibrate) navigator.vibrate(80);
  }

  function setScanningUi(on) {
    scanning = on;
    $("scanView").hidden = !on;
    $("btnScan").hidden = on;
    $("btnScanStop").hidden = !on;
  }

  function stop() {
    session++; // 讓還在等待中的 start() 知道自己已被取消
    starting = false;
    clearTimeout(timerId);
    timerId = 0;
    if (stream) {
      stream.getTracks().forEach((track) => track.stop());
      stream = null;
    }
    video.srcObject = null;
    setScanningUi(false);
  }

  function tick() {
    if (!scanning) return;
    // 固定間隔輪詢即可，不綁 requestAnimationFrame（分頁沒有焦點時 rAF 會被瀏覽器暫停）
    timerId = setTimeout(tick, SCAN_INTERVAL_MS);
    if (video.readyState < 2 || !video.videoWidth) return;

    const scale = Math.min(1, CAMERA_MAX_WIDTH / video.videoWidth);
    const width = Math.round(video.videoWidth * scale);
    const height = Math.round(video.videoHeight * scale);
    canvas.width = width;
    canvas.height = height;
    ctx.drawImage(video, 0, 0, width, height);

    const frame = ctx.getImageData(0, 0, width, height);
    const code = jsQR(frame.data, width, height, { inversionAttempts: "dontInvert" });
    if (code && code.data) {
      stop();
      showResult(code.data);
    }
  }

  async function start() {
    if (scanning || starting) return; // 開啟中再按一次不重複開
    hideResult();

    // getUserMedia 只能在 https 或 localhost 使用
    if (!window.isSecureContext || !navigator.mediaDevices || !navigator.mediaDevices.getUserMedia) {
      setStatus("目前的連線無法使用相機（需要 https）。請改用公開的 https 網址開啟本頁，或使用「從相簿選擇圖片」。");
      return;
    }

    setStatus("正在開啟相機…");
    starting = true;
    const mine = ++session;
    let opened = null;
    try {
      opened = await navigator.mediaDevices.getUserMedia({
        video: { facingMode: { ideal: "environment" } }, // 優先使用後鏡頭
        audio: false,
      });
      if (mine !== session) {
        // 等權限的期間已被停止：把剛拿到的鏡頭放掉就好
        opened.getTracks().forEach((track) => track.stop());
        return;
      }
      stream = opened;
      video.srcObject = opened;
      await video.play();
      if (mine !== session) return; // 播放前已被 stop() 清理過
    } catch (err) {
      if (mine !== session) {
        if (opened) opened.getTracks().forEach((track) => track.stop());
        return; // 已被取消，不顯示錯誤
      }
      stop();
      setStatus(describeCameraError(err));
      return;
    }
    starting = false;

    setScanningUi(true);
    setStatus("請把 QR code 放進畫面中。");
    timerId = setTimeout(tick, SCAN_INTERVAL_MS);
  }

  /** 從相簿選圖：縮圖後解碼，這個路徑不需要相機權限，也不需要 https */
  async function scanImageFile(file) {
    stop();
    hideResult();
    setStatus("正在辨識圖片…");

    let bitmap;
    try {
      bitmap = await createImageBitmap(file);
    } catch {
      setStatus("無法讀取這張圖片，請換一張。");
      return;
    }

    const scale = Math.min(1, IMAGE_MAX_SIDE / Math.max(bitmap.width, bitmap.height));
    const width = Math.max(1, Math.round(bitmap.width * scale));
    const height = Math.max(1, Math.round(bitmap.height * scale));
    canvas.width = width;
    canvas.height = height;
    ctx.drawImage(bitmap, 0, 0, width, height);
    if (bitmap.close) bitmap.close();

    const data = ctx.getImageData(0, 0, width, height);
    const code = jsQR(data.data, width, height, { inversionAttempts: "attemptBoth" });
    if (code && code.data) showResult(code.data);
    else setStatus("這張圖片裡找不到 QR code。");
  }

  async function copyResult() {
    const text = $("scanText").textContent;
    const button = $("scanCopy");
    const original = button.textContent;
    try {
      await navigator.clipboard.writeText(text);
      button.textContent = "已複製";
    } catch {
      window.prompt("請複製內容", text);
    }
    setTimeout(() => (button.textContent = original), 1500);
  }

  $("btnScan").addEventListener("click", start);
  $("btnScanStop").addEventListener("click", () => {
    stop();
    setStatus("已停止掃描。");
  });
  $("scanCopy").addEventListener("click", copyResult);
  $("scanImage").addEventListener("change", (event) => {
    const input = event.target;
    const file = input.files && input.files[0];
    if (file) scanImageFile(file);
    input.value = ""; // 允許連續選同一張圖
  });

  // 切到背景或離開頁面時一定要關相機，避免鏡頭燈一直亮著
  document.addEventListener("visibilitychange", () => {
    if (document.hidden && (scanning || starting)) {
      stop();
      setStatus("已暫停掃描，請重新開啟相機。");
    }
  });
  window.addEventListener("pagehide", stop);
})();
