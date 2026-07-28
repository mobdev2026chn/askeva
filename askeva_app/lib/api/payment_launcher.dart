import 'dart:io';

import 'package:url_launcher/url_launcher.dart';

/// Hosts the payment-gateway HTML returned by /payments/addWallet on a one-shot
/// localhost server and opens it in the device browser — the app's equivalent
/// of the web's `window.open(...).document.write(html)` popup. The page (a
/// self-submitting form) then hands off to the real gateway (UPI / card /
/// netbanking, with their own logos). Returns false if no browser opened.
Future<bool> openGatewayHtml(String html) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  // Serve the gateway page for the first request, then keep alive briefly so
  // the browser has time to load before we tear the server down.
  server.listen((req) async {
    req.response.headers.contentType = ContentType.html;
    req.response.write(html);
    await req.response.close();
  });
  final uri = Uri.parse('http://127.0.0.1:${server.port}/');
  bool ok = false;
  try {
    ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    ok = false;
  }
  Future.delayed(const Duration(minutes: 5), () => server.close(force: true));
  return ok;
}
