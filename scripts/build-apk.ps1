<#
.SYNOPSIS
  將 app-demo 同步到純英文路徑後打包 Android APK。

.DESCRIPTION
  原始碼所在路徑含中文時，Gradle / Kotlin 編譯會失敗，因此打包固定在英文路徑進行：
    1. 以 robocopy 鏡像同步原始碼到 $Dest（排除 build、.dart_tool、.git、app-install-page，
       以及專案根目錄的 release/；目的地已存在的這些資料夾不會被刪除，可沿用編譯快取加快速度。
       release/ 是發行用的舊 APK，不參與打包，目的地若已有舊的 release/ 也不會被動到，可自行刪除）
    2. 在 $Dest 執行 flutter build apk
    3. 印出 APK 位置與大小

  注意：release 版目前以 debug 金鑰簽署（build.gradle 尚未設定正式簽章），僅供內部測試。

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File .\scripts\build-apk.ps1
  powershell -ExecutionPolicy Bypass -File .\scripts\build-apk.ps1 -Mode debug
#>
param(
  [ValidateSet('release', 'debug')]
  [string]$Mode = 'release',
  [string]$Dest = 'C:\dev\app-demo-yun-lin-yes',
  # 只打包，不安裝到模擬器
  [switch]$NoInstall
)

$ErrorActionPreference = 'Stop'

# 來源 = 此腳本所在資料夾（scripts）的上一層，即 app-demo 專案根目錄
$Source = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path

Write-Host "來源：$Source"
Write-Host "目的：$Dest"

# 1. 同步（/MIR 鏡像；/XD 排除資料夾；其餘參數僅減少輸出）
#    app-install-page 是安裝頁（Node 專案，files/ 內還有數十 MB 的安裝檔），與 Flutter 打包無關，不需要同步
#    release/ 放的是發行用的舊 APK（已被 .gitignore 忽略），同樣不需要同步。
#    只排除「專案根目錄」的 release，用完整路徑；若只寫名稱，連 android/app/src/release 這類
#    release 專用的原始碼資料夾也會被排除，打包時會悄悄少東西。
New-Item -ItemType Directory -Force -Path $Dest | Out-Null
$releaseDir = Join-Path $Source 'release'
robocopy $Source $Dest /MIR /XD build .dart_tool .git app-install-page $releaseDir /NFL /NDL /NJH /NJS /NP | Out-Null
# robocopy 結束碼 0~7 皆為成功，8 以上才是失敗
if ($LASTEXITCODE -ge 8) {
  throw "robocopy 同步失敗（結束碼 $LASTEXITCODE）"
}
Write-Host '同步完成'

# 2. 打包
Push-Location $Dest
try {
  $buildArgs = @('build', 'apk')
  if ($Mode -eq 'debug') { $buildArgs += '--debug' }
  Write-Host "執行：flutter $($buildArgs -join ' ')"
  & flutter @buildArgs
  if ($LASTEXITCODE -ne 0) {
    throw "flutter build apk 失敗（結束碼 $LASTEXITCODE）"
  }
}
finally {
  Pop-Location
}

# 3. 印出結果
$apk = Join-Path $Dest "build\app\outputs\flutter-apk\app-$Mode.apk"
if (-not (Test-Path $apk)) {
  throw "找不到 APK：$apk"
}
$item = Get-Item $apk
$sizeMb = [math]::Round($item.Length / 1MB, 1)
Write-Host ''
Write-Host "APK 位置：$($item.FullName)"
Write-Host "APK 大小：$($item.Length) 位元組（約 $sizeMb MB）"
Write-Host "產生時間：$($item.LastWriteTime)"

# 4. 安裝到模擬器並重新啟動 App
if ($NoInstall) { return }

$PackageId = 'tw.com.pst.yes_app_demo'
$adbCmd = Get-Command adb -ErrorAction SilentlyContinue
if ($adbCmd) { $adb = $adbCmd.Source }
else {
  $sdk = if ($env:ANDROID_HOME) { $env:ANDROID_HOME } else { Join-Path $env:LOCALAPPDATA 'Android\Sdk' }
  $adb = Join-Path $sdk 'platform-tools\adb.exe'
}
if (-not (Test-Path $adb)) {
  Write-Warning "找不到 adb，略過安裝（可設定 ANDROID_HOME 或把 adb 加入 PATH）"
  return
}

# 只安裝到模擬器（序號以 emulator- 開頭），避免同時接著實體手機時誤裝；
# 沒有已啟動的模擬器就只提醒並略過，不算失敗
$devices = @(& $adb devices | Select-String '\tdevice$' | ForEach-Object { ($_.Line -split '\t')[0] })
$serial = $devices | Where-Object { $_ -like 'emulator-*' } | Select-Object -First 1
if (-not $serial) {
  if ($devices.Count -gt 0) {
    Write-Warning "只偵測到實體裝置（$($devices -join ', ')），不會自動安裝。請先啟動模擬器後再執行。"
  }
  else {
    Write-Warning '沒有已連線的模擬器，略過安裝。請先啟動模擬器後再執行。'
  }
  return
}
Write-Host ''
Write-Host "安裝到模擬器：$serial"
$others = @($devices | Where-Object { $_ -ne $serial })
if ($others.Count -gt 0) {
  Write-Host "（已略過其他裝置：$($others -join ', ')）"
}

# 本機環境靠 adb reverse 連到電腦的後端(44345)與網頁(3000)；模擬器重啟後會清空，每次重新設定
foreach ($port in 44345, 3000) {
  & $adb -s $serial reverse "tcp:$port" "tcp:$port" | Out-Null
  if ($LASTEXITCODE -ne 0) { throw "adb reverse tcp:$port 失敗" }
}
Write-Host 'adb reverse：tcp:44345、tcp:3000 已設定'

# -r 原地更新，保留 App 資料
& $adb -s $serial install -r $apk
if ($LASTEXITCODE -ne 0) { throw 'adb install 失敗' }

& $adb -s $serial shell am force-stop $PackageId | Out-Null
# monkey 會把參數印到 stderr；交給 cmd 以 >nul 2>&1 整個丟掉
# （PowerShell 5.1 直接用 2>&1 重導原生程式的 stderr，會被當成錯誤而中斷腳本）
cmd /c "`"$adb`" -s $serial shell monkey -p $PackageId -c android.intent.category.LAUNCHER 1 >nul 2>&1"
if ($LASTEXITCODE -ne 0) { Write-Warning '啟動 App 失敗，請手動開啟' }
Write-Host "已重新啟動 App：$PackageId"
