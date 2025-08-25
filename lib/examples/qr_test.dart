import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'dart:convert';

class QRTestScreen extends StatelessWidget {
  const QRTestScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // بيانات تجريبية للحجز
    Map<String, String> bookingData = {
      'bookingId': 'TEST123456',
      'patientName': 'أحمد محمد',
    };

    String qrData = jsonEncode(bookingData);

    return Scaffold(
      appBar: AppBar(
        title: const Text('اختبار QR Code'),
        backgroundColor: const Color(0xFF2FBDAF),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'QR Code للحجز',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            QrImageView(
              data: qrData,
              version: QrVersions.auto,
              size: 200.0,
              gapless: false,
              embeddedImage: null,
              embeddedImageStyle: null,
              embeddedImageEmitsError: false,
              errorStateBuilder: (context, error) => const Center(
                child: Text(
                  'خطأ في إنشاء QR Code',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'بيانات الحجز:',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Text('ID الحجز: ${bookingData['bookingId']}'),
            Text('اسم المريض: ${bookingData['patientName']}'),
          ],
        ),
      ),
    );
  }
}
