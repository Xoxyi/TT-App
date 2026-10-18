import 'dart:io';

import 'fitet_http.dart';

/// Android/iOS: direct requests with dart:io.
class PlatformFitetHttp implements FitetHttp {
  @override
  Future<FitetHttpResponse> send(
    String method,
    Uri uri, {
    required Map<String, String> headers,
    List<int>? body,
    required Duration timeout,
  }) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 10)
      ..idleTimeout = const Duration(seconds: 5)
      ..userAgent = 'TT-Piciulin club app (low volume)';
    try {
      return await (() async {
        final request = await client.openUrl(method, uri);
        headers.forEach((k, v) => request.headers.set(k, v));
        if (body != null) {
          request.contentLength = body.length;
          request.add(body);
        }
        final response = await request.close();
        final cookies = response.headers[HttpHeaders.setCookieHeader] ?? const <String>[];
        if (response.statusCode != 200) {
          await response.drain<void>();
          return FitetHttpResponse(response.statusCode, const <int>[], setCookies: cookies);
        }
        final bytes = await response.fold<List<int>>(<int>[], (all, chunk) => all..addAll(chunk));
        return FitetHttpResponse(200, bytes, setCookies: cookies);
      })()
          .timeout(timeout);
    } finally {
      // Also aborts a request that timed out.
      client.close(force: true);
    }
  }
}
