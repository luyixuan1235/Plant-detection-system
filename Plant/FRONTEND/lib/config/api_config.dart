class ApiConfig {
  // 后端 API 地址配置。
  //
  // 使用说明：
  // - 电脑本地访问时，默认请求 http://127.0.0.1:8000
  // - 手机通过局域网访问前端时，默认请求 http://当前网页主机:8000
  // - 使用 Cloudflare tunnel 或自定义后端时，启动前端时传入：
  //   flutter run -d web-server --web-hostname 0.0.0.0 --web-port 8085 --dart-define=API_BASE_URL=https://xxxx.trycloudflare.com
  //
  // 手机浏览器里的 127.0.0.1 指向手机自己，不是运行后端的电脑。
  // iPhone Safari 的二维码扫描和拍照上传需要 HTTPS，因此手机访问推荐使用 Cloudflare tunnel。
  static const String _configuredBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
  );

  static String get baseUrl {
    if (_configuredBaseUrl.isNotEmpty) return _configuredBaseUrl;

    final host = Uri.base.host;
    if (host.isNotEmpty && host != 'localhost' && host != '127.0.0.1') {
      return 'http://$host:8000';
    }

    return 'http://127.0.0.1:8000';
  }

  // 获取当前配置的 baseURL（用于调试）
  static String get currentBaseUrl => baseUrl;
}
