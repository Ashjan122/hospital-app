import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hospital_app/services/sms_service.dart';
import 'package:hospital_app/services/whatsapp_service.dart';
import 'package:hospital_app/models/country.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'package:hospital_app/screnns/patient_home_screen.dart';
import 'package:sms_autofill/sms_autofill.dart';

class OTPVerificationScreen extends StatefulWidget {
  final String phoneNumber;
  final String name;
  final String password;
  final String initialOtp;
  final DateTime initialOtpCreatedAt;
  final Country country;
  final String verificationMethod;

  const OTPVerificationScreen({
    super.key,
    required this.phoneNumber,
    required this.name,
    required this.password,
    required this.initialOtp,
    required this.initialOtpCreatedAt,
    required this.country,
    required this.verificationMethod,
  });

  @override
  State<OTPVerificationScreen> createState() => _OTPVerificationScreenState();
}

class _OTPVerificationScreenState extends State<OTPVerificationScreen> {
  final List<TextEditingController> _otpControllers = List.generate(
    6,
    (index) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(
    6,
    (index) => FocusNode(),
  );

  bool _isLoading = false;
  bool _isResending = false;
  int _remainingTime = 300; // 5 minutes in seconds
  Timer? _timer;
  Timer? _clipboardTimer;
  
  // Current OTP state
  late String _currentOtp;
  late DateTime _currentOtpCreatedAt;
  String? _appSignature;

  @override
  void initState() {
    super.initState();
    _currentOtp = widget.initialOtp;
    _currentOtpCreatedAt = widget.initialOtpCreatedAt;
    _startTimer();
    _initOtpAutoFill();
    _startClipboardListener();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _clipboardTimer?.cancel();
    SmsAutoFill().unregisterListener();
    for (var controller in _otpControllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  Future<void> _initOtpAutoFill() async {
    try {
      _appSignature = await SmsAutoFill().getAppSignature;
      // Listen for incoming SMS code (Android)
      await SmsAutoFill().listenForCode();
      SmsAutoFill().code.listen((code) {
        if (code.isNotEmpty) {
          final match = RegExp(r'\d{4,6}').firstMatch(code);
          if (match != null) {
            _fillOtp(match.group(0)!);
          }
        }
      });
    } catch (e) {
      // Ignore if not supported (iOS/permissions)
    }
  }

  void _startClipboardListener() {
    // Fallback for WhatsApp: poll clipboard briefly to detect OTP copied
    _clipboardTimer = Timer.periodic(const Duration(seconds: 2), (t) async {
      try {
        final data = await Clipboard.getData('text/plain');
        final text = data?.text ?? '';
        if (text.isNotEmpty) {
          final match = RegExp(r'\b(\d{6})\b').firstMatch(text);
          if (match != null) {
            _fillOtp(match.group(1)!);
            t.cancel();
          }
        }
      } catch (_) {}
    });
  }

  void _fillOtp(String code) {
    if (code.length < 4) return;
    final six = code.length >= 6 ? code.substring(0, 6) : code.padRight(6, '0');
    for (int i = 0; i < 6; i++) {
      _otpControllers[i].text = six[i];
    }
    // Move focus away and verify automatically
    FocusScope.of(context).unfocus();
    _verifyOTP();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingTime > 0) {
        setState(() {
          _remainingTime--;
        });
      } else {
        timer.cancel();
      }
    });
  }

