import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// 環境設定。模擬器內 localhost 需先 adb reverse tcp:3000 / tcp:44345。
class AppEnv {
  const AppEnv(this.name, this.apiBase, this.webUrl);
  final String name;
  final String apiBase;
  final String webUrl;

  /// WebView cookie 的 domain 取自網址 host
  String get cookieDomain => Uri.parse(webUrl).host;

  static const dev = AppEnv('本機', 'https://localhost:44345/LLMApi/', 'http://localhost:3000/?m=1');
  static const test = AppEnv(
      '測試機', 'https://testyesme.pst.com.tw/LLMApi/', 'https://testyesme.pst.com.tw/?m=1');
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
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const LoginPage(),
    );
  }
}

/// 後端為自簽憑證，開發環境略過憑證檢查
http.Client _devClient() {
  final inner = HttpClient()..badCertificateCallback = (cert, host, port) => true;
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
            body: jsonEncode({'account': _account.text.trim(), 'password': _password.text}),
          )
          .timeout(const Duration(seconds: 30));
      final body = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      final ok = body['isSuccess'] == true || body['status'] == true;
      final token = (body['data']?['token'] ?? body['token']) as String?;
      if (ok && token != null) {
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => HomePage(env: _env, token: token, account: _account.text.trim())),
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
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Card(
              color: Colors.white,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
                side: BorderSide(color: Colors.grey.shade200),
              ),
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset('assets/logo.jpg', width: 96, height: 96),
                    const SizedBox(height: 16),
                    const Text('我家環境通',
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    Text('您的專屬環境監測助手', style: TextStyle(color: Colors.grey.shade600)),
                    const SizedBox(height: 20),
                    SegmentedButton<AppEnv>(
                      segments: [
                        for (final e in AppEnv.all) ButtonSegment(value: e, label: Text(e.name)),
                      ],
                      selected: {_env},
                      onSelectionChanged: _loading ? null : (v) => setState(() => _env = v.first),
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
                          icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                          onPressed: () => setState(() => _obscure = !_obscure),
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
                                child: CircularProgressIndicator(strokeWidth: 2))
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
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.env, required this.token, required this.account});

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
    _web = WebViewController()..setJavaScriptMode(JavaScriptMode.unrestricted);
    _initWeb();
  }

  /// 先把登入 token 以 jwt_token cookie 寫入 WebView，網頁端即視為已登入
  Future<void> _initWeb() async {
    await WebViewCookieManager().setCookie(WebViewCookie(
      name: 'jwt_token',
      value: widget.token,
      domain: widget.env.cookieDomain,
      path: '/',
    ));
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
            _DashboardPlaceholder(account: widget.account),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.map_outlined), selectedIcon: Icon(Icons.map), label: 'AI 地圖'),
          NavigationDestination(
              icon: Icon(Icons.dashboard_outlined),
              selectedIcon: Icon(Icons.dashboard),
              label: '環境儀表板'),
        ],
      ),
    );
  }
}

class _DashboardPlaceholder extends StatelessWidget {
  const _DashboardPlaceholder({required this.account});
  final String account;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.dashboard, size: 64, color: Colors.blue),
          const SizedBox(height: 12),
          Text('環境儀表板（示意頁）', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 6),
          Text('目前登入：$account'),
        ],
      ),
    );
  }
}
