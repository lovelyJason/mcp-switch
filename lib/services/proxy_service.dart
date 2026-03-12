import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:socks5_proxy/socks_client.dart';
import 'config/config_service.dart';
import 'logger_service.dart';

class ProxyResult {
  final bool success;
  final int? statusCode;
  final Duration? elapsed;
  final String? error;

  const ProxyResult({
    required this.success,
    this.statusCode,
    this.elapsed,
    this.error,
  });
}

class ScannedProxy {
  final String host;
  final int port;
  final String type;
  final String displayUrl;

  const ScannedProxy({
    required this.host,
    required this.port,
    required this.type,
    required this.displayUrl,
  });
}

class ProxyService {
  final ConfigService _configService;

  ProxyService(this._configService);

  /// 根据当前代理配置创建 http.Client
  /// 无配置时返回普通 Client
  http.Client createProxiedClient() {
    final url = _configService.proxyUrl;
    if (url.isEmpty) return http.Client();

    try {
      return _buildClient(url, _configService.proxyUsername,
          _configService.proxyPassword);
    } catch (e) {
      LoggerService.error('[ProxyService] 创建代理 Client 失败', e);
      return http.Client();
    }
  }

  /// 用指定 URL 创建代理 Client（用于测试时）
  http.Client createClientForUrl(String proxyUrl,
      {String username = '', String password = ''}) {
    if (proxyUrl.isEmpty) return http.Client();
    return _buildClient(proxyUrl, username, password);
  }

  http.Client _buildClient(String proxyUrl, String username, String password) {
    final uri = Uri.parse(proxyUrl);
    final scheme = uri.scheme.toLowerCase();

    if (scheme == 'socks5' || scheme == 'socks5h') {
      return _buildSocks5Client(uri, username, password);
    }
    return _buildHttpProxyClient(uri, username, password);
  }

  http.Client _buildHttpProxyClient(
      Uri proxyUri, String username, String password) {
    final httpClient = HttpClient();
    final host = proxyUri.host;
    final port = proxyUri.port != 0 ? proxyUri.port : 7890;

    httpClient.findProxy = (uri) => 'PROXY $host:$port';

    if (username.isNotEmpty) {
      httpClient.addProxyCredentials(
        host,
        port,
        'Basic',
        HttpClientBasicCredentials(username, password),
      );
    }

    return IOClient(httpClient);
  }

  http.Client _buildSocks5Client(
      Uri proxyUri, String username, String password) {
    final host = proxyUri.host.isEmpty ? '127.0.0.1' : proxyUri.host;
    final port = proxyUri.port != 0 ? proxyUri.port : 1080;

    final proxy = ProxySettings(
      InternetAddress(host),
      port,
      username: username.isNotEmpty ? username : null,
      password: username.isNotEmpty ? password : null,
    );

    final httpClient = HttpClient();
    SocksTCPClient.assignToHttpClient(httpClient, [proxy]);
    return IOClient(httpClient);
  }

  /// 测试代理连通性
  Future<ProxyResult> testProxy(String proxyUrl,
      {String username = '', String password = ''}) async {
    final sw = Stopwatch()..start();
    http.Client? client;

    try {
      client = createClientForUrl(proxyUrl,
          username: username, password: password);
      final response = await client
          .get(Uri.parse('https://api.github.com'))
          .timeout(const Duration(seconds: 10));
      sw.stop();

      if (response.statusCode == 200 || response.statusCode == 403) {
        return ProxyResult(
          success: true,
          statusCode: response.statusCode,
          elapsed: sw.elapsed,
        );
      }
      return ProxyResult(
        success: false,
        statusCode: response.statusCode,
        elapsed: sw.elapsed,
        error: 'HTTP ${response.statusCode}',
      );
    } catch (e) {
      sw.stop();
      return ProxyResult(
        success: false,
        elapsed: sw.elapsed,
        error: e.toString(),
      );
    } finally {
      client?.close();
    }
  }

  /// 扫描本地常见代理端口
  static const _commonPorts = [
    (7890, 'http'), // Clash
    (7891, 'http'), // Clash (alt)
    (7897, 'http'), // ClashX Pro
    (1080, 'socks5'), // SOCKS5 common
    (1087, 'http'), // ClashX HTTP
    (8080, 'http'), // HTTP proxy common
    (8118, 'http'), // Privoxy
    (9090, 'http'), // Clash API
  ];

  Future<List<ScannedProxy>> scanLocalProxies() async {
    final results = <ScannedProxy>[];
    final futures = <Future>[];

    for (final (port, type) in _commonPorts) {
      futures.add(_checkPort('127.0.0.1', port, type).then((proxy) {
        if (proxy != null) results.add(proxy);
      }));
    }

    await Future.wait(futures);
    results.sort((a, b) => a.port.compareTo(b.port));
    return results;
  }

  Future<ScannedProxy?> _checkPort(String host, int port, String type) async {
    try {
      final socket = await Socket.connect(host, port,
          timeout: const Duration(milliseconds: 500));
      await socket.close();
      return ScannedProxy(
        host: host,
        port: port,
        type: type,
        displayUrl: '$type://$host:$port',
      );
    } catch (_) {
      return null;
    }
  }

  /// 校验代理 URL 格式
  static bool isValidProxyUrl(String url) {
    if (url.isEmpty) return false;
    try {
      final uri = Uri.parse(url);
      if (!['http', 'https', 'socks5', 'socks5h'].contains(uri.scheme)) {
        return false;
      }
      if (uri.host.isEmpty) return false;
      return true;
    } catch (_) {
      return false;
    }
  }
}
