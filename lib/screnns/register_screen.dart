import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hospital_app/services/sms_service.dart';
import 'package:hospital_app/models/country.dart';
import 'package:hospital_app/screnns/otp_verification_screen.dart';
import 'package:hospital_app/screnns/login_screen.dart';
import 'package:url_launcher/url_launcher.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  
  bool _isLoading = false;
  List<String> _supportPhones = [];
  
  Country _selectedCountry = Country.countries.first;
  
  // Phone number validation patterns for different countries
  final Map<String, RegExp> _phonePatterns = {
    'SD': RegExp(r'^[19]\d{8}$'), // Sudan: 9 digits starting with 1 or 9
    'SA': RegExp(r'^5\d{8}$'), // Saudi: 9 digits starting with 5
    'AE': RegExp(r'^5\d{8}$'), // UAE: 9 digits starting with 5
    'QA': RegExp(r'^[37]\d{7}$'), // Qatar: 8 digits starting with 3 or 7
    'EG': RegExp(r'^1\d{9}$'), // Egypt: 10 digits starting with 1
    'TR': RegExp(r'^5\d{9}$'), // Turkey: 10 digits starting with 5
    'KW': RegExp(r'^[569]\d{7}$'), // Kuwait: 8 digits starting with 5,6,9
    'BH': RegExp(r'^[369]\d{7}$'), // Bahrain: 8 digits starting with 3,6,9
    'OM': RegExp(r'^[79]\d{7}$'), // Oman: 8 digits starting with 7,9
    'JO': RegExp(r'^7[789]\d{7}$'), // Jordan: 9 digits starting with 77,78,79
    'LB': RegExp(r'^[37]\d{7}$'), // Lebanon: 8 digits starting with 3,7
    'SY': RegExp(r'^9\d{8}$'), // Syria: 9 digits starting with 9
    'IQ': RegExp(r'^7[3-9]\d{8}$'), // Iraq: 10 digits starting with 73-79
    'LY': RegExp(r'^[29]\d{8}$'), // Libya: 9 digits starting with 2,9
    'TN': RegExp(r'^[2-5]\d{7}$'), // Tunisia: 8 digits starting with 2-5
    'DZ': RegExp(r'^[5-7]\d{8}$'), // Algeria: 9 digits starting with 5-7
    'MA': RegExp(r'^[6-7]\d{8}$'), // Morocco: 9 digits starting with 6,7
    'YE': RegExp(r'^7\d{8}$'), // Yemen: 9 digits starting with 7
    'PS': RegExp(r'^5[9]\d{7}$'), // Palestine: 9 digits starting with 59
  };

  @override
  void initState() {
    super.initState();
    _loadSupportPhonesOnce();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
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

  void _showCountryPicker() async {
    final result = await showModalBottomSheet<Country>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _CountryPickerModal(),
    );
    
    if (result != null) {
      setState(() {
        _selectedCountry = result;
      });
    }
  }


  Future<void> _register() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        // Validate and format phone number based on selected country
        final phoneNumber = _phoneController.text.trim();
        String digitsOnly = phoneNumber.replaceAll(RegExp(r'[^0-9]'), '');
        
        // Remove country code if present
        String countryCode = _selectedCountry.dialCode.replaceAll('+', '');
        if (digitsOnly.startsWith(countryCode)) {
          digitsOnly = digitsOnly.substring(countryCode.length);
        }
        
        // Remove leading 0 if present
        if (digitsOnly.startsWith('0')) {
          digitsOnly = digitsOnly.substring(1);
        }
        
        // Validate phone number format for selected country
        if (!_phonePatterns.containsKey(_selectedCountry.code) || 
            !_phonePatterns[_selectedCountry.code]!.hasMatch(digitsOnly)) {
          setState(() {
            _isLoading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('رقم الهاتف غير صحيح لـ ${_selectedCountry.nameAr}'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }
        
        // Format phone number with country code
        final formattedPhoneNumber = '${countryCode}$digitsOnly';

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

        // Generate OTP and send via selected method
        print('🔍 بدء عملية إنشاء الحساب...');
        print('📱 رقم الهاتف: $formattedPhoneNumber');
        print('🌍 البلد: ${_selectedCountry.nameAr}');

        String otp = SMSService.generateOTP();
        print('🔐 رمز التحقق المُنشأ: $otp');

        print('📡 إرسال رمز التحقق...');
        final result = await SMSService.sendOTP(formattedPhoneNumber, otp);
        
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
                  password: '', // Empty password since we removed password fields
                  initialOtp: otp,
                  initialOtpCreatedAt: DateTime.now(),
                  country: _selectedCountry,
                  verificationMethod: 'sms',
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

  void _showTermsAndConditions() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const TermsAndConditionsScreen(),
      ),
    );
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
      appBar: AppBar(
        title: const Text(
          'إنشاء حساب جديد',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontSize: 20,
          ),
        ),
        backgroundColor: const Color(0xFF2FBDAF),
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
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
                          'إنشاء حساب جديد',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'أدخل بياناتك لإنشاء حساب',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 32),

                        // Phone field with country code on the left
                        TextFormField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          decoration: InputDecoration(
                            labelText: 'رقم الهاتف *',
                            hintText: 'أدخل رقمك',
                            prefixIcon: Padding(
                              padding: const EdgeInsets.only(left: 16, right: 8),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.phone, color: Color(0xFF2FBDAF)),
                                  const SizedBox(width: 8),
                                  GestureDetector(
                                    onTap: () {
                                      _showCountryPicker();
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        border: Border.all(color: Colors.grey[300]!),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            _selectedCountry.dialCode,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF2FBDAF),
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          const Icon(
                                            Icons.arrow_drop_down,
                                            color: Color(0xFF2FBDAF),
                                            size: 14,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
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
                              return 'يرجى إدخال رقم الهاتف';
                            }
                            
                            String digitsOnly = value.replaceAll(RegExp(r'[^0-9]'), '');
                            String countryCode = _selectedCountry.dialCode.replaceAll('+', '');
                            
                            if (digitsOnly.startsWith(countryCode)) {
                              digitsOnly = digitsOnly.substring(countryCode.length);
                            }
                            
                            if (digitsOnly.startsWith('0')) {
                              digitsOnly = digitsOnly.substring(1);
                            }
                            
                            if (!_phonePatterns.containsKey(_selectedCountry.code) || 
                                !_phonePatterns[_selectedCountry.code]!.hasMatch(digitsOnly)) {
                              return 'رقم الهاتف غير صحيح لـ ${_selectedCountry.nameAr}';
                            }
                            
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // Name field
                        TextFormField(
                          controller: _nameController,
                          decoration: InputDecoration(
                            labelText: 'الاسم الثلاثي *',
                            hintText: 'أدخل الاسم الثلاثي',
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
                              return 'يرجى إدخال الاسم الثلاثي';
                            }
                            
                            // تقسيم الاسم إلى أجزاء
                            List<String> nameParts = value.trim().split(' ').where((part) => part.isNotEmpty).toList();
                            
                            if (nameParts.length < 3) {
                              return 'يرجى إدخال الاسم الثلاثي (3 أسماء على الأقل)';
                            }
                            
                            // التحقق من أن كل جزء يحتوي على حروف عربية أو إنجليزية
                            for (String part in nameParts) {
                              if (part.length < 2) {
                                return 'كل جزء من الاسم يجب أن يكون حرفين على الأقل';
                              }
                            }
                            
                            return null;
                          },
                        ),
                        const SizedBox(height: 20),

                        // Terms and Conditions
                        GestureDetector(
                          onTap: _showTermsAndConditions,
                          child: RichText(
                            textAlign: TextAlign.center,
                            text: TextSpan(
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.grey,
                              ),
                              children: [
                                const TextSpan(text: 'إنشاء الحساب يعني موافقتك على '),
                                TextSpan(
                                  text: 'الشروط والأحكام',
                                  style: TextStyle(
                                    color: const Color(0xFF2FBDAF),
                                    decoration: TextDecoration.underline,
                                    decorationColor: const Color(0xFF2FBDAF),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Register button
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _register,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2FBDAF),
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
                                Navigator.of(context).pushReplacement(
                                  MaterialPageRoute(
                                    builder: (context) => const LoginScreen(),
                                  ),
                                );
                              },
                              child: const Text(
                                'تسجيل الدخول',
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

class _CountryPickerModal extends StatefulWidget {
  @override
  _CountryPickerModalState createState() => _CountryPickerModalState();
}

class _CountryPickerModalState extends State<_CountryPickerModal> {
  String searchQuery = '';
  List<Country> filteredCountries = Country.countries;

  @override
  void initState() {
    super.initState();
    filteredCountries = Country.countries;
  }

  void _filterCountries(String query) {
    setState(() {
      searchQuery = query.toLowerCase();
      if (query.isEmpty) {
        filteredCountries = Country.countries;
      } else {
        filteredCountries = Country.countries.where((country) {
          return country.nameAr.toLowerCase().contains(searchQuery) ||
                 country.name.toLowerCase().contains(searchQuery) ||
                 country.dialCode.contains(query);
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Search bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              onChanged: _filterCountries,
              decoration: InputDecoration(
                hintText: 'ابحث عن بلدك أو أدخل المفتاح',
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF2FBDAF)),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Countries list
          Expanded(
            child: filteredCountries.isEmpty
                ? const Center(
                    child: Text(
                      'لا توجد نتائج',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey,
                      ),
                    ),
                  )
                : ListView.builder(
                    itemCount: filteredCountries.length,
                    itemBuilder: (context, index) {
                      final country = filteredCountries[index];
                      return ListTile(
                        leading: Text(
                          country.flag,
                          style: const TextStyle(fontSize: 24),
                        ),
                        title: Text(
                          country.nameAr,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        trailing: Text(
                          country.dialCode,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2FBDAF),
                          ),
                        ),
                        onTap: () {
                          Navigator.pop(context, country);
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class TermsAndConditionsScreen extends StatefulWidget {
  const TermsAndConditionsScreen({super.key});

  @override
  State<TermsAndConditionsScreen> createState() => _TermsAndConditionsScreenState();
}

class _TermsAndConditionsScreenState extends State<TermsAndConditionsScreen> {
  List<String> _supportPhones = [];

  @override
  void initState() {
    super.initState();
    _loadSupportPhonesOnce();
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

  void _showTechnicalSupportDialog(BuildContext context) {
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
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'الشروط والأحكام',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.white,
              fontSize: 20,
            ),
          ),
          backgroundColor: const Color(0xFF2FBDAF),
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFF2FBDAF).withOpacity(0.1),
                Colors.grey[50]!,
              ],
            ),
          ),
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Card(
                elevation: 8,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Center(
                        child: Column(
                          children: [
                            Container(
                              width: 80,
                              height: 80,
                              child: Image.asset(
                                'assets/images/logo.png',
                                fit: BoxFit.contain,
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'الشروط والأحكام',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF2FBDAF),
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'شروط وأحكام استخدام التطبيق',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Terms Content
                      _buildTermsSection(
                        '1. كيفية الاستخدام',
                        'التطبيق مخصص لحجز المواعيد الطبية والاستفادة من الخدمات الطبية. يجب استخدام التطبيق للأغراض الطبية المشروعة فقط. المستخدم مسؤول عن صحة المعلومات المقدمة في التطبيق',
                      ),
                      const SizedBox(height: 24),
                      _buildTermsSection(
                        '2. التزامات التطبيق',
                        'نلتزم بتوفير خدمات حجز المواعيد الطبية بكفاءة عالية وضمان سرية وأمان البيانات الشخصية للمستخدمين. نوفر دعم فني متواصل للمستخدمين ونقوم بتحديث التطبيق بانتظام لتحسين الخدمات. نضمن توفر الخدمات على مدار الساعة وتوفير معلومات دقيقة ومحدثة عن المراكز الطبية.',
                      ),
                      const SizedBox(height: 24),
                      _buildTermsSection(
                        '3. المساعدة والدعم',
                        'فريق الدعم الفني متاح لمساعدتك في أي وقت ويمكن التواصل معنا عبر الأرقام المرفقة في التطبيق. نلتزم بالرد على استفساراتك في أقرب وقت ممكن ونوفر دليل استخدام شامل للتطبيق. نقدم المساعدة في حل المشاكل التقنية ونستقبل اقتراحاتكم لتحسين الخدمة.',
                      ),
                      const SizedBox(height: 24),
                      _buildTermsSection(
                        '4. الخصوصية وسرية المعلومات',
                        'نحن نلتزم بحماية خصوصيتك وسرية معلوماتك الشخصية ولا نشارك معلوماتك مع أطراف ثالثة دون موافقتك. نحتفظ ببياناتك فقط للمدة اللازمة لتقديم الخدمة ونلتزم بجميع القوانين المحلية والدولية لحماية البيانات.',
                      ),
                      const SizedBox(height: 24),
                      _buildTermsSection(
                        '5. إخلاء المسؤولية',
                        'التطبيق يقدم خدمات حجز المواعيد فقط ولا نتحمل مسؤولية جودة الخدمات الطبية المقدمة. المستخدم مسؤول عن التأكد من صحة المعلومات الطبية وننصح بالاستشارة الطبية المباشرة في الحالات الطارئة.',
                      ),
                      const SizedBox(height: 32),

                      // Technical Support Footer
                      GestureDetector(
                        onTap: () => _showTechnicalSupportDialog(context),
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
    );
  }

  Widget _buildTermsSection(String title, String content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF2FBDAF),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          content,
          style: const TextStyle(
            fontSize: 15,
            color: Colors.black87,
            height: 1.6,
          ),
        ),
      ],
    );
  }
}
