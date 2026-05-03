import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:hospital_app/models/country.dart';
import 'package:hospital_app/screnns/otp_verification_screen.dart';
import 'package:hospital_app/services/sms_service.dart';
import 'package:hospital_app/services/whatsapp_service.dart';
import 'package:http/http.dart' as http;
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LabResultsScreen extends StatefulWidget {
  const LabResultsScreen({super.key});

  @override
  State<LabResultsScreen> createState() => _LabResultsScreenState();
}

class _LabResultsScreenState extends State<LabResultsScreen> {
  final TextEditingController _receiptController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final FocusNode _receiptFocusNode = FocusNode();
  bool _isLoading = false;
  bool _isSendingOtp = false;
  String? _savedPhone; // الرقم المحفوظ في SharedPreferences
  List<Map<String, dynamic>> _patients = [];
  String? _errorMessage;
  int _selectedSearchMethod = 0;
  bool _isReceiptFieldFocused = false;

  // هل الرقم المدخل حالياً هو نفس المحفوظ؟
  bool get _isPhoneKnown {
    if (_savedPhone == null || _savedPhone!.isEmpty) return false;
    final entered = _phoneController.text.trim().replaceAll(
      RegExp(r'[^\d]'),
      '',
    );
    final saved = _savedPhone!.replaceAll(RegExp(r'[^\d]'), '');
    return entered == saved ||
        _getPossiblePhoneFormats(saved).contains(entered);
  }

  @override
  void initState() {
    super.initState();
    _receiptController.addListener(_onReceiptChanged);
    _receiptFocusNode.addListener(_onReceiptFocusChanged);
    _phoneController.addListener(() => setState(() {}));
    _checkSavedPhone();
  }

  @override
  void dispose() {
    _receiptController.removeListener(_onReceiptChanged);
    _receiptFocusNode.removeListener(_onReceiptFocusChanged);
    _receiptController.dispose();
    _phoneController.dispose();
    _receiptFocusNode.dispose();
    super.dispose();
  }

  Future<void> _checkSavedPhone() async {
    final prefs = await SharedPreferences.getInstance();
    final phone =
        prefs.getString('userPhone') ??
        prefs.getString('userEmail') ??
        prefs.getString('phone');
    if (mounted) {
      setState(() {
        _savedPhone = (phone != null && phone.isNotEmpty) ? phone : null;
        if (_savedPhone != null) {
          _phoneController.text = _savedPhone!;
        }
      });
    }
  }

  void _onReceiptFocusChanged() {
    setState(() {
      _isReceiptFieldFocused = _receiptFocusNode.hasFocus;
    });
  }

  void _onReceiptChanged() {
    setState(() {
      _patients = [];
      _errorMessage = null;
    });
  }

  List<String> _getPossiblePhoneFormats(String phone) {
    final clean = phone.replaceAll(RegExp(r'[^\d]'), '');
    final Set<String> formats = {clean};
    if (clean.startsWith('249') && clean.length == 12) {
      formats.add('0${clean.substring(3)}');
    } else if (clean.startsWith('0') && clean.length == 10) {
      formats.add('249${clean.substring(1)}');
    } else if (clean.length == 9) {
      formats.add('0$clean');
      formats.add('249$clean');
    }
    return formats.toList();
  }

