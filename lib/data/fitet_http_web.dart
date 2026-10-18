import 'package:http/browser_client.dart';
import 'package:http/http.dart' as http;

import 'fitet_http.dart';

/// Browser: requests go through the FITeT proxy (see `tool/fitet_proxy.dart`
/// and `web_proxy/worker.js`), set at build time with
/// `--dart-define=FITET_PROXY=https://...`.
class PlatformFitetHttp implements FitetHttp {
  static const String proxy = String.fromEnvironment('FITET_PROXY', defaultValue: 'http://localhost:8787');

  @override
  Future<FitetHttpResponse> send(
    String method,
    Uri uri, {
    required Map<String, String> headers,
    List<int>? body,
    required Duration timeout,
  }) async {
    final base = Uri.parse(proxy);
    final target = base.replace(
      path: '${base.path.replaceFirst(RegExp(r'/$'), '')}${uri.path}',
      query: uri.hasQuery ? uri.query : null,
    );
    // Browsers may not set Referer, Cookie or User-Agent themselves: the
    // proxy turns "X-Fitet-<name>" headers back into the real ones.
    final request = http.Request(method, target);
    headers.forEach((k, v) => request.headers['X-Fitet-$k'] = v);
    final type = headers['Content-Type'];
    if (type != null) request.headers['Content-Type'] = type;
    if (body != null) request.bodyBytes = body;
    final client = BrowserClient();
    try {
      final response = await http.Response.fromStream(await client.send(request).timeout(timeout)).timeout(timeout);
      final cookies = response.headers['x-fitet-set-cookie'];
      return FitetHttpResponse(
        response.statusCode,
        response.bodyBytes,
        setCookies: cookies == null || cookies.isEmpty ? const <String>[] : cookies.split('\n'),
      );
    } finally {
      client.close();
    }
  }
}
