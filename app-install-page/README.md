# App 安裝頁

簡易的內部測試版安裝頁：Android 直接下載 APK，iOS 用 `itms-services` 安裝 IPA。頁面上有「分享本頁 QR code」讓別台手機掃描開啟，也能用相機「掃描別的 QR code」。

只需要 Node.js 18+，沒有任何 npm 套件要安裝。

本資料夾放在 `app-demo` 儲存庫內（`app-demo/app-install-page/`），因為它發佈的就是 `app-demo` 打包出來的 APK / IPA。

## 目錄

| 路徑                   | 說明                                                         |
| ---------------------- | ------------------------------------------------------------ |
| `server.js`            | 靜態檔、`/api/info`、動態 `manifest.plist`、apk/ipa 下載     |
| `config.json`          | App 名稱、版本、套件識別碼、apk/ipa 檔名、連接埠             |
| `public/`              | 安裝頁（`index.html`、`style.css`、`app.js` 安裝與分享 QR、`scan.js` 掃描 QR） |
| `public/vendor/`       | 內建不依賴 CDN：QR code 產生器 [qrcode-generator](https://github.com/kazuhikoarase/qrcode-generator)（MIT）、QR code 解碼器 [jsQR](https://github.com/cozmo/jsQR)（Apache-2.0） |
| `files/`               | 放 `app-release.apk`、`app-release.ipa`（已加入 `.gitignore`） |

## 使用

1. 把安裝檔放進 `files/`，檔名要和 `config.json` 的 `android.file`、`ios.file` 一致（預設 `app-release.apk`、`app-release.ipa`）。沒放的平台，按鈕會停用並顯示「尚未上傳安裝檔」。
2. 發行新版時更新 `config.json` 的 `version`、`build`（iOS 的 manifest 會用到）。
3. 啟動：

   ```bash
   node server.js
   ```

   預設連接埠 8080，可用 `PORT=9000 node server.js` 或改 `config.json` 的 `port`。
4. 在 VS Code 的「連接埠」面板轉送該埠，右鍵 → **連接埠可見度 → 公開**，用轉送出來的 `https://…` 網址開啟頁面（頁面底部的 QR code 就是這個網址）。

## 發行安裝檔

### Android

```powershell
powershell -ExecutionPolicy Bypass -File ..\scripts\build-apk.ps1
copy C:\dev\app-demo-yun-lin-yes\build\app\outputs\flutter-apk\app-release.apk files\app-release.apk
```

release 版目前以 debug 金鑰簽署，僅供內部測試。

### iOS（Codemagic 雲端打包，不需要 Mac）

`app-demo/codemagic.yaml` 已設定好 `ios-adhoc` workflow。一次性設定：

1. **Apple Developer 帳號**（付費，個人或公司）。到 [developer.apple.com](https://developer.apple.com/account) → Certificates, IDs & Profiles：
   - **Identifiers**：新增 App ID，Bundle ID 填 `tw.com.pst.yesAppDemo`（Explicit）。
   - **Devices**：註冊要測試的 iPhone UDID（最多 100 台）。UDID 可在 Mac Finder、或 iPhone 開 [get.udid.io](https://get.udid.io) 取得。
2. **App Store Connect API key**：[App Store Connect](https://appstoreconnect.apple.com/access/integrations/api) → 使用者與存取 → 整合 → App Store Connect API → 產生金鑰（權限選 **Admin** 或 **App Manager**），下載 `.p8`（只能下載一次），記下 Issuer ID 與 Key ID。
3. **Codemagic**：註冊並連到儲存庫（見下方注意事項）→ Teams → Integrations → Developer Portal → Connect，名稱填 `codemagic`，貼上 Issuer ID、Key ID 並上傳 `.p8`。
4. 在 Codemagic 的 app 頁選 `ios-adhoc` workflow → **Start new build**。Codemagic 會自動建立 ad-hoc 憑證與描述檔，不需自己準備 `.p12`。
5. 建置完成後下載 `.ipa`，複製成 `files/app-release.ipa`。

新增測試機後，要在 Apple Developer 註冊 UDID，再重跑一次 build（描述檔會自動更新）。

注意：儲存庫 remote 是內網 GitLab（`192.168.5.9`），Codemagic 雲端連不到。可選：把程式碼另推一份到 GitHub / GitLab.com / Bitbucket 私有庫給 Codemagic 使用，或在 Codemagic 用 ZIP/「Other」方式上傳原始碼。

### iOS（有 Mac 時）

在 Mac 上打包，匯出方式要選 **ad-hoc** 或 **enterprise**（App Store / development 匯出的 IPA 無法用 OTA 安裝）：

```bash
flutter build ipa --export-method ad-hoc
```

把產出的 `.ipa` 複製成 `files/app-release.ipa`。

- `config.json` 的 `ios.bundleId` 必須和 IPA 的 Bundle ID 一致（`app-demo` 目前是 `tw.com.pst.yesAppDemo`），否則 iOS 會安裝失敗。
- ad-hoc：安裝的 iPhone 的 UDID 必須已加入描述檔。enterprise 則沒有此限制。
- 第一次安裝後，到「設定 → 一般 → VPN 與裝置管理」信任開發者，App 才能開啟。

## iOS 安裝原理與限制

按鈕連結是：

```text
itms-services://?action=download-manifest&url=https://<公開網址>/manifest.plist
```

- iOS 要求 **manifest 與 IPA 都必須是有效憑證的 https 網址**。用 `http://localhost` 開啟時，iOS 按鈕會停用。
- `manifest.plist` 由 `server.js` 依目前連線的網址動態產生（讀 `X-Forwarded-Host`、`X-Forwarded-Proto`、`Host`），所以轉送網址每次不同也不用手動改。若走的是沒有帶這些標頭的反向代理，可指定固定網址：

  ```bash
  PUBLIC_BASE_URL=https://example.com node server.js
  ```
- 請用 **Safari** 開啟。LINE、Facebook、微信等 App 內建瀏覽器無法觸發安裝，頁面偵測到時會提示。

## 掃描 QR code

頁面的「掃描 QR code」區塊提供兩種方式，解碼都在手機瀏覽器本機完成，影像不會上傳到任何伺服器：

- **開啟相機掃描**：優先使用後鏡頭，掃到就自動停止並放掉相機。切到背景或離開頁面也會自動關閉相機。
- **從相簿選擇圖片**：不需要相機權限，也不需要 https，相機被拒絕或用 `http://localhost` 以外的 http 網址開啟時可以改用這個。

注意：

- 瀏覽器規定 **相機只能在 https 或 `localhost` 使用**，所以請用 VS Code 轉送出來的 `https://…` 公開網址開啟。第一次按下去會跳出相機權限詢問，要選「允許」；iOS 請用 Safari。
- 掃到的內容一律以**純文字**顯示。只有 `http(s)` 網址會出現「開啟連結」按鈕（需自己按；`http` 會多一行不加密警告），其他像 `javascript:`、`itms-services:`、`WIFI:` 開頭的內容只顯示、不提供開啟。
- 掃描解碼器是 jsQR，不是原生條碼掃描：光線太暗、反光或 QR code 太小時辨識率會下降，必要時靠近一點或改用相簿選圖。

## 疑難排解

| 現象 | 可能原因 |
| ---- | -------- |
| iOS 按鈕是灰的 | `files/` 沒有 IPA，或不是用 https 開啟頁面 |
| 點 iOS 安裝後出現「無法連接」 | 連接埠不是「公開」；或 `bundleId` 與 IPA 不符；或憑證無效 |
| iOS 安裝完成卻打不開 | 尚未在「VPN 與裝置管理」信任開發者；ad-hoc 的 UDID 未加入描述檔 |
| Android 下載後無法安裝 | 未允許該瀏覽器「安裝未知應用程式」；或手機上已有不同簽章的同套件 App，需先解除安裝 |
| 按「開啟相機掃描」顯示「需要 https」 | 不是用 https 開啟頁面，請改用公開的 https 網址 |
| 按「開啟相機掃描」顯示沒有權限 | 瀏覽器或系統已拒絕相機權限，到瀏覽器的網站設定重新允許；或改用「從相簿選擇圖片」 |
| 公開網址第一次開啟出現提示頁 | VS Code 連接埠轉送（dev tunnels）對瀏覽器的首次訪問可能顯示確認頁，按「繼續」即可 |

## 注意

- 這是內部測試用，公開連接埠等於任何知道網址的人都能下載安裝檔，測試完請關閉連接埠或把可見度改回私人。
- `files/` 內的安裝檔不進版控；`/files/` 只提供 `config.json` 指定的兩個檔名，其他路徑一律 404。
