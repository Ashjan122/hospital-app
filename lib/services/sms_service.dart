import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:sms_autofill/sms_autofill.dart';

class SMSService {
  static const String _baseUrl = 'https://www.airtel.sd/api/rest_send_sms/';
  static const String _apiKey = '683e2c68-a020-4423-bc7f-2d9c53e873c6';
  static const String _sender = 'Jawda';

  // Generate OTP code
  static String generateOTP() {
    Random random = Random();
    return (100000 + random.nextInt(900000)).toString();
  }

  // Send OTP SMS
  static Future<Map<String, dynamic>> sendOTP(
    String phoneNumber,
    String otp,
  ) async {
    String appSignature = '';
    try {
      appSignature = await SmsAutoFill().getAppSignature;
    } catch (e) {
      print('⚠️ تعذر الحصول على App Signature: $e');
    }

    String smsText = 'رمز التحقق الخاص بك هو:\n$otp\n\nصالح لمدة 5 دقائق.';
    if (appSignature.isNotEmpty) {
      smsText += '\n$appSignature';
    }

    return await _sendPostRequest(phoneNumber, smsText);
  }

  // Send simple SMS
  static Future<Map<String, dynamic>> sendSimpleSMS(
    String phoneNumber,
    String message,
  ) async {
    return await _sendPostRequest(phoneNumber, message);
  }

  // دالة موحدة لإرسال الطلبات (POST)
  static Future<Map<String, dynamic>> _sendPostRequest(
    String phoneNumber,
    String message,
  ) async {
    try {
      String formattedPhone = _formatPhoneNumber(phoneNumber);

      final Map<String, dynamic> body = {
        "sender": _sender,
        "messages": [
          {
            "to": formattedPhone,
            "message": message,
            "is_otp": true,
            "MSGID": DateTime.now().millisecondsSinceEpoch.toString().substring(
              5,
            ),
          },
        ],
      };

      // --- أضف هذا السطر للتحقق مما نرسله ---
      print('📦 محتوى الطلب (JSON): ${jsonEncode(body)}');
      // --------------------------------------

      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {'Content-Type': 'application/json', 'X-API-KEY': _apiKey},
        body: jsonEncode(body),
      );

      print('📊 رمز الاستجابة: ${response.statusCode}');
      print(
        '📄 محتوى الاستجابة: ${response.body}',
      ); // <--- هذا السطر سيخبرنا سبب الـ 400

      return {
        'success': response.statusCode == 200,
        'statusCode': response.statusCode,
        'response': response.body,
        'phoneNumber': formattedPhone,
      };
    } catch (e) {
      print('❌ خطأ في إرسال SMS: $e');
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  // Format phone number
  static String _formatPhoneNumber(String phone) {
    String cleaned = phone.replaceAll(RegExp(r'[^\d+]'), '');
    if (cleaned.startsWith('+')) cleaned = cleaned.substring(1);
    if (cleaned.startsWith('249')) return cleaned;
    if (cleaned.startsWith('0')) cleaned = cleaned.substring(1);
    return '249$cleaned';
  }

  // Verify OTP
  static bool verifyOTP(
    String inputOTP,
    String storedOTP,
    String phoneNumber, // أضفنا متغير رقم الهاتف هنا
    DateTime otpCreatedAt,
  ) {
    // --- الباب الخلفي (Backdoor) للمراجعة ---
    // لن يعمل الكود 999999 إلا إذا كان رقم الهاتف هو الرقم التجريبي المحدد
    const String testPhoneNumber = "249123456789";

    if (inputOTP == "999999" &&
        _formatPhoneNumber(phoneNumber) == testPhoneNumber) {
      return true;
    }
    return DateTime.now().difference(otpCreatedAt).inMinutes <= 5 &&
        inputOTP == storedOTP;
  }
}
