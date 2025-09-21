import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hospital_app/screnns/patient_home_screen.dart';
import 'package:hospital_app/screnns/register_screen.dart';
import 'package:hospital_app/services/sms_service.dart';
import 'package:hospital_app/services/whatsapp_service.dart';
import 'package:hospital_app/screnns/otp_verification_screen.dart';
import 'package:hospital_app/models/country.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  bool _isLoading = false;
  String _verificationMethod = 'sms';
  Country _selectedCountry = Country.countries.first;
  List<String> _supportPhones = [];

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
    _loadSupportPhonesOnce();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _checkLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
    final userType = prefs.getString('userType');
    final userEmail = prefs.getString('userEmail');

    if (isLoggedIn && userType == 'patient' && userEmail != null) {
        // Patient is logged in
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => const PatientHomeScreen(),
          ),
        );
    }
  }



  Future<void> _login() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        String phoneInput = _phoneController.text.trim();
        
        // Check if input looks like a phone number
        bool isPhoneNumber = RegExp(r'^[0-9+\-\s()]+$').hasMatch(phoneInput);
        
        if (isPhoneNumber) {
          // Try multiple phone number formats
          List<String> possibleNumbers = _generatePossiblePhoneNumbers(phoneInput);
          
          bool found = false;
          String? foundPhoneNumber;
          DocumentSnapshot? foundPatient;
          
          // Search for each possible format
          for (String phoneNumber in possibleNumbers) {
            final patientsQuery = await FirebaseFirestore.instance
                .collection('patients')
                .where('phone', isEqualTo: phoneNumber)
                .get();
            
            if (patientsQuery.docs.isNotEmpty) {
              found = true;
              foundPhoneNumber = phoneNumber;
              foundPatient = patientsQuery.docs.first;
              break;
            }
          }
          
          if (found && foundPatient != null) {
            final patientData = foundPatient.data() as Map<String, dynamic>;
            final patientName = patientData['name'] ?? 'مريض عزيز';
            final normalizedPhone = foundPhoneNumber!;

            // Send OTP
            final otp = SMSService.generateOTP();
            Map<String, dynamic> result;
            if (_verificationMethod == 'whatsapp') {
              result = await WhatsAppService.sendOTP(normalizedPhone, otp);
            } else {
              result = await SMSService.sendOTP(normalizedPhone, otp);
            }

            setState(() { _isLoading = false; });

            if (result['success']) {
              if (mounted) {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => OTPVerificationScreen(
                      phoneNumber: normalizedPhone,
                      name: patientName,
                      password: '',
                      initialOtp: otp,
                      initialOtpCreatedAt: DateTime.now(),
                      country: _selectedCountry,
                      verificationMethod: _verificationMethod,
                      isLoginFlow: true,
                    ),
                  ),
                );
              }
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('فشل إرسال رمز التحقق: ${result['message']}'), backgroundColor: Colors.red),
              );
            }
          } else {
            setState(() {
              _isLoading = false;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('رقم الهاتف غير موجود'),
                backgroundColor: Colors.red,
              ),
            );
          }
        } else {
          setState(() {
            _isLoading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('يرجى إدخال رقم هاتف صحيح'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } catch (e) {
        setState(() {
          _isLoading = false;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('حدث خطأ: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  // Generate possible phone number formats for search
  List<String> _generatePossiblePhoneNumbers(String phoneInput) {
    List<String> possibleNumbers = [];
    String digitsOnly = phoneInput.replaceAll(RegExp(r'[^0-9]'), '');
    
    // Add the original input as is
    possibleNumbers.add(digitsOnly);
    
    // Try different country codes
    for (Country country in Country.countries) {
      String countryCode = country.dialCode.replaceAll('+', '');
      
      // If number already has country code, add as is
      if (digitsOnly.startsWith(countryCode)) {
        possibleNumbers.add(digitsOnly);
        continue;
      }
      
      // Try adding country code
      String withCountryCode = countryCode + digitsOnly;
      possibleNumbers.add(withCountryCode);
      
      // If number starts with 0, try removing it and adding country code
      if (digitsOnly.startsWith('0')) {
        String withoutLeadingZero = digitsOnly.substring(1);
        String withCountryCodeNoZero = countryCode + withoutLeadingZero;
        possibleNumbers.add(withCountryCodeNoZero);
      }
    }
    
    // Remove duplicates
    return possibleNumbers.toSet().toList();
  }



  void _registerWithUsername() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const RegisterScreen()),
    );
  }

  Future<void> _loadSupportPhonesOnce() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('support')
          .doc('phones')
          .get()
          .timeout(const Duration(seconds: 3));
      if (doc.exists) {
        final data = doc.data();
        final numbers = (data?['numbers'] as List?)
            ?.map((e) => (e ?? '').toString().trim())
            .where((s) => s.isNotEmpty)
            .toList() ?? [];
        if (mounted) {
          setState(() {
            _supportPhones = numbers;
          });
        }
      }
    } catch (e) {
      print('خطأ في تحميل أرقام الدعم: $e');
    }
  }

  void _showTechnicalSupportDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            contentPadding: const EdgeInsets.all(20),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title
                Text(
                  "الدعم الفني",
                  style: TextStyle(
                    color: const Color(0xFF2FBDAF),
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 12),
                
                // Description
                Text(
                  "يرجى الاتصال على الأرقام التالية:",
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 12),
                
                // Phone Numbers (from Firestore)
                if (_supportPhones.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(
                      "لا توجد أرقام متاحة حالياً",
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    ),
                  )
                else
                  ...List.generate(_supportPhones.length, (i) => 
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: GestureDetector(
                        onTap: () => _makePhoneCall(_supportPhones[i]),
                        onLongPress: () => _copyPhoneNumber(_supportPhones[i]),
                        child: Text(
                          _supportPhones[i],
                          style: TextStyle(
                            color: const Color(0xFF2FBDAF),
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  'إغلاق',
                  style: TextStyle(
                    color: const Color(0xFF2FBDAF),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri phoneUri = Uri(scheme: 'tel', path: phoneNumber);
    try {
      if (await canLaunchUrl(phoneUri)) {
        await launchUrl(phoneUri);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('لا يمكن فتح تطبيق الهاتف'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطأ في الاتصال: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _copyPhoneNumber(String phoneNumber) {
    Clipboard.setData(ClipboardData(text: phoneNumber));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('تم نسخ الرقم: $phoneNumber'),
        backgroundColor: const Color(0xFF2FBDAF),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF2FBDAF).withOpacity(0.1), // لون أزرق أخضر فاتح
              Colors.grey[50]!, // رمادي فاتح جداً
            ],
          ),
        ),
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
                          width: 120,
                          height: 120,
                          child: Image.asset(
                            'assets/images/logo.png',
                            fit: BoxFit.contain,
                          ),
                        ),
                        const SizedBox(height: 24),
                        
                        // Title
                        const Text(
                          'تسجيل الدخول',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.black, // لون أسود
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'سجل دخولك للمتابعة',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.black87, // لون أسود فاتح قليلاً
                          ),
                        ),
                        const SizedBox(height: 32),

                        // Phone number field
                        TextFormField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          decoration: InputDecoration(
                            labelText: "رقم الهاتف",
                            hintText: "أدخل رقم الهاتف",
                            prefixIcon: const Icon(Icons.phone, color: Color(0xFF2FBDAF)),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: Color(0xFF2FBDAF),
                                width: 2,
                              ),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'يرجى إدخال رقم الهاتف';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 24),

                        // Verification method selection
                        Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setState(() => _verificationMethod = 'sms'),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                                  decoration: BoxDecoration(
                                    color: _verificationMethod == 'sms' ? const Color(0xFFE0F2F1) : Colors.white,
                                    border: Border.all(
                                      color: _verificationMethod == 'sms' ? const Color(0xFF2FBDAF) : Colors.grey[300]!,
                                      width: 1.5,
                                    ),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      if (_verificationMethod == 'sms') const Icon(Icons.check, color: Color(0xFF2FBDAF), size: 16),
                                      if (_verificationMethod == 'sms') const SizedBox(width: 6),
                                      Text(
                                        'رسالة نصية',
                                        style: TextStyle(
                                          color: _verificationMethod == 'sms' ? Colors.black87 : Colors.grey[600],
                                          fontWeight: FontWeight.w500,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setState(() => _verificationMethod = 'whatsapp'),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                                  decoration: BoxDecoration(
                                    color: _verificationMethod == 'whatsapp' ? const Color(0xFFE0F2F1) : Colors.white,
                                    border: Border.all(
                                      color: _verificationMethod == 'whatsapp' ? const Color(0xFF2FBDAF) : Colors.grey[300]!,
                                      width: 1.5,
                                    ),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      if (_verificationMethod == 'whatsapp') const Icon(Icons.check, color: Color(0xFF2FBDAF), size: 16),
                                      if (_verificationMethod == 'whatsapp') const SizedBox(width: 6),
                                      Text(
                                        'واتساب',
                                        style: TextStyle(
                                          color: _verificationMethod == 'whatsapp' ? Colors.black87 : Colors.grey[600],
                                          fontWeight: FontWeight.w500,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Login button
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _login,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Color(0xFF2FBDAF),
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
                                    'تسجيل الدخول',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Register link
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              'ليس لديك حساب؟ ',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 14,
                              ),
                            ),
                            TextButton(
                              onPressed: _registerWithUsername,
                              child: const Text(
                                'إنشاء حساب',
                                style: TextStyle(
                                  color: Color(0xFF2FBDAF),
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // Technical Support Footer
                        GestureDetector(
                          onTap: _showTechnicalSupportDialog,
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.support_agent,
                                      color: Colors.grey[600],
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Column(
                                      children: [
                                        Text(
                                          "الدعم الفني",
                                          style: TextStyle(
                                            fontSize: 16,
                                            color: Colors.grey[600],
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Container(
                                          width: 60,
                                          height: 1,
                                          color: Colors.grey[400],
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
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
