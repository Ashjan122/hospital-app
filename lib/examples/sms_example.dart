import 'package:flutter/material.dart';
import '../services/sms_service.dart';

class SMSExample extends StatefulWidget {
  const SMSExample({super.key});

  @override
  State<SMSExample> createState() => _SMSExampleState();
}

class _SMSExampleState extends State<SMSExample> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();
  String? _generatedOTP;
  DateTime? _otpCreatedAt;
  bool _isLoading = false;
  String _resultMessage = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SMS Service Example'),
        backgroundColor: Colors.blue,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Phone number input
            TextField(
              controller: _phoneController,
              decoration: const InputDecoration(
                labelText: 'رقم الهاتف',
                hintText: 'مثال: 09124584291',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 16),

            // Generate and send OTP button
            ElevatedButton(
              onPressed: _isLoading ? null : _generateAndSendOTP,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text(
                      'إرسال رمز التحقق',
                      style: TextStyle(fontSize: 16, color: Colors.white),
                    ),
            ),
            const SizedBox(height: 16),

            // Generated OTP display (for testing)
            if (_generatedOTP != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  border: Border.all(color: Colors.blue),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    const Text(
                      'رمز التحقق المُنشأ (للاختبار فقط):',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _generatedOTP!,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                    if (_otpCreatedAt != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        'تم الإنشاء في: ${_otpCreatedAt!.toString().substring(0, 19)}',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // OTP verification input
            TextField(
              controller: _otpController,
              decoration: const InputDecoration(
                labelText: 'رمز التحقق',
                hintText: 'أدخل رمز التحقق المكون من 6 أرقام',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              maxLength: 6,
            ),
            const SizedBox(height: 16),

            // Verify OTP button
            ElevatedButton(
              onPressed: _generatedOTP == null ? null : _verifyOTP,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text(
                'التحقق من الرمز',
                style: TextStyle(fontSize: 16, color: Colors.white),
              ),
            ),
            const SizedBox(height: 16),

            // Test simple SMS button
            ElevatedButton(
              onPressed: _isLoading ? null : _testSimpleSMS,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text(
                'اختبار إرسال رسالة بسيطة',
                style: TextStyle(fontSize: 16, color: Colors.white),
              ),
            ),
            const SizedBox(height: 24),

            // Result message
            if (_resultMessage.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _resultMessage.contains('نجح') || _resultMessage.contains('success')
                      ? Colors.green.shade50
                      : Colors.red.shade50,
                  border: Border.all(
                    color: _resultMessage.contains('نجح') || _resultMessage.contains('success')
                        ? Colors.green
                        : Colors.red,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _resultMessage,
                  style: TextStyle(
                    color: _resultMessage.contains('نجح') || _resultMessage.contains('success')
                        ? Colors.green.shade800
                        : Colors.red.shade800,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _generateAndSendOTP() async {
    if (_phoneController.text.isEmpty) {
      setState(() {
        _resultMessage = 'يرجى إدخال رقم الهاتف';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _resultMessage = 'جاري إرسال رمز التحقق...';
    });

    try {
      // Generate OTP
      String otp = SMSService.generateOTP();
      DateTime createdAt = DateTime.now();

      // Send OTP via SMS
      Map<String, dynamic> result = await SMSService.sendOTP(
        _phoneController.text,
        otp,
      );

      setState(() {
        _isLoading = false;
        _generatedOTP = otp;
        _otpCreatedAt = createdAt;
        
        if (result['success']) {
          _resultMessage = 'تم إرسال رمز التحقق بنجاح!';
          if (result['apiMsgId'] != null) {
            _resultMessage += '\nمعرف الرسالة: ${result['apiMsgId']}';
          }
        } else {
          _resultMessage = 'فشل في إرسال رمز التحقق: ${result['message']}';
        }
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _resultMessage = 'خطأ: $e';
      });
    }
  }

  void _verifyOTP() {
    if (_otpController.text.isEmpty) {
      setState(() {
        _resultMessage = 'يرجى إدخال رمز التحقق';
      });
      return;
    }

    if (_generatedOTP == null || _otpCreatedAt == null) {
      setState(() {
        _resultMessage = 'يرجى إرسال رمز التحقق أولاً';
      });
      return;
    }

    bool isValid = SMSService.verifyOTP(
      _otpController.text,
      _generatedOTP!,
      _otpCreatedAt!,
    );

    setState(() {
      if (isValid) {
        _resultMessage = '✅ رمز التحقق صحيح! تم التحقق بنجاح.';
      } else {
        _resultMessage = '❌ رمز التحقق غير صحيح أو منتهي الصلاحية.';
      }
    });
  }

  Future<void> _testSimpleSMS() async {
    if (_phoneController.text.isEmpty) {
      setState(() {
        _resultMessage = 'يرجى إدخال رقم الهاتف';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _resultMessage = 'جاري إرسال رسالة الاختبار...';
    });

    try {
      Map<String, dynamic> result = await SMSService.sendSimpleSMS(
        _phoneController.text,
        'مرحباً! هذه رسالة اختبار من تطبيق المستشفى.',
      );

      setState(() {
        _isLoading = false;
        
        if (result['success']) {
          _resultMessage = 'تم إرسال رسالة الاختبار بنجاح!';
          if (result['apiMsgId'] != null) {
            _resultMessage += '\nمعرف الرسالة: ${result['apiMsgId']}';
          }
        } else {
          _resultMessage = 'فشل في إرسال رسالة الاختبار: ${result['message']}';
        }
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _resultMessage = 'خطأ: $e';
      });
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }
}