  String _formatTime(int seconds) {
    int minutes = seconds ~/ 60;
    int remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  Future<void> _resendOTP() async {
    setState(() {
      _isResending = true;
    });

    try {
      String newOTP = SMSService.generateOTP();
      Map<String, dynamic> result;
      
      if (widget.verificationMethod == 'whatsapp') {
        result = await WhatsAppService.sendOTP(widget.phoneNumber, newOTP);
      } else {
        result = await SMSService.sendOTP(widget.phoneNumber, newOTP);
      }

      if (result['success']) {
        // Update the OTP in the state
        _currentOtp = newOTP;
        _currentOtpCreatedAt = DateTime.now();
        
        setState(() {
          _remainingTime = 300; // Reset timer
        });
        _startTimer();

        if (mounted) {
          String methodText = widget.verificationMethod == 'whatsapp' ? 'واتساب' : 'رسالة نصية';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('تم إرسال رمز التحقق الجديد عبر $methodText'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('فشل في إرسال رمز التحقق'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isResending = false;
      });
    }
  }

  Future<void> _verifyOTP() async {
    // Get the entered OTP
    String enteredOTP = _otpControllers.map((controller) => controller.text).join();
    
    if (enteredOTP.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى إدخال رمز التحقق المكون من 6 أرقام'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Verify OTP
      bool isValid = SMSService.verifyOTP(enteredOTP, _currentOtp, _currentOtpCreatedAt);

      if (isValid) {
        // Create the patient account
        await _createPatientAccount();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('رمز التحقق غير صحيح أو منتهي الصلاحية'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _createPatientAccount() async {
    try {
      // Check if phone number already exists
      final existingPatient = await FirebaseFirestore.instance
          .collection('patients')
          .where('phone', isEqualTo: widget.phoneNumber)
          .get();

      if (existingPatient.docs.isNotEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('رقم الهاتف مستخدم بالفعل'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // Generate a unique ID for the patient
      final patientId = 'patient_${DateTime.now().millisecondsSinceEpoch}_${widget.phoneNumber}';

      // Save patient data to Firestore
      await FirebaseFirestore.instance
          .collection('patients')
          .doc(patientId)
          .set({
        'name': widget.name,
        'phone': widget.phoneNumber,
        'password': widget.password,
        'createdAt': FieldValue.serverTimestamp(),
        'isActive': true,
        'verified': true, // Mark as verified
      });

      // Save login data in SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isLoggedIn', true);
      await prefs.setString('userType', 'patient');
      await prefs.setString('userName', widget.name);
      await prefs.setString('userEmail', widget.phoneNumber);
      await prefs.setString('userId', patientId);
      await prefs.setString('userPhone', widget.phoneNumber);

      if (mounted) {
        // Go to home screen immediately
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const PatientHomeScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ في إنشاء الحساب: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _onOTPChanged(String value, int index) {
    if (value.length == 1 && index < 5) {
      _focusNodes[index + 1].requestFocus();
    } else if (value.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
    }

    // Check if all OTP digits are entered
    String fullOTP = _otpControllers.map((controller) => controller.text).join();
    if (fullOTP.length == 6) {
      _verifyOTP();
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
            icon: Icon(Icons.arrow_back, color: Color(0xFF2FBDAF)),
          ),
          title: Text(
            "التحقق من رقم الهاتف",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: const Color(0xFF2FBDAF),
              fontSize: 24,
            ),
          ),
        ),
        body: SafeArea(
          child: Container(
            color: Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  // Phone number display
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color.fromARGB(255, 78, 17, 175).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color.fromARGB(255, 78, 17, 175).withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.phone,
                          color: const Color(0xFF2FBDAF),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'رقم الهاتف',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                              ),
                              Text(
                                widget.phoneNumber,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF2FBDAF),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // OTP input fields
                  Text(
                    'أدخل رمز التحقق المرسل إلى رقم هاتفك عبر ${widget.verificationMethod == 'whatsapp' ? 'واتساب' : 'رسالة نصية'}',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[700],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),

                  Directionality(
                    textDirection: TextDirection.ltr,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: List.generate(
                        6,
                        (index) => SizedBox(
                          width: 45,
                          child: TextField(
                            controller: _otpControllers[index],
                            focusNode: _focusNodes[index],
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            maxLength: 1,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            onChanged: (value) => _onOTPChanged(value, index),
                            decoration: InputDecoration(
                              counterText: '',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(
                                  color: const Color(0xFF2FBDAF),
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(
                                  color: Color(0xFF2FBDAF),
                                  width: 2,
                                ),
                              ),
                            ),
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF2FBDAF),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Timer
                  if (_remainingTime > 0)
                    Text(
                      'الوقت المتبقي: ${_formatTime(_remainingTime)}',
                      style: TextStyle(
                        fontSize: 16,
                        color: _remainingTime < 60 ? Colors.red : Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  const SizedBox(height: 16),

                  // Verify button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _verifyOTP,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2FBDAF),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text(
                              'تحقق من الرمز',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Resend OTP button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'لم تستلم الرمز؟ ',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                        ),
                      ),
                      TextButton(
                        onPressed: _isResending || _remainingTime > 0 ? null : _resendOTP,
                        child: _isResending
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Text(
                                'إعادة إرسال',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: _remainingTime > 0
                                      ? Colors.grey
                                      : const Color(0xFF2FBDAF),
                                ),
                              ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
