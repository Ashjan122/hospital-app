import 'package:flutter/material.dart';
import 'package:hospital_app/screnns/patient_home_screen.dart';
import 'package:hospital_app/screnns/register_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hospital_app/models/country.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
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
            final patientId = foundPatient.id;
            
            // Save patient login data
            await _saveLoginData('patient', userEmail: foundPhoneNumber!, userName: patientName, userId: patientId);
            
            // Save phone number separately for lab results
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('userPhone', foundPhoneNumber);
            
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
