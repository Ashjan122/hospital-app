import 'package:flutter/material.dart';
import 'package:hospital_app/screnns/patient_home_screen.dart';
import 'package:hospital_app/screnns/register_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isPasswordVisible = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
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

  Future<void> _saveLoginData(String userType, {String? userEmail, String? userName, String? userId}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedIn', true);
    await prefs.setString('userType', userType);
    
    if (userEmail != null) await prefs.setString('userEmail', userEmail);
    if (userName != null) await prefs.setString('userName', userName);
    if (userId != null) await prefs.setString('userId', userId);
  }

  Future<void> _saveFCMTokenForPatient(String patientId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final fcmToken = prefs.getString('fcm_token');
      
      if (fcmToken != null) {
        await FirebaseFirestore.instance
            .collection('patients')
            .doc(patientId)
            .update({
          'fcmToken': fcmToken,
          'lastTokenUpdate': FieldValue.serverTimestamp(),
        });
        print('تم حفظ FCM token للمريض: $patientId');
      }
    } catch (e) {
      print('خطأ في حفظ FCM token: $e');
    }
  }

  Future<void> _login() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
          // Check if input looks like a phone number
          bool isPhoneNumber = RegExp(r'^[0-9+\-\s()]+$').hasMatch(_usernameController.text.trim());
          
          if (isPhoneNumber) {
            // Format phone number for search
            String searchPhoneNumber = _usernameController.text.trim();
            
            // Remove any non-digit characters
            String digitsOnly = searchPhoneNumber.replaceAll(RegExp(r'[^0-9]'), '');
            
            // If it's a 9-digit number starting with 1 or 9, add country code
            if (digitsOnly.length == 9 && (digitsOnly.startsWith('1') || digitsOnly.startsWith('9'))) {
              searchPhoneNumber = '249$digitsOnly';
            }
            // If it's a 10-digit number starting with 01 or 09, remove first digit and add country code
            else if (digitsOnly.length == 10 && (digitsOnly.startsWith('01') || digitsOnly.startsWith('09'))) {
              searchPhoneNumber = '249${digitsOnly.substring(1)}';
            }
            // If it's already 12 digits starting with 249, use as is
            else if (digitsOnly.length == 12 && digitsOnly.startsWith('249')) {
              searchPhoneNumber = digitsOnly;
            }
            // If it's 12 digits starting with +249, remove + and use
            else if (digitsOnly.length == 12 && searchPhoneNumber.startsWith('+249')) {
              searchPhoneNumber = digitsOnly;
            }
            // If it's 11 digits starting with +249, remove + and use
            else if (digitsOnly.length == 11 && searchPhoneNumber.startsWith('+249')) {
              searchPhoneNumber = digitsOnly;
            }
            
            // Patient login with phone number
            // First, find the patient by phone number in Firestore
            final patientsQuery = await FirebaseFirestore.instance
                .collection('patients')
                .where('phone', isEqualTo: searchPhoneNumber)
                .get();

                        if (patientsQuery.docs.isNotEmpty) {
              final patientDoc = patientsQuery.docs.first;
              final patientData = patientDoc.data();
              final patientPassword = patientData['password'] ?? '';

              if (patientPassword == _passwordController.text) {
                // Direct login without Firebase Auth for phone-based login
                final patientName = patientData['name'] ?? 'مريض عزيز';
                final patientId = patientDoc.id;
                
                // Save patient login data
                await _saveLoginData('patient', userEmail: searchPhoneNumber, userName: patientName, userId: patientId);
                
                // Save phone number separately for lab results
                final prefs = await SharedPreferences.getInstance();
                await prefs.setString('userPhone', searchPhoneNumber);
                
                // Save FCM token for patient
                await _saveFCMTokenForPatient(patientId);
                
                if (mounted) {
                  setState(() {
                    _isLoading = false;
                  });
                  
                  // Patient login - redirect to patient home screen
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (context) => const PatientHomeScreen()),
                  );
                                 }
              } else {
                setState(() {
                  _isLoading = false;
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('كلمة المرور غير صحيحة'),
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
                  content: Text('رقم الهاتف غير موجود'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          } else {
          // Not a valid phone number
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



  void _registerWithUsername() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const RegisterScreen()),
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

                        // Username/Email/Phone field
                        TextFormField(
                          controller: _usernameController,
                          decoration: InputDecoration(
                            labelText: "رقم الهاتف",
                            hintText: "أدخل رقم الهاتف",
                            prefixIcon: const Icon(Icons.person, color: Color(0xFF2FBDAF)),
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
                        const SizedBox(height: 16),

                        // Password field
                        TextFormField(
                          controller: _passwordController,
                          obscureText: !_isPasswordVisible,
                          decoration: InputDecoration(
                            labelText: 'كلمة المرور',
                            prefixIcon: const Icon(Icons.lock, color: Color(0xFF2FBDAF)),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _isPasswordVisible
                                    ? Icons.visibility
                                    : Icons.visibility_off,
                                color: const Color(0xFF2FBDAF),
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
                                color: Color(0xFF2FBDAF),
                                width: 2,
                              ),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'يرجى إدخال كلمة المرور';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 24),

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
