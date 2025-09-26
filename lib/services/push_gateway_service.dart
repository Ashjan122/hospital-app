import 'dart:convert';
import 'package:http/http.dart' as http;

class PushGatewayService {
  // Deployed Cloud Function URL
  static String gatewayUrl = 'https://us-central1-hospitalapp-681f1.cloudfunctions.net/sendPush';

  static Future<bool> sendPush({
    required String token,
    required String title,
    required String body,
    Map<String, String>? data,
  }) async {
    if (gatewayUrl.isEmpty) return false;
    try {
      final uri = Uri.parse(gatewayUrl);
      final resp = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'token': token,
          'title': title,
          'body': body,
          'data': data ?? {},
        }),
      );
      final ok = resp.statusCode == 200;
      // Debug output to help diagnose delivery issues
      // Note: keep logs minimal in production
      // print('PUSH GW RESP ${resp.statusCode}: ${resp.body}');
      return ok;
    } catch (_) {
      return false;
    }
  }
}


