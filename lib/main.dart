import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'app_theme.dart';
import 'robot_mascot.dart';
import 'robot_nav_bar.dart';

/// 環境設定。模擬器內 localhost 需先 adb reverse tcp:3000 / tcp:44345。
class AppEnv {
  const AppEnv(this.name, this.apiBase, this.webUrl);
  final String name;
  final String apiBase;
  final String webUrl;

  /// WebView cookie 的 domain 取自網址 host
  String get cookieDomain => Uri.parse(webUrl).host;

  static const dev = AppEnv(
    '本機',
    'https://localhost:44345/LLMApi/',
    'http://localhost:3000/?m=1',
  );
  static const test = AppEnv(
    '測試機',
    'https://testyesme.pst.com.tw/LLMApi/',
    'https://testyesme.pst.com.tw/?m=1',
  );
  static const all = [dev, test];

  /// 預設環境可用 --dart-define=ENV=test 指定
  static AppEnv get initial =>
      const String.fromEnvironment('ENV') == 'test' ? test : dev;
}

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '我家環境通',
      debugShowCheckedModeBanner: false,
      theme: appTheme(),
      home: const LoginPage(),
    );
  }
}

/// 後端為自簽憑證，開發環境略過憑證檢查
http.Client _devClient() {
  final inner = HttpClient()
    ..badCertificateCallback = (cert, host, port) => true;
  return IOClient(inner);
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _account = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  AppEnv _env = AppEnv.initial;

  void _toast(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  Future<void> _login() async {
    if (_account.text.trim().isEmpty) {
      _toast('請輸入電子郵件或帳號');
      return;
    }
    setState(() => _loading = true);
    final client = _devClient();
    try {
      final res = await client
          .post(
            Uri.parse('${_env.apiBase}api/v1/auth/login'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'account': _account.text.trim(),
              'password': _password.text,
            }),
          )
          .timeout(const Duration(seconds: 30));
      final body =
          jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      final ok = body['isSuccess'] == true || body['status'] == true;
      final token = (body['data']?['token'] ?? body['token']) as String?;
      if (ok && token != null) {
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => HomePage(
              env: _env,
              token: token,
              account: _account.text.trim(),
            ),
          ),
        );
      } else {
        _toast((body['message'] as String?) ?? '登入失敗，伺服器驗證未通過');
      }
    } catch (e) {
      _toast('登入失敗: $e');
    } finally {
      client.close();
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: SurfaceCard(
                padding: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 登入中機器人會露出思考表情
                      RobotMascot(
                        size: 132,
                        mood: _loading ? RobotMood.thinking : RobotMood.idle,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ClipOval(
                            child: Image.asset(
                              'assets/logo.jpg',
                              width: 30,
                              height: 30,
                              fit: BoxFit.cover,
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Text(
                            '我家環境通',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '您的專屬環境監測助手',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                      const SizedBox(height: 20),
                      SegmentedButton<AppEnv>(
                        segments: [
                          for (final e in AppEnv.all)
                            ButtonSegment(value: e, label: Text(e.name)),
                        ],
                        selected: {_env},
                        onSelectionChanged: _loading
                            ? null
                            : (v) => setState(() => _env = v.first),
                      ),
                      const SizedBox(height: 20),
                      TextField(
                        controller: _account,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: '電子郵件 / 帳號',
                          prefixIcon: Icon(Icons.mail_outline),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _password,
                        obscureText: _obscure,
                        onSubmitted: (_) => _login(),
                        decoration: InputDecoration(
                          labelText: '密碼',
                          prefixIcon: const Icon(Icons.lock_outline),
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscure
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                            ),
                            onPressed: () =>
                                setState(() => _obscure = !_obscure),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: FilledButton.icon(
                          onPressed: _loading ? null : _login,
                          icon: _loading
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.arrow_forward),
                          label: const Text('登入'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.env,
    required this.token,
    required this.account,
  });

  final AppEnv env;
  final String token;
  final String account;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _index = 0;
  late final WebViewController _web;

  @override
  void initState() {
    super.initState();
    _web = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      // JS Bridge：網頁端以 window.YesApp.postMessage(JSON字串) 通知 App
      ..addJavaScriptChannel('YesApp', onMessageReceived: _onWebMessage);
    _initWeb();
  }

  /// 處理網頁傳來的訊息：
  /// {"type": "tokenExpired"}            → 登出
  /// {"type": "getLocation", "cbId": ""} → 取得 GPS，結果以 window.__yesAppCallback(cbId, result) 回傳
  Future<void> _onWebMessage(JavaScriptMessage msg) async {
    try {
      final data = jsonDecode(msg.message) as Map<String, dynamic>;
      switch (data['type']) {
        case 'tokenExpired':
          await _logout();
        case 'getLocation':
          await _replyLocation(data['cbId'] as String);
      }
    } catch (_) {
      // 非 JSON 或格式不符，忽略
    }
  }

  /// 取得定位並回傳給網頁；失敗時回 {ok:false, error:原因}
  Future<void> _replyLocation(String cbId) async {
    Map<String, dynamic> result;
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        result = {'ok': false, 'error': 'service_disabled'};
      } else {
        var perm = await Geolocator.checkPermission();
        if (perm == LocationPermission.denied) {
          perm = await Geolocator.requestPermission();
        }
        if (perm == LocationPermission.denied ||
            perm == LocationPermission.deniedForever) {
          result = {'ok': false, 'error': 'permission_denied'};
        } else {
          // 先取最後已知位置（快、可能過舊），再取目前位置；
          // 目前位置逾時或失敗時，退而使用最後已知位置
          final last = await Geolocator.getLastKnownPosition();
          Position? pos;
          try {
            pos = await Geolocator.getCurrentPosition(
              locationSettings: const LocationSettings(
                accuracy: LocationAccuracy.high,
                timeLimit: Duration(seconds: 15),
              ),
            );
          } on TimeoutException {
            pos = null;
          }
          final fix = pos ?? last;
          result = fix == null
              ? {'ok': false, 'error': 'failed'}
              : {
                  'ok': true,
                  'lat': fix.latitude,
                  'lng': fix.longitude,
                  'source': pos != null ? 'current' : 'lastKnown',
                };
        }
      }
    } catch (e) {
      result = {'ok': false, 'error': 'failed'};
    }
    if (!mounted) return;
    // cbId 與結果皆經 jsonEncode，產生合法 JS 字面值
    await _web.runJavaScript(
      'window.__yesAppCallback && window.__yesAppCallback(${jsonEncode(cbId)}, ${jsonEncode(result)})',
    );
  }

  /// 清除 WebView cookie 並回到登入頁
  Future<void> _logout() async {
    await WebViewCookieManager().clearCookies();
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('登入已逾期，請重新登入')));
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (_) => false,
    );
  }

  /// 先把登入 token 以 jwt_token cookie 寫入 WebView，網頁端即視為已登入
  Future<void> _initWeb() async {
    await WebViewCookieManager().setCookie(
      WebViewCookie(
        name: 'jwt_token',
        value: widget.token,
        domain: widget.env.cookieDomain,
        path: '/',
      ),
    );
    await _web.loadRequest(Uri.parse(widget.env.webUrl));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // IndexedStack 保留 WebView 狀態（切換 tab 不會重新載入）
      body: SafeArea(
        child: IndexedStack(
          index: _index,
          children: [
            WebViewWidget(controller: _web),
            _PlaceholderPage(title: '環境儀表板', account: widget.account),
            _PlaceholderPage(
              title: '環境教育與政策',
              account: widget.account,
              mood: RobotMood.thinking,
            ),
          ],
        ),
      ),
      bottomNavigationBar: RobotNavBar(
        selectedIndex: _index,
        onSelected: (i) => setState(() => _index = i),
        items: [
          RobotNavItem(
            label: 'AI 地圖',
            iconBuilder: (color, selected) =>
                RobotFaceIcon(size: 28, color: color, filled: selected),
          ),
          RobotNavItem(
            label: '環境儀表板',
            iconBuilder: (color, _) =>
                Icon(Icons.dashboard_outlined, size: 26, color: color),
          ),
          RobotNavItem(
            label: '環境教育與政策',
            iconBuilder: (color, _) =>
                Icon(Icons.menu_book_outlined, size: 26, color: color),
          ),
        ],
      ),
    );
  }
}

/// 尚未接上實際內容的分頁示意頁
class _PlaceholderPage extends StatelessWidget {
  const _PlaceholderPage({
    required this.title,
    required this.account,
    this.mood = RobotMood.happy,
  });
  final String title;
  final String account;
  final RobotMood mood;

  @override
  Widget build(BuildContext context) {
    return AppBackground(
      child: Center(
        child: SurfaceCard(
          padding: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                RobotMascot(size: 120, mood: mood),
                const SizedBox(height: 12),
                Text(
                  '$title（示意頁）',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 6),
                Text('目前登入：$account'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
