import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:hospital_app/services/sms_service.dart';

class WhatsAppService {
  static const String _baseUrl = 'https://api.ultramsg.com/instance140372/messages/chat';
  static const String _token = 'wjav78swzp7u87uk';

  // Generate OTP code
  static String generateOTP() {
    // Use the same OTP generation as SMS service for consistency
    return SMSService.generateOTP();
  }

  // Send OTP via WhatsApp
  static Future<Map<String, dynamic>> sendOTP(String phoneNumber, String otp) async {
    try {
      print('🔍 بدء إرسال رمز التحقق عبر واتساب...');
      print('📱 رقم الهاتف المدخل: $phoneNumber');
      print('🔐 رمز التحقق: $otp');
      
      // Format phone number for WhatsApp
      String formattedPhone = _formatPhoneNumberForWhatsApp(phoneNumber);
      print('📞 رقم الهاتف المنسق: $formattedPhone');
      
      // Prepare WhatsApp message
      String message = 
    'رمز التحقق الخاص بك هو:\n\n'
    '```$otp```\n\n'
    
    'صالح لمدة 5 دقائق.';

      print('💬 نص الرسالة: $message');
      
      print('📡 إرسال طلب HTTP إلى واتساب...');
      
      // Send HTTP request using the exact format you provided
      var headers = {
        'Content-Type': 'application/x-www-form-urlencoded'
      };
      
      var request = http.Request('POST', Uri.parse(_baseUrl));
      request.bodyFields = {
        'token': _token,
        'to': formattedPhone,
        'body': message,
      };
      request.headers.addAll(headers);
      
      http.StreamedResponse response = await request.send();
      String responseBody = await response.stream.bytesToString();
      
      print('📊 رمز الاستجابة: ${response.statusCode}');
      print('📄 محتوى الاستجابة: $responseBody');
      
      // Parse response
      Map<String, dynamic> result = {
        'success': false,
        'statusCode': response.statusCode,
        'response': responseBody,
        'phoneNumber': formattedPhone,
      };
      
      if (response.statusCode == 200) {
        print('✅ تم استلام استجابة 200 من واتساب');
        print('📄 الاستجابة الخام: $responseBody');
        
        // If we get 200 status code, assume success since message is actually delivered
        result['success'] = true;
        result['message'] = 'WhatsApp message sent successfully';
        
        try {
          // Try to parse JSON response for additional info
          Map<String, dynamic> jsonResponse = json.decode(responseBody);
          print('📋 استجابة JSON: $jsonResponse');
          
          // Extract message ID if available
          result['messageId'] = jsonResponse['id'] ?? 
                               jsonResponse['messageId'] ?? 
                               jsonResponse['msgId'] ??
                               jsonResponse['message_id'];
          
          // Check for any error indicators in the response
          if (jsonResponse.containsKey('error') && jsonResponse['error'] != null) {
            print('⚠️ تحذير في الاستجابة: ${jsonResponse['error']}');
            result['warning'] = jsonResponse['error'];
          }
          
        } catch (e) {
          print('⚠️ لا يمكن تحليل الاستجابة كـ JSON: $e');
          // This is fine - we still consider it successful if status is 200
          result['message'] = 'WhatsApp message sent (response not JSON)';
        }
        
        print('✅ تم اعتبار الإرسال ناجح (استجابة 200)');
        
      } else {
        print('❌ فشل في الاتصال بواتساب: رمز الاستجابة ${response.statusCode}');
        result['message'] = 'WhatsApp API error: HTTP ${response.statusCode} - $responseBody';
      }
      
      print('🎯 النتيجة النهائية: $result');
      return result;
    } catch (e) {
      print('❌ خطأ في إرسال رسالة واتساب: $e');
      return {
        'success': false,
        'message': 'Error sending WhatsApp message: $e',
        'phoneNumber': phoneNumber,
      };
    }
  }

  // Format phone number for WhatsApp API
  static String _formatPhoneNumberForWhatsApp(String phone) {
    print('🔧 تنسيق رقم الهاتف للواتساب: $phone');
    
    // Remove any non-digit characters except +
    String cleaned = phone.replaceAll(RegExp(r'[^\d+]'), '');
    print('🧹 بعد التنظيف: $cleaned');
    
    // Remove + if present
    if (cleaned.startsWith('+')) {
      cleaned = cleaned.substring(1);
      print('➖ بعد إزالة +: $cleaned');
    }
    
    // For WhatsApp, we need the full international format without +
    print('📞 الرقم النهائي للواتساب: $cleaned');
    return cleaned;
  }

