import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hospital_app/services/sms_service.dart';
import 'package:hospital_app/screnns/otp_verification_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (_formKey.currentState!.validate()) {
      if (_passwordController.text != _confirmPasswordController.text) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('كلمات المرور غير متطابقة'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      setState(() {
        _isLoading = true;
      });

      try {
        // Validate and format phone number
        final phoneNumber = _phoneController.text.trim();
        // Remove any non-digit characters and the prefix
        String digitsOnly = phoneNumber.replaceAll(RegExp(r'[^0-9]'), '');
        
        // If it starts with 249, remove it
        if (digitsOnly.startsWith('249')) {
          digitsOnly = digitsOnly.substring(3);
        }
        
        // If it's 10 digits and starts with 0, remove the 0
        if (digitsOnly.length == 10 && digitsOnly.startsWith('0')) {
          digitsOnly = digitsOnly.substring(1);
        }
        
        if (digitsOnly.length != 9) {
          setState(() {
            _isLoading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('رقم الهاتف يجب أن يكون 9 أرقام (بدون المفتاح)'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }
        
        // Check if it starts with valid Sudanese prefixes (1 or 9)
        if (!digitsOnly.startsWith('1') && !digitsOnly.startsWith('9')) {
          setState(() {
            _isLoading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('رقم الهاتف يجب أن يبدأ بـ 1 أو 9'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }
        
        // Format phone number with country code
        final formattedPhoneNumber = '249$digitsOnly';

        // Validate password strength
        if (_passwordController.text.length < 6) {
          setState(() {
            _isLoading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('كلمة المرور يجب أن تكون 6 أحرف على الأقل'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }

        // Check if phone number already exists
        final existingPatient = await FirebaseFirestore.instance
            .collection('patients')
            .where('phone', isEqualTo: formattedPhoneNumber)
            .get();

        if (existingPatient.docs.isNotEmpty) {
          setState(() {
            _isLoading = false;
          });
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

        // Generate OTP and send SMS
        print('🔍 بدء عملية إنشاء الحساب...');
        print('📱 رقم الهاتف: $formattedPhoneNumber');
        
        String otp = SMSService.generateOTP();
        print('🔐 رمز التحقق المُنشأ: $otp');
        
        print('📡 إرسال رمز التحقق...');
        Map<String, dynamic> result = await SMSService.sendOTP(formattedPhoneNumber, otp);
        print('📊 نتيجة الإرسال: $result');

        if (result['success']) {
          if (mounted) {
            setState(() {
              _isLoading = false;
            });

            // Navigate to OTP verification screen
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => OTPVerificationScreen(
                  phoneNumber: formattedPhoneNumber,
                  name: _nameController.text.trim(),
                  password: _passwordController.text,
                  initialOtp: otp,
                  initialOtpCreatedAt: DateTime.now(),
                ),
              ),
            );
          }
        } else {
          print('❌ فشل في إرسال رمز التحقق');
          print('السبب: ${result['message']}');
          print('رمز الاستجابة: ${result['statusCode']}');
          
          setState(() {
            _isLoading = false;
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('فشل في إرسال رمز التحقق: ${result['message']}'),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 5),
              ),
            );
          }
        }
      } catch (e) {
        setState(() {
          _isLoading = false;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('حدث خطأ في إنشاء الحساب: $e'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'إنشاء حساب جديد',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontSize: 20,
          ),
        ),
        backgroundColor: const Color.fromARGB(255, 78, 17, 175),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Container(
        color: Colors.white,
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Card(
                elevation: 8,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Logo/Icon
                        Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            color: const Color.fromARGB(255, 78, 17, 175),
                            borderRadius: BorderRadius.circular(50),
                          ),
                          child: const Icon(
                            Icons.person_add,
                            size: 50,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 24),
                        
                        // Title
                        const Text(
                          'إنشاء حساب جديد',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Color.fromARGB(255, 78, 17, 175),
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'أدخل بياناتك لإنشاء حساب',
                          style: TextStyle(
                            fontSize: 16,
                            color: Color.fromARGB(255, 78, 17, 175),
                          ),
                        ),
                        const SizedBox(height: 32),

                        // Phone field with country code
                        TextFormField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          decoration: InputDecoration(
                            labelText: 'رقم الهاتف *',
                            hintText: '01XXXXXXXX أو 09XXXXXXXX',
                            prefixIcon: const Icon(Icons.phone, color: Color.fromARGB(255, 78, 17, 175)),
                            prefixText: '+249 ',
                            prefixStyle: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color.fromARGB(255, 78, 17, 175),
                            ),
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
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'يرجى إدخال رقم الهاتف';
                            }
                            // Remove any non-digit characters and the prefix
                            String digitsOnly = value.replaceAll(RegExp(r'[^0-9]'), '');
                            
                            // If it starts with 249, remove it
                            if (digitsOnly.startsWith('249')) {
                              digitsOnly = digitsOnly.substring(3);
                            }
                            
                            // If it's 10 digits and starts with 0, remove the 0
                            if (digitsOnly.length == 10 && digitsOnly.startsWith('0')) {
                              digitsOnly = digitsOnly.substring(1);
                            }
                            
                            if (digitsOnly.length != 9) {
                              return 'رقم الهاتف يجب أن يكون 9 أرقام (بدون المفتاح)';
                            }
                            
                            // Check if it starts with valid Sudanese prefixes (1 or 9)
                            if (!digitsOnly.startsWith('1') && !digitsOnly.startsWith('9')) {
                              return 'رقم الهاتف يجب أن يبدأ بـ 1 أو 9';
                            }
                            
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // Name field
                        TextFormField(
                          controller: _nameController,
                          decoration: InputDecoration(
                            labelText: 'الاسم الكامل',
                            prefixIcon: const Icon(Icons.person, color: Color.fromARGB(255, 78, 17, 175)),
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
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'يرجى إدخال الاسم الكامل';
                            }
                            if (value.length < 3) {
                              return 'الاسم يجب أن يكون 3 أحرف على الأقل';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),



                        // Password field
                        TextFormField(
                          controller: _passwordController,
                          obscureText: !_isPasswordVisible,
                          decoration: InputDecoration(
                            labelText: 'كلمة المرور',
                            prefixIcon: const Icon(Icons.lock, color: Color.fromARGB(255, 78, 17, 175)),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _isPasswordVisible
                                    ? Icons.visibility
                                    : Icons.visibility_off,
                                color: const Color.fromARGB(255, 78, 17, 175),
                              ),
                              onPressed: () {
                                setState(() {
                                  _isPasswordVisible = !_isPasswordVisible;
                                });
                              },
                            ),
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
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'يرجى إدخال كلمة المرور';
                            }
                            if (value.length < 6) {
                              return 'كلمة المرور يجب أن تكون 6 أحرف على الأقل';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // Confirm Password field
                        TextFormField(
                          controller: _confirmPasswordController,
                          obscureText: !_isConfirmPasswordVisible,
                          decoration: InputDecoration(
                            labelText: 'تأكيد كلمة المرور',
                            prefixIcon: const Icon(Icons.lock_outline, color: Color.fromARGB(255, 78, 17, 175)),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _isConfirmPasswordVisible
                                    ? Icons.visibility
                                    : Icons.visibility_off,
                                color: const Color.fromARGB(255, 78, 17, 175),
                              ),
                              onPressed: () {
                                setState(() {
                                  _isConfirmPasswordVisible = !_isConfirmPasswordVisible;
                                });
                              },
                            ),
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
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'يرجى تأكيد كلمة المرور';
                            }
                            if (value != _passwordController.text) {
                              return 'كلمات المرور غير متطابقة';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 24),

                        // Register button
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _register,
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
                                    'إرسال رمز التحقق',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Back to login
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              'لديك حساب بالفعل؟ ',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 14,
                              ),
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.of(context).pop();
                              },
                              child: const Text(
                                'تسجيل الدخول',
                                style: TextStyle(
                                  color: Color.fromARGB(255, 78, 17, 175),
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
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
          ),
        ),
      ),
    );
  }
}
