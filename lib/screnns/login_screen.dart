import 'package:flutter/material.dart';
import 'package:hospital_app/screnns/dashboard_screen.dart';
import 'package:hospital_app/screnns/patient_home_screen.dart';
import 'package:hospital_app/screnns/register_screen.dart';
import 'package:hospital_app/screnns/control_panel_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
    final centerId = prefs.getString('centerId');
    final centerName = prefs.getString('centerName');
    final userEmail = prefs.getString('userEmail');

    if (isLoggedIn) {
      if (userType == 'control') {
        // Control user is logged in
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => const ControlPanelScreen(),
          ),
        );
      } else if (userType == 'admin' && centerId != null && centerName != null) {
        // Admin is logged in
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => DashboardScreen(
              centerId: centerId,
              centerName: centerName,
            ),
          ),
        );
      } else if (userType == 'patient' && userEmail != null) {
        // Patient is logged in
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => const PatientHomeScreen(),
          ),
        );
      } else if (userType == 'user' && centerId != null && centerName != null) {
        // Internal user is logged in
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => DashboardScreen(
              centerId: centerId,
              centerName: centerName,
            ),
          ),
        );
      }
    }
  }

  Future<void> _saveLoginData(String userType, {String? centerId, String? centerName, String? userEmail, String? userName, String? userId}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedIn', true);
    await prefs.setString('userType', userType);
    
    if (centerId != null) await prefs.setString('centerId', centerId);
    if (centerName != null) await prefs.setString('centerName', centerName);
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
        // Check if control credentials (super admin)
        if (_usernameController.text.trim().toLowerCase() == 'كنترول' && _passwordController.text == '11223344') {
          // Control login - redirect to control panel
          await _saveLoginData('control');
          
          if (mounted) {
            setState(() {
              _isLoading = false;
            });
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (context) => const ControlPanelScreen(),
              ),
            );
          }
          return;
        }
        
        // Check if admin credentials (center ID or name)
        if (_passwordController.text == '12345678') {
          // Check if username is a center ID or name
          final centerQuery = await FirebaseFirestore.instance
              .collection('medicalFacilities')
              .where('available', isEqualTo: true)
              .get();

          bool isAdminLogin = false;
          String centerId = '';
          String centerName = '';

          for (var doc in centerQuery.docs) {
            final centerData = doc.data();
            final centerDocId = doc.id;
            final centerDocName = centerData['name'] ?? '';

            // Check if username matches center ID or name (case insensitive)
            if (_usernameController.text.trim() == centerDocId || 
                _usernameController.text.trim().toLowerCase() == centerDocName.toLowerCase() ||
                _usernameController.text.trim().toLowerCase().contains(centerDocName.toLowerCase()) ||
                centerDocName.toLowerCase().contains(_usernameController.text.trim().toLowerCase())) {
              isAdminLogin = true;
              centerId = centerDocId;
              centerName = centerDocName;
              break;
            }
          }

          if (isAdminLogin) {
            // Save admin login data
            await _saveLoginData('admin', centerId: centerId, centerName: centerName);
            
            // Admin login - redirect to dashboard with center info
            if (mounted) {
              setState(() {
                _isLoading = false;
              });
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (context) => DashboardScreen(
                    centerId: centerId,
                    centerName: centerName,
                  ),
                ),
              );
            }
          } else {
            // Not a valid center, show error
            setState(() {
              _isLoading = false;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('اسم المركز غير موجود أو غير مفعل'),
                backgroundColor: Colors.red,
              ),
            );
          }
        } else {
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
            // Check if it's a user login by name
            // Search for user in all medical facilities
            final centersQuery = await FirebaseFirestore.instance
                .collection('medicalFacilities')
                .where('available', isEqualTo: true)
                .get();

            bool userFound = false;
            String centerId = '';
            String centerName = '';

            for (var centerDoc in centersQuery.docs) {
              final usersQuery = await FirebaseFirestore.instance
                  .collection('medicalFacilities')
                  .doc(centerDoc.id)
                  .collection('users')
                  .where('name', isEqualTo: _usernameController.text.trim())
                  .where('isActive', isEqualTo: true)
                  .get();

              if (usersQuery.docs.isNotEmpty) {
                final userData = usersQuery.docs.first.data();
                if (userData['password'] == _passwordController.text) {
                  userFound = true;
                  centerId = centerDoc.id;
                  centerName = centerDoc.data()['name'] ?? '';
                  break;
                }
              }
            }

            if (userFound) {
              // Save user login data
              await _saveLoginData('user', centerId: centerId, centerName: centerName);
              
              // User login - redirect to dashboard
              if (mounted) {
                setState(() {
                  _isLoading = false;
                });
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (context) => DashboardScreen(
                      centerId: centerId,
                      centerName: centerName,
                    ),
                  ),
                );
              }
            } else {
              // User not found or wrong password
              setState(() {
                _isLoading = false;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('اسم المستخدم أو كلمة المرور غير صحيحة'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        }
      } on FirebaseAuthException catch (e) {
        setState(() {
          _isLoading = false;
        });

        String errorMessage = 'حدث خطأ أثناء تسجيل الدخول';
        
        if (e.code == 'user-not-found') {
          errorMessage = 'المستخدم غير موجود';
        } else if (e.code == 'wrong-password') {
          errorMessage = 'كلمة المرور غير صحيحة';
        } else if (e.code == 'invalid-email') {
          errorMessage = 'بيانات غير صحيحة';
        } else if (e.code == 'user-disabled') {
          errorMessage = 'تم تعطيل هذا الحساب';
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMessage),
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
                            Icons.local_hospital,
                            size: 50,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 24),
                        
                        // Title
                        const Text(
                          'تسجيل الدخول',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Color.fromARGB(255, 78, 17, 175),
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'سجل دخولك للمتابعة',
                          style: TextStyle(
                            fontSize: 16,
                            color: Color.fromARGB(255, 78, 17, 175),
                          ),
                        ),
                        const SizedBox(height: 32),

                        // Username/Email/Phone field
                        TextFormField(
                          controller: _usernameController,
                          decoration: InputDecoration(
                            labelText: "رقم الهاتف",
                            hintText: "أدخل رقم الهاتف",
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
