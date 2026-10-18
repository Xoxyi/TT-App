// Local FITeT proxy for the web build (the portal sends no CORS headers, so a
// browser cannot read its pages directly).
//
//   dart run tool/fitet_proxy.dart            # listens on http://localhost:8787
//   flutter run -d chrome                     # uses http://localhost:8787 by default
//
// Only forwards to portale.fitet.org, only the pages the app uses, one request
// at a time with a pause between them.
import 'dart:async';
import 'dart:io';

const String fitetHost = 'portale.fitet.org';
const Duration minGap = Duration(milliseconds: 500);

/// Pages the app reads (see lib/data/fitet.dart).
final RegExp allowedPath = RegExp(r'^/(risultati/[A-Za-z0-9_/]+\.(php|asp)|scheda_unica_i\.php|ajax\.php)$');

/// Headers the app sends as `X-Fitet-<name>`; the proxy restores them.
const List<String> forwarded = <String>['X-Requested-With', 'Referer', 'Accept', 'Cookie'];

Future<void> main(List<String> args) async {
  final port = args.isNotEmpty ? int.parse(args.first) : 8787;
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
  stdout.writeln('FITeT proxy on http://localhost:$port');
  var queue = Future<void>.value();
  await for (final request in server) {
    final done = Completer<void>();
    final previous = queue;
    queue = done.future;
    unawaited(() async {
      try {
        await _handle(request, previous);
      } catch (e) {
        stderr.writeln('error: $e');
        try {
          request.response.statusCode = HttpStatus.badGateway;
          await request.response.close();
        } catch (_) {}
      } finally {
        done.complete();
      }
    }());
  }
}

DateTime _last = DateTime.fromMillisecondsSinceEpoch(0);

Future<void> _handle(HttpRequest request, Future<void> previous) async {
  final res = request.response;
  final origin = request.headers.value('origin');
  if (origin != null && _originAllowed(origin)) {
    res.headers
      ..set('Access-Control-Allow-Origin', origin)
      ..set('Vary', 'Origin')
      ..set('Access-Control-Allow-Methods', 'GET, POST, OPTIONS')
      ..set('Access-Control-Allow-Headers',
          ['Content-Type', ...forwarded.map((h) => 'X-Fitet-$h'), 'X-Fitet-Content-Type'].join(', '))
      ..set('Access-Control-Expose-Headers', 'X-Fitet-Set-Cookie');
  }
  if (request.method == 'OPTIONS') {
    res.statusCode = HttpStatus.noContent;
    return res.close();
  }
  if ((request.method != 'GET' && request.method != 'POST') || !allowedPath.hasMatch(request.uri.path)) {
    res.statusCode = HttpStatus.forbidden;
    return res.close();
  }

  // One request at a time, with a pause, to stay gentle with the portal.
  await previous;
  final wait = minGap - DateTime.now().difference(_last);
  if (wait > Duration.zero) await Future<void>.delayed(wait);

  final target = Uri.https(fitetHost, request.uri.path, request.uri.queryParameters.isEmpty ? null : request.uri.queryParameters);
  final client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 10)
    ..userAgent = 'TT-Piciulin club app (low volume, web)';
  try {
    final out = await client.openUrl(request.method, target);
    for (final h in forwarded) {
      final v = request.headers.value('X-Fitet-$h');
      if (v == null) continue;
      if (h == 'Referer' && !v.startsWith('https://$fitetHost/')) continue;
      out.headers.set(h, v);
    }
    final type = request.headers.value('content-type');
    if (type != null) out.headers.set('content-type', type);
    final body = await request.fold<List<int>>(<int>[], (all, chunk) => all..addAll(chunk));
    if (body.isNotEmpty) {
      out.contentLength = body.length;
      out.add(body);
    }
    final answer = await out.close().timeout(const Duration(seconds: 20));
    final bytes = await answer.fold<List<int>>(<int>[], (all, chunk) => all..addAll(chunk));
    _last = DateTime.now();
    stdout.writeln('${request.method} ${target.path}${target.hasQuery ? '?${target.query}' : ''} -> ${answer.statusCode}');
    res.statusCode = answer.statusCode;
    final cookies = answer.headers[HttpHeaders.setCookieHeader];
    if (cookies != null && cookies.isNotEmpty) res.headers.set('X-Fitet-Set-Cookie', cookies.join('\n'));
    final ct = answer.headers.contentType;
    if (ct != null) res.headers.contentType = ct;
    res.add(bytes);
    await res.close();
  } finally {
    client.close(force: true);
  }
}

bool _originAllowed(String origin) {
  final uri = Uri.tryParse(origin);
  return uri != null && (uri.host == 'localhost' || uri.host == '127.0.0.1');
}
