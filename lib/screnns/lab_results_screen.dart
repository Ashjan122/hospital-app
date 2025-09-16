import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'dart:typed_data';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:open_file/open_file.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cross_file/cross_file.dart';

class LabResultsScreen extends StatefulWidget {
  const LabResultsScreen({super.key});

  @override
  State<LabResultsScreen> createState() => _LabResultsScreenState();
}

class _LabResultsScreenState extends State<LabResultsScreen> {
  final TextEditingController _receiptController = TextEditingController();
  final FocusNode _receiptFocusNode = FocusNode();
  bool _isLoading = false;
  String? _currentLoadingPatientId; // لتتبع المريض الذي يتم تحميله حالياً
  List<Map<String, dynamic>> _patients = [];
  String? _errorMessage;
  Timer? _searchDebounce;
  int _selectedSearchMethod = 0; // 0: رقم الهاتف, 1: رقم الإيصال
  bool _isReceiptFieldFocused = false; // لتتبع حالة التركيز على حقل البحث

  @override
  void initState() {
    super.initState();
    _receiptController.addListener(_onReceiptChanged);
    _receiptFocusNode.addListener(_onReceiptFocusChanged);
  }

  @override
  void dispose() {
    _receiptController.removeListener(_onReceiptChanged);
    _receiptFocusNode.removeListener(_onReceiptFocusChanged);
    _receiptController.dispose();
    _receiptFocusNode.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  void _onReceiptFocusChanged() {
    setState(() {
      _isReceiptFieldFocused = _receiptFocusNode.hasFocus;
    });
  }

  void _onReceiptChanged() {
    // إلغاء البحث السابق
    _searchDebounce?.cancel();
    
    // مسح النتائج عند تغيير النص
    setState(() {
      _patients = [];
      _errorMessage = null;
    });
  }

  Future<void> _searchByPhone() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _patients = [];
    });

    try {
      // جلب رقم الهاتف من SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      
      // للتشخيص - عرض جميع المفاتيح المحفوظة
      final keys = prefs.getKeys();
      print('جميع المفاتيح المحفوظة: $keys');
      for (String key in keys) {
        print('$key: ${prefs.get(key)}');
      }
      
      // البحث عن رقم الهاتف في المفاتيح المختلفة
      String? phone = prefs.getString('userPhone') ?? 
                     prefs.getString('userEmail') ?? 
                     prefs.getString('phone');
      
      print('رقم الهاتف المستخدم للبحث: $phone');
      
      if (phone == null || phone.isEmpty) {
        setState(() {
          _errorMessage = 'لم يتم العثور على رقم الهاتف المسجل';
          _isLoading = false;
        });
        return;
      }

      // تنظيف وتنسيق رقم الهاتف
      String formattedPhone = _formatPhoneNumber(phone);
      print('رقم الهاتف الأصلي: $phone');
      print('رقم الهاتف المنسق: $formattedPhone');

      final url = 'https://alroomy.a.pinggy.link/projects/bootstraped/new/patients_api.php?phone=$formattedPhone';
      print('URL: $url');
      
      final response = await http.get(Uri.parse(url)).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('انتهت مهلة الاتصال');
        },
      );

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['success'] == true) {
          setState(() {
            _patients = List<Map<String, dynamic>>.from(data['data']);
            _isLoading = false;
          });
          
          // للتشخيص - عرض بيانات المرضى
          print('Found ${_patients.length} patients');
          for (int i = 0; i < _patients.length; i++) {
            print('Patient $i: ${_patients[i]}');
          }
        } else {
          setState(() {
            _errorMessage = 'لم يتم العثور على مرضى بهذا الرقم';
            _patients = [];
            _isLoading = false;
          });
        }
      } else {
        setState(() {
          _errorMessage = 'خطأ في الاتصال بالخادم';
          _patients = [];
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'خطأ في الاتصال: $e';
        _patients = [];
        _isLoading = false;
      });
    }
  }

  String _formatPhoneNumber(String phone) {
    // إزالة جميع المسافات والرموز
    String cleanPhone = phone.replaceAll(RegExp(r'[^\d]'), '');
    
    // إذا كان الرقم يبدأ بـ 249 (مفتاح السودان)
    if (cleanPhone.startsWith('249')) {
      // إزالة 249 وإضافة 0
      cleanPhone = '0${cleanPhone.substring(3)}';
    }
    // إذا كان الرقم يبدأ بـ 9 (بدون مفتاح)
    else if (cleanPhone.startsWith('9') && cleanPhone.length == 9) {
      // إضافة 0 في البداية
      cleanPhone = '0$cleanPhone';
    }
    // إذا كان الرقم يبدأ بـ 0
    else if (cleanPhone.startsWith('0')) {
      // الرقم صحيح بالفعل
      cleanPhone = cleanPhone;
    }
    // إذا كان الرقم يبدأ بـ 1 أو 2 أو 3 أو 4 أو 5 أو 6 أو 7 أو 8
    else if (cleanPhone.length == 9) {
      // إضافة 0 في البداية
      cleanPhone = '0$cleanPhone';
    }
    
    return cleanPhone;
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
      final url = 'https://alroomy.a.pinggy.link/projects/bootstraped/new/lab_results_api.php?patient_id=$receipt';
      final response = await http.get(Uri.parse(url)).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('انتهت مهلة الاتصال');
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['success'] == true) {
          // تحويل البيانات إلى تنسيق متوافق مع العرض
          final patientData = data['data'];
          final patientId = patientData['patient_id']?.toString();
          final patientName = patientData['patient_name'] ?? 'المريض';
          
          // استخراج التاريخ فقط من generated_at
          String displayDate = 'غير محدد';
          if (patientData['generated_at'] != null) {
            try {
              final dateTime = DateTime.parse(patientData['generated_at']);
              displayDate = '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')}';
            } catch (e) {
              displayDate = patientData['generated_at'].toString();
            }
          }
          
          setState(() {
            _patients = [{
              'patient_id': patientId,
              'patient_name': patientName,
              'patient_date': displayDate,
              'pdf_data': patientData,
            }];
            _isLoading = false;
          });
          
          print('Found patient by receipt: $patientName (ID: $patientId)');
        } else {
          setState(() {
            _errorMessage = 'لم يتم العثور على نتائج بهذا الرقم';
            _patients = [];
            _isLoading = false;
          });
        }
      } else {
        setState(() {
          _errorMessage = 'خطأ في الاتصال بالخادم';
          _patients = [];
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'خطأ في الاتصال: $e';
        _patients = [];
        _isLoading = false;
      });
    }
  }

  Future<void> _viewResults(Map<String, dynamic> patient) async {
    final patientId = patient['patient_id']?.toString();
    final patientName = patient['patient_name'] ?? 'المريض';
    
    if (patientId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('خطأ: معرف المريض غير متوفر'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    // للتشخيص - عرض معرف المريض
    print('Patient ID: $patientId');
    print('Patient Name: $patientName');
    
    // التحقق من حالة النتيجة عند الضغط على عرض النتيجة
    _checkResultsStatus(patientId, patientName);
  }

  Future<void> _downloadAndOpenPDF(String patientName, Map<String, dynamic> apiData, [String? patientId]) async {
    try {
      // للتشخيص - عرض بيانات API
      print('API Data: $apiData');
      
      // إنشاء اسم الملف باسم المريض (بدون أرقام)
      final String cleanName = patientName.replaceAll(RegExp(r'[0-9]'), '').replaceAll(' ', '_').replaceAll(RegExp(r'_+'), '_');
      final String fileName = 'نتائج_$cleanName.pdf';
      
      // الحصول على مجلد التطبيق
      final directory = await getApplicationDocumentsDirectory();
      final filePath = '${directory.path}/$fileName';
      
      // التحقق من وجود بيانات PDF في الاستجابة
      final pdfData = apiData['data'];
      PdfDocument document;
      
      if (pdfData != null && pdfData['pdf_base64'] != null) {
        // إذا كان هناك PDF base64، استخدمه
        try {
          final Uint8List pdfBytes = base64Decode(pdfData['pdf_base64']);
          document = PdfDocument(inputBytes: pdfBytes);
        } catch (e) {
          // في حالة فشل فك الترميز، أنشئ PDF جديد
          document = PdfDocument();
          final PdfPage page = document.pages.add();
          final PdfGraphics graphics = page.graphics;
          
          final PdfFont titleFont = PdfStandardFont(PdfFontFamily.helvetica, 20, style: PdfFontStyle.bold);
          final PdfFont normalFont = PdfStandardFont(PdfFontFamily.helvetica, 14);
          final PdfFont smallFont = PdfStandardFont(PdfFontFamily.helvetica, 12);
          final PdfBrush brush = PdfSolidBrush(PdfColor(0, 0, 0));
          
          graphics.drawString(
            'نتائج المختبر',
            titleFont,
            brush: brush,
            bounds: Rect.fromLTWH(50, 50, 500, 30),
          );
          
          graphics.drawString(
            'اسم المريض: $patientName',
            normalFont,
            brush: brush,
            bounds: Rect.fromLTWH(50, 100, 500, 25),
          );
          
          graphics.drawString(
            'تاريخ الطباعة: ${DateTime.now().toString().split('.')[0]}',
            smallFont,
            brush: brush,
            bounds: Rect.fromLTWH(50, 130, 500, 20),
          );
          
          graphics.drawLine(
            PdfPen(PdfColor(0, 0, 0), width: 1),
            Offset(50, 170),
            Offset(550, 170),
          );
          
          graphics.drawString(
            'تم إنشاء هذا التقرير بناءً على طلب عرض نتائج المختبر',
            smallFont,
            brush: brush,
            bounds: Rect.fromLTWH(50, 200, 500, 20),
          );
        }
      } else {
        // إنشاء ملف PDF بسيط مع معلومات المريض
        document = PdfDocument();
        final PdfPage page = document.pages.add();
        final PdfGraphics graphics = page.graphics;
        
        final PdfFont titleFont = PdfStandardFont(PdfFontFamily.helvetica, 20, style: PdfFontStyle.bold);
        final PdfFont normalFont = PdfStandardFont(PdfFontFamily.helvetica, 14);
        final PdfFont smallFont = PdfStandardFont(PdfFontFamily.helvetica, 12);
        final PdfBrush brush = PdfSolidBrush(PdfColor(0, 0, 0));
        
        graphics.drawString(
          'نتائج المختبر',
          titleFont,
          brush: brush,
          bounds: Rect.fromLTWH(50, 50, 500, 30),
        );
        
        graphics.drawString(
          'اسم المريض: $patientName',
          normalFont,
          brush: brush,
          bounds: Rect.fromLTWH(50, 100, 500, 25),
        );
        
        graphics.drawString(
          'تاريخ الطباعة: ${DateTime.now().toString().split('.')[0]}',
          smallFont,
          brush: brush,
          bounds: Rect.fromLTWH(50, 130, 500, 20),
        );
        
        graphics.drawLine(
          PdfPen(PdfColor(0, 0, 0), width: 1),
          Offset(50, 170),
          Offset(550, 170),
        );
        
        graphics.drawString(
          'تم إنشاء هذا التقرير بناءً على طلب عرض نتائج المختبر',
          smallFont,
          brush: brush,
          bounds: Rect.fromLTWH(50, 200, 500, 20),
        );
      }
      
      // حفظ الملف
      final File file = File(filePath);
      
      // حذف الملف القديم إذا كان موجوداً
      if (await file.exists()) {
        await file.delete();
        print('🗑️ تم حذف الملف القديم من _downloadAndOpenPDF');
      }
      
      final List<int> pdfBytes = await document.save();
      await file.writeAsBytes(pdfBytes);
      document.dispose();
      
      // التحقق من أن الملف تم حفظه بشكل صحيح
      if (await file.exists() && file.lengthSync() > 0) {
        print('💾 تم حفظ الملف بنجاح في: ${file.path}');
        print('📏 حجم الملف: ${file.lengthSync()} bytes');
      } else {
        print('❌ فشل في حفظ الملف أو الملف فارغ');
        throw Exception('فشل في حفظ الملف');
      }
      
      // التحقق من وجود الملف
      if (await file.exists()) {
        // محاولة فتح الملف
        try {
          await OpenFile.open(filePath);
        } catch (e) {
          // في حالة فشل فتح الملف
          print('فشل في فتح الملف: $e');
        }
      } else {
        throw Exception('فشل في حفظ الملف');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطأ في فتح الملف: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _checkResultsStatus(String patientId, String patientName) async {
    try {
      setState(() {
        _isLoading = true;
        _currentLoadingPatientId = patientId;
      });

      // جرب endpoint مختلف بناءً على الوثائق - endpoint للتحقق من الحالة
      final url = 'https://alroomy.a.pinggy.link/projects/bootstraped/new/lab_results_api.php?check_status=$patientId';
      print('Checking results status URL: $url');
      
      final response = await http.get(Uri.parse(url)).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('انتهت مهلة الاتصال');
        },
      );

      print('Results status response: ${response.statusCode}');
      print('Results status body: ${response.body}');

      setState(() {
        _isLoading = false;
        _currentLoadingPatientId = null;
      });

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('Parsed data: $data');
        
        // التحقق من بنية البيانات الصحيحة بناءً على API Documentation
        bool isReady = false;
        
        if (data['success'] == true && data['data'] != null) {
          // بناءً على الوثائق: data.is_ready
          if (data['data']['is_ready'] != null) {
            isReady = data['data']['is_ready'] == true;
            print('Found is_ready in data.data: ${data['data']['is_ready']}');
          }
          // إذا كان هناك بيانات PDF، فهذا يعني أن النتيجة جاهزة
          else if (data['data'] is String && (data['data'] as String).isNotEmpty) {
            isReady = true;
            print('Found PDF data, marking as ready');
          }
        }
        
        print('Is ready: $isReady');
        
        if (isReady) {
          // Results are ready - show dialog with options
          _showResultsReadyDialog(patientId, patientName, data['data']);
        } else {
          // Results are not ready - show dialog with progress info
          _showResultsNotReadyDialog(patientName, data['data']);
        }
      } else {
        // إذا فشل التحقق من الحالة، جرب الحصول على النتيجة مباشرة
        print('Status check failed, trying direct result fetch...');
        _tryDirectResultFetch(patientId, patientName);
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _currentLoadingPatientId = null;
      });
      print('Error in status check: $e');
      // إذا فشل التحقق من الحالة، جرب الحصول على النتيجة مباشرة
      _tryDirectResultFetch(patientId, patientName);
    }
  }

  Future<void> _tryDirectResultFetch(String patientId, String patientName) async {
    try {
      setState(() {
        _isLoading = true;
        _currentLoadingPatientId = patientId;
      });

      final url = 'https://alroomy.a.pinggy.link/projects/bootstraped/new/lab_results_api.php?patient_id=$patientId';
      print('Trying direct result fetch URL: $url');
      
      final response = await http.get(Uri.parse(url)).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('انتهت مهلة الاتصال');
        },
      );

      print('Direct fetch response: ${response.statusCode}');
      print('Direct fetch body: ${response.body}');

      setState(() {
        _isLoading = false;
        _currentLoadingPatientId = null;
      });

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['success'] == true && data['data'] != null && (data['data'] as String).isNotEmpty) {
          // النتيجة جاهزة
          _showResultsReadyDialog(patientId, patientName);
        } else {
          // النتيجة غير جاهزة
          _showResultsNotReadyDialog(patientName);
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('خطأ في الاتصال بالخادم'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _currentLoadingPatientId = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطأ في التحقق من حالة النتائج: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showResultsReadyDialog(String patientId, String patientName, [Map<String, dynamic>? statusData]) {
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
                  // Header with success icon
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
                  
                  // Greeting message
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
                  Align(
                    alignment: Alignment.centerRight,
                    child: const Text(
                      'نتائج المختبر الخاصة بك جاهزة. اختر ما تريد فعله:',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.black87,
                        height: 1.3,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Action buttons
                  Row(
                    children: [
                      // Share on WhatsApp button
                      Expanded(
                        child: Container(
                          height: 45,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.of(context).pop();
                              _shareOnWhatsApp(patientId, patientName);
                            },
                            icon: const Icon(Icons.share, size: 18, color: Colors.green),
                            label: const Text(
                              'مشاركة في واتساب',
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
                                side: const BorderSide(color: Colors.green, width: 1),
                              ),
                              elevation: 1,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      // View Result button
                      Expanded(
                        child: Container(
                          height: 45,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.of(context).pop();
                              _navigateToResultsView(patientId, patientName);
                            },
                            icon: const Icon(Icons.visibility, size: 18, color: Colors.blue),
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
                                side: const BorderSide(color: Colors.blue, width: 1),
                              ),
                              elevation: 1,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  
                  // Cancel button
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
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

  void _showResultsNotReadyDialog(String patientName, [Map<String, dynamic>? statusData]) {
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
                  // Header with clock icon
                  Row(
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration: const BoxDecoration(
                          color: Colors.orange,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.access_time,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      const Text(
                        'النتيجة غير جاهزة',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  
                  // Message
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
                  Align(
                    alignment: Alignment.centerRight,
                    child: const Text(
                      'نتائج المختبر الخاصة بك لم تكتمل بعد.',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.black87,
                        height: 1.3,
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  
                  // Okay button
                  SizedBox(
                    width: double.infinity,
                    height: 45,
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.blue,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: const BorderSide(color: Colors.blue, width: 1),
                        ),
                        elevation: 1,
                      ),
                      child: const Text(
                        'حسناً',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
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

  void _navigateToResultsView(String patientId, String patientName) async {
    try {
      print('🚀 بدء تحميل وعرض النتيجة للمريض: $patientName (ID: $patientId)');
      
      // إظهار مؤشر التحميل
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
            duration: Duration(seconds: 3),
          ),
        );
      }
      
      final url = 'https://alroomy.a.pinggy.link/projects/bootstraped/new/lab_results_api.php?patient_id=$patientId';
      final response = await http.get(Uri.parse(url)).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('انتهت مهلة الاتصال');
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['success'] == true) {
          // تحميل وعرض PDF مع حفظ للمشاركة
          await _downloadAndOpenPDF(patientName, data, patientId);
          
          // إظهار رسالة نجاح
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(data['message'] ?? 'خطأ في تحميل النتائج'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('خطأ في الاتصال بالخادم'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print('❌ خطأ في تحميل النتيجة: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطأ في تحميل النتائج: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // دالة مشاركة ملف النتيجة - محسنة مع معالجة أفضل للأخطاء
  void _shareOnWhatsApp(String patientId, String patientName) async {
    try {
      print('🚀 بدء مشاركة ملف النتيجة للمريض: $patientName (ID: $patientId)');
      
      // إظهار مؤشر التحميل
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
            duration: Duration(seconds: 3),
          ),
        );
      }
      
      // التحقق من وجود ملف محفوظ مسبقاً
      final Directory appDocDir = await getApplicationDocumentsDirectory();
      final String savedFilePath = '${appDocDir.path}/lab_result_$patientId.pdf';
      final File savedFile = File(savedFilePath);
      
      print('🔍 البحث عن ملف محفوظ في: $savedFilePath');
      print('📁 مجلد التطبيق: ${appDocDir.path}');
      
      // قائمة بجميع الملفات في المجلد للتشخيص
      try {
        final List<FileSystemEntity> files = appDocDir.listSync();
        print('📋 الملفات الموجودة في المجلد:');
        for (final file in files) {
          if (file is File && file.path.contains('lab_result')) {
            print('  - ${file.path} (${file.lengthSync()} bytes)');
          }
        }
      } catch (e) {
        print('❌ خطأ في قراءة مجلد التطبيق: $e');
      }
      
      if (await savedFile.exists()) {
        print('✅ تم العثور على ملف محفوظ مسبقاً: ${savedFile.path}');
        print('📏 حجم الملف: ${savedFile.lengthSync()} bytes');
        
        // التحقق من أن الملف ليس فارغاً
        if (savedFile.lengthSync() > 0) {
          // مشاركة الملف المحفوظ
          final String cleanName = patientName.replaceAll(RegExp(r'[0-9]'), '').replaceAll(' ', '_').replaceAll(RegExp(r'_+'), '_');
          final String fileName = 'نتائج_$cleanName.pdf';
          await Share.shareXFiles(
            [XFile(savedFile.path, name: fileName)],
            text: 'نتائج المختبر - $patientName\nرقم المريض: $patientId',
            subject: 'نتائج المختبر - $patientName',
          );
          
          print('✅ تم مشاركة الملف المحفوظ بنجاح');
          
          return;
        } else {
          print('⚠️ الملف المحفوظ فارغ، سيتم حذفه وتحميل ملف جديد...');
          await savedFile.delete();
        }
      }
      
      print('⚠️ لم يتم العثور على ملف محفوظ صالح، سيتم تحميل ملف جديد...');

      // محاولة أولى - استخدام API endpoint المباشر
      print('📡 محاولة تحميل البيانات من API...');
      final response = await http.get(
        Uri.parse('https://api.romy-medical.com/api/lab-results/$patientId'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json, application/pdf',
          'User-Agent': 'HospitalApp/1.0',
        },
      ).timeout(const Duration(seconds: 30));

      print('📊 حالة الاستجابة: ${response.statusCode}');
      print('📋 نوع المحتوى: ${response.headers['content-type']}');
      print('📏 حجم الاستجابة: ${response.bodyBytes.length} bytes');

      if (response.statusCode == 200) {
        // فحص نوع المحتوى
        final contentType = response.headers['content-type'] ?? '';
        
        if (contentType.contains('application/pdf')) {
          // الاستجابة هي ملف PDF مباشر
          print('✅ تم استلام ملف PDF مباشر');
          await _saveAndSharePdf(response.bodyBytes, patientId, patientName);
        } else if (contentType.contains('application/json')) {
          // الاستجابة هي JSON
          print('📄 تم استلام استجابة JSON');
          final jsonData = json.decode(response.body);
          print('🔍 محتوى JSON: ${jsonData.toString().substring(0, 200)}...');
          
          // البحث عن رابط PDF
          String? pdfUrl;
          if (jsonData['data'] != null && jsonData['data']['pdf_url'] != null) {
            pdfUrl = jsonData['data']['pdf_url'];
          } else if (jsonData['pdf_url'] != null) {
            pdfUrl = jsonData['pdf_url'];
          } else if (jsonData['result'] != null && jsonData['result']['pdf_url'] != null) {
            pdfUrl = jsonData['result']['pdf_url'];
          }
          
          if (pdfUrl != null && pdfUrl.isNotEmpty) {
            print('🔗 تم العثور على رابط PDF: $pdfUrl');
            await _downloadAndSharePdf(pdfUrl, patientId, patientName);
          } else {
            throw Exception('لم يتم العثور على رابط ملف PDF في الاستجابة');
          }
        } else {
          throw Exception('نوع محتوى غير متوقع: $contentType');
        }
      } else {
        throw Exception('فشل في تحميل البيانات: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('❌ خطأ في مشاركة الملف: $e');
      
      // محاولة بديلة - إنشاء ملف PDF بسيط
      print('🔄 محاولة إنشاء ملف PDF بديل...');
      try {
        await _createAndShareSimplePdf(patientId, patientName);
      } catch (fallbackError) {
        print('❌ فشل في إنشاء ملف PDF بديل: $fallbackError');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('حدث خطأ في مشاركة الملف: ${e.toString()}'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
            ),
          );
        }
      }
    }
  }

  // دالة مساعدة لحفظ ومشاركة ملف PDF
  Future<void> _saveAndSharePdf(Uint8List pdfBytes, String patientId, String patientName) async {
    try {
      final Directory appDocDir = await getApplicationDocumentsDirectory();
      final String cleanName = patientName.replaceAll(RegExp(r'[0-9]'), '').replaceAll(' ', '_').replaceAll(RegExp(r'_+'), '_');
      final String fileName = 'نتائج_$cleanName.pdf';
      final String filePath = '${appDocDir.path}/$fileName';
      final File file = File(filePath);
      
      // حذف الملف القديم إذا كان موجوداً
      if (await file.exists()) {
        await file.delete();
        print('🗑️ تم حذف الملف القديم');
      }
      
      // حفظ الملف الجديد
      await file.writeAsBytes(pdfBytes);
      
      // التحقق من أن الملف تم حفظه بشكل صحيح
      if (await file.exists() && file.lengthSync() > 0) {
        print('💾 تم حفظ الملف بنجاح في: ${file.path}');
        print('📏 حجم الملف: ${file.lengthSync()} bytes');
        
        // مشاركة الملف مع فتح قائمة المشاركة
        await Share.shareXFiles(
          [XFile(file.path, name: fileName)],
          text: 'نتائج المختبر - $patientName\nرقم المريض: $patientId',
          subject: 'نتائج المختبر - $patientName',
        );
        
        print('✅ تم مشاركة الملف بنجاح');
        
      } else {
        throw Exception('فشل في حفظ الملف أو الملف فارغ');
      }
    } catch (e) {
      print('❌ خطأ في حفظ أو مشاركة الملف: $e');
      throw e;
    }
  }

  // دالة مساعدة لتحميل ومشاركة ملف PDF من رابط
  Future<void> _downloadAndSharePdf(String pdfUrl, String patientId, String patientName) async {
    try {
      print('📥 تحميل ملف PDF من: $pdfUrl');
      final pdfResponse = await http.get(Uri.parse(pdfUrl)).timeout(const Duration(seconds: 30));
      
      if (pdfResponse.statusCode == 200) {
        print('✅ تم تحميل ملف PDF بنجاح');
        await _saveAndSharePdf(pdfResponse.bodyBytes, patientId, patientName);
      } else {
        throw Exception('فشل في تحميل ملف PDF: ${pdfResponse.statusCode}');
      }
    } catch (e) {
      print('❌ خطأ في تحميل ملف PDF: $e');
      throw e;
    }
  }

  // دالة مساعدة لإنشاء ملف PDF بسيط كبديل
  Future<void> _createAndShareSimplePdf(String patientId, String patientName) async {
    try {
      print('🛠️ إنشاء ملف PDF بسيط...');
      
      // إنشاء PDF بسيط
      final PdfDocument document = PdfDocument();
      final PdfPage page = document.pages.add();
      final PdfGraphics graphics = page.graphics;
      
      // استخدام خط يدعم العربية أو إنشاء نص إنجليزي
      final PdfFont font = PdfStandardFont(PdfFontFamily.helvetica, 16);
      
      // إضافة نص باللغة الإنجليزية لتجنب مشاكل الخطوط العربية
      graphics.drawString(
        'Lab Results - $patientName',
        font,
        bounds: const Rect.fromLTWH(50, 50, 500, 50),
      );
      
      graphics.drawString(
        'Patient ID: $patientId',
        font,
        bounds: const Rect.fromLTWH(50, 100, 500, 50),
      );
      
      graphics.drawString(
        'Print Date: ${DateTime.now().toString().split(' ')[0]}',
        font,
        bounds: const Rect.fromLTWH(50, 150, 500, 50),
      );
      
      graphics.drawString(
        'Note: This is a temporary file. Please contact the center for complete results.',
        font,
        bounds: const Rect.fromLTWH(50, 200, 500, 100),
      );
      
      // إضافة نص إضافي باللغة الإنجليزية
      graphics.drawString(
        'Lab Results - $patientName',
        font,
        bounds: const Rect.fromLTWH(50, 250, 500, 50),
      );
      
      // حفظ الملف
      final Directory appDocDir = await getApplicationDocumentsDirectory();
      final String filePath = '${appDocDir.path}/lab_result_simple_$patientId.pdf';
      final File file = File(filePath);
      final List<int> bytes = await document.save();
      await file.writeAsBytes(bytes);
      document.dispose();
      
      print('💾 تم إنشاء ملف PDF بسيط في: ${file.path}');
      
      // مشاركة الملف مع فتح قائمة المشاركة
      final String cleanName = patientName.replaceAll(RegExp(r'[0-9]'), '').replaceAll(' ', '_').replaceAll(RegExp(r'_+'), '_');
      final String fileName = 'نتائج_$cleanName.pdf';
      await Share.shareXFiles(
        [XFile(file.path, name: fileName)],
        text: 'نتائج المختبر - $patientName\nرقم المريض: $patientId\nLab Results - $patientName\nPatient ID: $patientId',
        subject: 'نتائج المختبر - $patientName',
      );
      
      print('✅ تم مشاركة الملف البسيط بنجاح');
      
    } catch (e) {
      print('❌ خطأ في إنشاء ملف PDF بسيط: $e');
      
      // محاولة بديلة - إنشاء ملف نصي بسيط
      try {
        print('🔄 محاولة إنشاء ملف نصي بديل...');
        await _createAndShareTextFile(patientId, patientName);
      } catch (textError) {
        print('❌ فشل في إنشاء ملف نصي: $textError');
        throw e; // إعادة رمي الخطأ الأصلي
      }
    }
  }

  // دالة مساعدة لإنشاء ملف نصي كبديل أخير
  Future<void> _createAndShareTextFile(String patientId, String patientName) async {
    try {
      print('📝 إنشاء ملف نصي...');
      
      final Directory appDocDir = await getApplicationDocumentsDirectory();
      final String filePath = '${appDocDir.path}/lab_result_$patientId.txt';
      final File file = File(filePath);
      
      // إنشاء محتوى الملف
      final String content = '''
نتائج المختبر - Lab Results
============================

اسم المريض / Patient Name: $patientName
رقم المريض / Patient ID: $patientId
تاريخ الطباعة / Print Date: ${DateTime.now().toString().split(' ')[0]}

ملاحظة / Note:
هذا ملف مؤقت. يرجى التواصل مع المركز للحصول على النتائج الكاملة.
This is a temporary file. Please contact the center for complete results.

مركز الرومي الطبي
Al-Roomy Medical Center
''';
      
      await file.writeAsString(content, encoding: utf8);
      
      print('💾 تم إنشاء ملف نصي في: ${file.path}');
      
      // مشاركة الملف النصي
      final String cleanName = patientName.replaceAll(RegExp(r'[0-9]'), '').replaceAll(' ', '_').replaceAll(RegExp(r'_+'), '_');
      final String fileName = 'نتائج_$cleanName.txt';
      await Share.shareXFiles(
        [XFile(file.path, name: fileName)],
        text: 'نتائج المختبر - $patientName\nرقم المريض: $patientId',
        subject: 'نتائج المختبر - $patientName',
      );
      
      print('✅ تم مشاركة الملف النصي بنجاح');
      
    } catch (e) {
      print('❌ خطأ في إنشاء ملف نصي: $e');
      throw e;
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
          title: const Text(
            "نتائج المختبر",
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
                          color: Colors.grey.withOpacity(0.1),
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
                            // رقم الإيصال
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setState(() => _selectedSearchMethod = 1),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                                  decoration: BoxDecoration(
                                    color: _selectedSearchMethod == 1 ? const Color(0xFF2FBDAF) : Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: _selectedSearchMethod == 1 ? const Color(0xFF2FBDAF) : Colors.grey[300]!,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.receipt,
                                        color: _selectedSearchMethod == 1 ? Colors.white : Colors.grey[600],
                                        size: 20,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'رقم الإيصال',
                                        style: TextStyle(
                                          color: _selectedSearchMethod == 1 ? Colors.white : Colors.grey[600],
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            // رقم الهاتف
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setState(() => _selectedSearchMethod = 0),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                                  decoration: BoxDecoration(
                                    color: _selectedSearchMethod == 0 ? const Color(0xFF2FBDAF) : Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: _selectedSearchMethod == 0 ? const Color(0xFF2FBDAF) : Colors.grey[300]!,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.phone,
                                        color: _selectedSearchMethod == 0 ? Colors.white : Colors.grey[600],
                                        size: 20,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'رقم الهاتف',
                                        style: TextStyle(
                                          color: _selectedSearchMethod == 0 ? Colors.white : Colors.grey[600],
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Search Input Section
                  if (_selectedSearchMethod == 1) ...[
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.1),
                            spreadRadius: 2,
                            blurRadius: 15,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
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
                              decoration: InputDecoration(
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _searchByReceipt,
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
                    ),
                  ] else ...[
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.1),
                            spreadRadius: 2,
                            blurRadius: 15,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _searchByPhone,
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
                                  'الاستعلام عن النتيجة',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ],

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
                        style: TextStyle(
                          color: Colors.red[700],
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),

                  // Results Section
                  Expanded(
                    child: _patients.isEmpty && !_isLoading && _errorMessage == null
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  _selectedSearchMethod == 0 ? Icons.phone : Icons.receipt,
                                  size: 64,
                                  color: Colors.grey[400],
                                ),
                                const SizedBox(height: 16),
                                if (!_isReceiptFieldFocused || _selectedSearchMethod == 0)
                                  Text(
                                    _selectedSearchMethod == 0 
                                        ? 'اضغط على "الاستعلام عن النتيجة" للعثور على نتائج المختبر المرتبطة برقم هاتفك'
                                        : 'أدخل رقم الإيصال واضغط على "البحث" للعثور على نتائج المختبر',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: const Color.fromARGB(255, 250, 152, 5),
                                      height: 1.5,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            itemCount: _patients.length,
                            itemBuilder: (context, index) {
                              final patient = _patients[index];
                              return _buildPatientCard(patient);
                            },
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

  Widget _buildPatientCard(Map<String, dynamic> patient) {
    final patientId = patient['patient_id']?.toString() ?? '';
    final isLoading = _isLoading && _currentLoadingPatientId == patientId;
    
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
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            ElevatedButton(
              onPressed: isLoading ? null : () => _viewResults(patient),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2FBDAF),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text(
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
