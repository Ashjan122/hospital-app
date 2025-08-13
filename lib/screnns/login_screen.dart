import 'package:flutter/material.dart';
import 'package:hospital_app/screnns/dashboard_screen.dart';
import 'package:hospital_app/screnns/hospital_screen.dart';
import 'package:hospital_app/screnns/register_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
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
          // Check if input looks like an email
          bool isEmail = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(_usernameController.text.trim());
          
          if (isEmail) {
            // Patient login with Firebase
            final userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
              email: _usernameController.text.trim(),
              password: _passwordController.text,
            );

            if (mounted) {
              setState(() {
                _isLoading = false;
              });

              // Check if user exists in patients collection
              final userDoc = await FirebaseFirestore.instance
                  .collection('patients')
                  .doc(userCredential.user!.uid)
                  .get();

              if (mounted) {
                if (userDoc.exists) {
                  // Patient login - redirect to hospital screen
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (context) => const HospitalScreen()),
                  );
                } else {
                  // User not found in patients collection
                  await FirebaseAuth.instance.signOut();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('بيانات غير صحيحة'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
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
          errorMessage = 'البريد الإلكتروني غير صحيح';
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
                        
                        const SizedBox(height: 8),
                        const Text(
                          'سجل دخولك للمتابعة',
                          style: TextStyle(
                            fontSize: 16,
                            color: Color.fromARGB(255, 78, 17, 175),
                          ),
                        ),
                        const SizedBox(height: 32),

                        // Username/Email field
                        TextFormField(
                          controller: _usernameController,
                          decoration: InputDecoration(
                            labelText:"البريد الالكتروني",
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
                              return 'يرجى ادخال البريد الالكتروني';
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