  Future<void> _searchByPhone() async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) {
      setState(() => _errorMessage = 'يرجى إدخال رقم الهاتف');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _patients = [];
    });

    try {
      final phoneFormats = _getPossiblePhoneFormats(phone);

      final snapshot =
          await FirebaseFirestore.instance
              .collection('alroomy_results')
              .where('patient_phone', whereIn: phoneFormats)
              .orderBy('created_at', descending: true)
              .get();

      if (snapshot.docs.isEmpty) {
        setState(() {
          _errorMessage = 'لم يتم العثور على نتائج مختبر بهذا الرقم';
          _isLoading = false;
        });
        return;
      }

      setState(() {
        _patients = snapshot.docs.map((doc) => _docToPatient(doc)).toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'خطأ في الاتصال: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _searchByReceipt() async {
    final receipt = _receiptController.text.trim();
    if (receipt.isEmpty) {
      setState(() {
        _errorMessage = 'يرجى إدخال رقم الإيصال';
        _patients = [];
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _patients = [];
    });

    try {
      final doc =
          await FirebaseFirestore.instance
              .collection('alroomy_results')
              .doc(receipt)
              .get();

      if (!doc.exists) {
        setState(() {
          _errorMessage = 'لم يتم العثور على نتائج بهذا الرقم';
          _isLoading = false;
        });
        return;
      }

      setState(() {
        _patients = [_docToPatient(doc)];
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'خطأ في الاتصال: $e';
        _isLoading = false;
      });
    }
  }

  // إرسال OTP للتحقق من رقم الهاتف
  Future<void> _sendOtpForLab() async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) {
      setState(() => _errorMessage = 'يرجى إدخال رقم الهاتف');
      return;
    }

    // تنسيق الرقم
    final clean = phone.replaceAll(RegExp(r'[^\d]'), '');
    if (clean.length < 9) {
      setState(() => _errorMessage = 'رقم الهاتف غير صحيح');
      return;
    }

    setState(() {
      _isSendingOtp = true;
      _errorMessage = null;
    });

    try {
      final otp = SMSService.generateOTP();
      final otpCreatedAt = DateTime.now();

      // إرسال عبر واتساب مع فولباك على SMS
      Map<String, dynamic> result = await WhatsAppService.sendOTP(phone, otp);

      if (!result['success']) {
        result = await SMSService.sendOTP(phone, otp);
      }

      setState(() => _isSendingOtp = false);

      if (!mounted) return;

      if (result['success'] == true) {
        final verificationMethod =
            result['method'] == 'sms' ? 'sms' : 'whatsapp';

        Navigator.push(
          context,
          MaterialPageRoute(
            builder:
                (context) => OTPVerificationScreen(
                  phoneNumber: phone,
                  name: '',
                  password: '',
                  initialOtp: otp,
                  initialOtpCreatedAt: otpCreatedAt,
                  country: Country.countries.first, // السودان
                  verificationMethod: verificationMethod,
                  isLoginFlow: false,
                  onVerified: () async {
                    // حفظ الرقم في SharedPreferences ثم البحث
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setString('userPhone', phone);
                    if (mounted) {
                      setState(() => _savedPhone = phone);
                      _searchByPhone();
                    }
                  },
                ),
          ),
        );
      } else {
        setState(() => _errorMessage = 'فشل إرسال رمز التحقق، حاول مرة أخرى');
      }
    } catch (e) {
      setState(() {
        _isSendingOtp = false;
        _errorMessage = 'خطأ في إرسال رمز التحقق: $e';
      });
    }
  }

  Map<String, dynamic> _docToPatient(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final createdAt = data['created_at'];
    String displayDate = 'غير محدد';
    if (createdAt is Timestamp) {
      final dt = createdAt.toDate();
      displayDate =
          '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
    }
    return {
      'patient_id': doc.id,
      'patient_name': data['patient_name'] ?? 'المريض',
      'patient_date': displayDate,
      'result_url': data['result_url'] ?? '',
    };
  }

  void _viewResults(Map<String, dynamic> patient) {
    final resultUrl = patient['result_url'] as String? ?? '';
    final patientName = patient['patient_name'] ?? 'المريض';
    final patientId = patient['patient_id'] ?? '';

    if (resultUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('رابط النتيجة غير متوفر'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    _showResultsReadyDialog(patientId, patientName, resultUrl);
  }

  Future<void> _downloadAndOpenPDF(String resultUrl, String patientName) async {
    try {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 12),
                Text('جاري تحميل النتيجة...'),
              ],
            ),
            duration: Duration(seconds: 15),
          ),
        );
      }

      final response = await http
          .get(Uri.parse(resultUrl))
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () => throw Exception('انتهت مهلة الاتصال'),
          );

      if (response.statusCode != 200) {
        throw Exception('فشل تحميل الملف: ${response.statusCode}');
      }

      final directory = await getApplicationDocumentsDirectory();
      final cleanName = patientName
          .replaceAll(RegExp(r'[^\w؀-ۿ\s]'), '')
          .replaceAll(' ', '_');
      final filePath = '${directory.path}/نتائج_$cleanName.pdf';
      await File(filePath).writeAsBytes(response.bodyBytes);

      if (mounted) ScaffoldMessenger.of(context).hideCurrentSnackBar();
      await OpenFile.open(filePath);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في فتح الملف: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _shareResult(
    String resultUrl,
    String patientName,
    String patientId,
  ) async {
    try {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 12),
                Text('جاري تحضير الملف للمشاركة...'),
              ],
            ),
            duration: Duration(seconds: 15),
          ),
        );
      }

      final response = await http
          .get(Uri.parse(resultUrl))
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () => throw Exception('انتهت مهلة الاتصال'),
          );

      if (response.statusCode != 200) {
        throw Exception('فشل تحميل الملف: ${response.statusCode}');
      }

      final directory = await getApplicationDocumentsDirectory();
      final cleanName = patientName
          .replaceAll(RegExp(r'[^\w؀-ۿ\s]'), '')
          .replaceAll(' ', '_');
      final fileName = 'نتائج_$cleanName.pdf';
      final filePath = '${directory.path}/$fileName';
      await File(filePath).writeAsBytes(response.bodyBytes);

      if (mounted) ScaffoldMessenger.of(context).hideCurrentSnackBar();

      await Share.shareXFiles(
        [XFile(filePath, name: fileName)],
        text: 'نتائج المختبر - $patientName',
        subject: 'نتائج المختبر - $patientName',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في مشاركة الملف: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showResultsReadyDialog(
    String patientId,
    String patientName,
    String resultUrl,
  ) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            elevation: 8,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration: const BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      const Text(
                        'النتيجة جاهزة',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      'مرحباً $patientName،',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      'نتائج المختبر الخاصة بك جاهزة. اختر ما تريد فعله:',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.black87,
                        height: 1.3,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 45,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.of(context).pop();
                              _shareResult(resultUrl, patientName, patientId);
                            },
                            icon: const Icon(
                              Icons.share,
                              size: 18,
                              color: Colors.green,
                            ),
                            label: const Text(
                              'مشاركة واتساب',
                              style: TextStyle(
                                color: Colors.green,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                                side: const BorderSide(
                                  color: Colors.green,
                                  width: 1,
                                ),
                              ),
                              elevation: 1,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: SizedBox(
                          height: 45,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.of(context).pop();
                              _downloadAndOpenPDF(resultUrl, patientName);
                            },
                            icon: const Icon(
                              Icons.visibility,
                              size: 18,
                              color: Colors.blue,
                            ),
                            label: const Text(
                              'عرض النتيجة',
                              style: TextStyle(
                                color: Colors.blue,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                                side: const BorderSide(
                                  color: Colors.blue,
                                  width: 1,
                                ),
                              ),
                              elevation: 1,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                    child: const Text(
                      'إلغاء',
                      style: TextStyle(
                        color: Colors.black54,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
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
          title: const Text(
            'نتائج المختبر',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFF2FBDAF),
              fontSize: 24,
            ),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Color(0xFF2FBDAF)),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: SafeArea(
          child: Container(
            color: Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  // Search Method Selection
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withValues(alpha: 0.1),
                          spreadRadius: 2,
                          blurRadius: 15,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Text(
                          'اختر طريقة البحث:',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey[700],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            _buildMethodTab(
                              label: 'رقم الإيصال',
                              icon: Icons.receipt,
                              selected: _selectedSearchMethod == 1,
                              onTap:
                                  () =>
                                      setState(() => _selectedSearchMethod = 1),
                            ),
                            const SizedBox(width: 12),
                            _buildMethodTab(
                              label: 'رقم الهاتف',
                              icon: Icons.phone,
                              selected: _selectedSearchMethod == 0,
                              onTap:
                                  () =>
                                      setState(() => _selectedSearchMethod = 0),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Search Input Section
                  if (_selectedSearchMethod == 1)
                    _buildReceiptSection()
                  else
                    _buildPhoneSection(),

                  const SizedBox(height: 20),

                  // Error Message
                  if (_errorMessage != null)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.red[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.red[200]!),
                      ),
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(color: Colors.red[700], fontSize: 14),
                        textAlign: TextAlign.center,
                      ),
                    ),

                  // Results Section
                  Expanded(
                    child:
                        _patients.isEmpty &&
                                !_isLoading &&
                                _errorMessage == null
                            ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    _selectedSearchMethod == 0
                                        ? Icons.phone
                                        : Icons.receipt,
                                    size: 64,
                                    color: Colors.grey[400],
                                  ),
                                  const SizedBox(height: 16),
                                  if (!_isReceiptFieldFocused ||
                                      _selectedSearchMethod == 0)
                                    Text(
                                      _selectedSearchMethod == 0
                                          ? 'أدخل رقم هاتفك ثم اضغط للاستعلام أو إرسال رمز التحقق'
                                          : 'أدخل رقم الإيصال واضغط على "البحث" للعثور على نتائج المختبر',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        color: Color.fromARGB(255, 250, 152, 5),
                                        height: 1.5,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                ],
                              ),
                            )
                            : ListView.builder(
                              itemCount: _patients.length,
                              itemBuilder:
                                  (context, index) =>
                                      _buildPatientCard(_patients[index]),
                            ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMethodTab({
    required String label,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF2FBDAF) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? const Color(0xFF2FBDAF) : Colors.grey[300]!,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: selected ? Colors.white : Colors.grey[600],
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: selected ? Colors.white : Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReceiptSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.receipt, color: Colors.grey[600], size: 20),
              const SizedBox(width: 8),
              Text(
                'أدخل رقم الإيصال:',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[700],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
            ),
            child: TextField(
              controller: _receiptController,
              focusNode: _receiptFocusNode,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.right,
              textDirection: TextDirection.rtl,
              decoration: const InputDecoration(
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _searchByReceipt,
              style: _primaryButtonStyle(),
              child:
                  _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                        'البحث برقم الإيصال',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhoneSection() {
    final isKnown = _isPhoneKnown;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.phone, color: Colors.grey[600], size: 20),
              const SizedBox(width: 8),
              Text(
                'رقم الهاتف:',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[700],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
            ),
            child: TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              textAlign: TextAlign.right,
              textDirection: TextDirection.ltr,
              decoration: InputDecoration(
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                hintText: '09XXXXXXXX',
                hintStyle: TextStyle(color: Colors.grey[400]),
                prefixIcon: Icon(
                  Icons.phone,
                  color: Colors.grey[500],
                  size: 20,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),

          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child:
                isKnown
                    // رقم محفوظ → بحث مباشر
                    ? ElevatedButton(
                      onPressed: _isLoading ? null : _searchByPhone,
                      style: _primaryButtonStyle(),
                      child:
                          _isLoading
                              ? const CircularProgressIndicator(
                                color: Colors.white,
                              )
                              : const Text(
                                'الاستعلام عن النتيجة',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                    )
                    // رقم جديد → إرسال OTP
                    : ElevatedButton.icon(
                      onPressed: _isSendingOtp ? null : _sendOtpForLab,
                      style: _primaryButtonStyle(),
                      icon:
                          _isSendingOtp
                              ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                              : const Icon(
                                Icons.send,
                                color: Colors.white,
                                size: 20,
                              ),
                      label: Text(
                        _isSendingOtp ? 'جاري الإرسال...' : 'إرسال رمز التحقق',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
          ),
        ],
      ),
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      boxShadow: [
        BoxShadow(
          color: Colors.grey.withValues(alpha: 0.1),
          spreadRadius: 2,
          blurRadius: 15,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

  ButtonStyle _primaryButtonStyle() {
    return ElevatedButton.styleFrom(
      backgroundColor: const Color(0xFF2FBDAF),
      padding: const EdgeInsets.symmetric(vertical: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  Widget _buildPatientCard(Map<String, dynamic> patient) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    patient['patient_name'] ?? 'غير محدد',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    patient['patient_date'] ?? 'غير محدد',
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
            ElevatedButton(
              onPressed: () => _viewResults(patient),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2FBDAF),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'عرض النتيجة',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
