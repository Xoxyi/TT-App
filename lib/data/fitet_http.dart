import 'fitet_http_io.dart' if (dart.library.js_interop) 'fitet_http_web.dart' as platform;

/// What the FITeT portal answered to one request.
class FitetHttpResponse {
  const FitetHttpResponse(this.statusCode, this.bytes, {this.setCookies = const <String>[]});

  final int statusCode;
  final List<int> bytes;

  /// Raw `Set-Cookie` values ("NAME=value; path=/; ...").
  final List<String> setCookies;
}

/// Sends one HTTP request to the FITeT portal.
///
/// On Android/iOS it talks to the portal directly; in a browser it goes
/// through a small proxy, because the portal sends no CORS headers.
abstract class FitetHttp {
  factory FitetHttp() = platform.PlatformFitetHttp;

  Future<FitetHttpResponse> send(
    String method,
    Uri uri, {
    required Map<String, String> headers,
    List<int>? body,
    required Duration timeout,
  });
}