  // Send simple WhatsApp message (for testing)
  static Future<Map<String, dynamic>> sendSimpleMessage(String phoneNumber, String message) async {
    try {
      // Format phone number
      String formattedPhone = _formatPhoneNumberForWhatsApp(phoneNumber);
      
      print('Sending WhatsApp message to: $formattedPhone');
      print('Message: $message');
      
      // Send HTTP request
      var headers = {
        'Content-Type': 'application/x-www-form-urlencoded'
      };
      
      var request = http.Request('POST', Uri.parse(_baseUrl));
      request.bodyFields = {
        'token': _token,
        'to': formattedPhone,
        'body': message,
      };
      request.headers.addAll(headers);
      
      http.StreamedResponse response = await request.send();
      String responseBody = await response.stream.bytesToString();
      
      print('WhatsApp Response: ${response.statusCode} - $responseBody');
      
      // Parse response
      Map<String, dynamic> result = {
        'success': false,
        'statusCode': response.statusCode,
        'response': responseBody,
        'phoneNumber': formattedPhone,
      };
      
      if (response.statusCode == 200) {
        // If we get 200 status code, assume success since message is actually delivered
        result['success'] = true;
        result['message'] = 'WhatsApp message sent successfully';
        
        try {
          Map<String, dynamic> jsonResponse = json.decode(responseBody);
          result['messageId'] = jsonResponse['id'] ?? 
                               jsonResponse['messageId'] ?? 
                               jsonResponse['msgId'] ??
                               jsonResponse['message_id'];
        } catch (e) {
          // This is fine - we still consider it successful if status is 200
          result['message'] = 'WhatsApp message sent (response not JSON)';
        }
      } else {
        result['message'] = 'WhatsApp API error: HTTP ${response.statusCode}';
      }
      
      return result;
    } catch (e) {
      print('Error sending WhatsApp message: $e');
      return {
        'success': false,
        'message': 'Error sending WhatsApp message: $e',
        'phoneNumber': phoneNumber,
      };
    }
  }

  // Send booking confirmation via WhatsApp Cloud API template
  static Future<Map<String, dynamic>> sendBookingTemplate({
    required String phoneNumber,
    required String facilityName,
    required String patientName,
    required String doctorName,
    required String specializationName,
    required String dayName,
    required String date,
    required String period,
    required String patientPhone,
  }) async {
    const String cloudApiToken =
        'EAAapSj9k2sABRIVNLKtomho0lxjbXkH9JXm1Asgzosmz0x3nsOAlDdzRauNcJOgYNwUfXzRz5xCetT0SqgKZAeJZAD2h92NaUnrXWDOiFyjdZAaStoF1d36EPgwzAxZC6UmihhYyGZCyx2JdlDIBvpl2JTTvNFdTPYi215N0GiS2XhmoHULg9F6WK6iwd7ZBklXgZDZD';
    const String phoneNumberId = '1151556284697196';
    final String url =
        'https://graph.facebook.com/v19.0/$phoneNumberId/messages';

    final String to = phoneNumber.replaceAll(RegExp(r'[^\d]'), '').replaceFirst(RegExp(r'^0'), '249');

    final Map<String, dynamic> body = {
      'messaging_product': 'whatsapp',
      'to': to,
      'type': 'template',
      'template': {
        'name': 'booking_message',
        'language': {'code': 'ar'},
        'components': [
          {
            'type': 'body',
            'parameters': [
              {'type': 'text', 'text': facilityName},
              {'type': 'text', 'text': patientName},
              {'type': 'text', 'text': doctorName},
              {'type': 'text', 'text': specializationName},
              {'type': 'text', 'text': dayName},
              {'type': 'text', 'text': date},
              {'type': 'text', 'text': period},
              {'type': 'text', 'text': patientPhone},
            ],
          },
        ],
      },
    };

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $cloudApiToken',
        },
        body: jsonEncode(body),
      );
      print('📲 WhatsApp Cloud API: ${response.statusCode} - ${response.body}');
      return {
        'success': response.statusCode == 200,
        'statusCode': response.statusCode,
        'response': response.body,
      };
    } catch (e) {
      print('❌ خطأ في إرسال قالب واتساب: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  // Test WhatsApp API connection
  static Future<Map<String, dynamic>> testConnection() async {
    try {
      print('🧪 اختبار اتصال واتساب API...');
      
      var headers = {
        'Content-Type': 'application/x-www-form-urlencoded'
      };
      
      var request = http.Request('POST', Uri.parse(_baseUrl));
      request.bodyFields = {
        'token': _token,
        'to': '249123456789', // Test number
        'body': 'رمز التحقق الخاص بك هو:\n123456\n\nصالح لمدة 5 دقائق.'
      };
      request.headers.addAll(headers);
      
      http.StreamedResponse response = await request.send();
      String responseBody = await response.stream.bytesToString();
      
      print('🧪 Test Response: ${response.statusCode} - $responseBody');
      
      return {
        'success': response.statusCode == 200,
        'statusCode': response.statusCode,
        'response': responseBody,
      };
    } catch (e) {
      print('❌ Test Error: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  // Verify OTP (same as SMS service)
  static bool verifyOTP(String inputOTP, String storedOTP, DateTime otpCreatedAt) {
    // Check if OTP is expired (5 minutes)
    DateTime now = DateTime.now();
    Duration difference = now.difference(otpCreatedAt);
    
    if (difference.inMinutes > 5) {
      return false; // OTP expired
    }
    
    // Check if OTP matches
    return inputOTP == storedOTP;
  }
}