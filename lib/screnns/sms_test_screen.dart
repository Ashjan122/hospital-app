import 'package:flutter/material.dart';
import 'package:hospital_app/services/sms_service.dart';

class SMSTestScreen extends StatefulWidget {
  const SMSTestScreen({super.key});

  @override
  State<SMSTestScreen> createState() => _SMSTestScreenState();
}

class _SMSTestScreenState extends State<SMSTestScreen> {
  final _phoneController = TextEditingController();
  bool _isLoading = false;
  String _result = '';

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _testSMS() async {
    if (_phoneController.text.trim().isEmpty) {
      setState(() {
        _result = 'يرجى إدخال رقم الهاتف';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _result = 'جاري إرسال الرسالة...';
    });

    try {
      String otp = SMSService.generateOTP();
      Map<String, dynamic> result = await SMSService.sendOTP(_phoneController.text.trim(), otp);

      setState(() {
        _isLoading = false;
        if (result['success']) {
          _result = 'تم إرسال الرسالة بنجاح!\nرمز التحقق: $otp';
          if (result['apiMsgId'] != null) {
            _result += '\nمعرف الرسالة: ${result['apiMsgId']}';
          }
        } else {
          _result = 'فشل في إرسال الرسالة: ${result['message']}';
        }
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _result = 'حدث خطأ: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          centerTitle: true,
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            onPressed: () => Navigator.pop(context),
            icon: Icon(Icons.arrow_back, color: Color.fromARGB(255, 78, 17, 175)),
          ),
          title: Text(
            "اختبار SMS",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: const Color.fromARGB(255, 78, 17, 175),
              fontSize: 24,
            ),
          ),
        ),
        body: Container(
          color: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                // Phone number input
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: 'رقم الهاتف',
                    prefixIcon: const Icon(Icons.phone, color: Color.fromARGB(255, 78, 17, 175)),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: Color.fromARGB(255, 78, 17, 175),
                        width: 2,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Test button
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _testSMS,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color.fromARGB(255, 78, 17, 175),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : const Text(
                            'اختبار إرسال SMS',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 24),

                // Result display
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'النتيجة:',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: const Color.fromARGB(255, 78, 17, 175),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _result.isEmpty ? 'لم يتم إرسال أي رسالة بعد' : _result,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
