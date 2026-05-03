import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:hospital_app/models/country.dart';
import 'package:hospital_app/screnns/booking_success_screen.dart';
import 'package:hospital_app/screnns/otp_verification_screen.dart';
import 'package:hospital_app/services/sms_service.dart';
import 'package:hospital_app/services/syncfusion_pdf_service.dart';
import 'package:intl/intl.dart' as intl;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PatientInfoScreen extends StatefulWidget {
  final String facilityId;
  final String specializationId;
  final String doctorId;
  final DateTime selectedDate;
  final String? selectedShift;
  final Map<String, dynamic> workingSchedule;
  final bool isReschedule;
  final Map<String, dynamic>? oldBookingData;

  const PatientInfoScreen({
    super.key,
    required this.facilityId,
    required this.specializationId,
    required this.doctorId,
    required this.selectedDate,
    required this.selectedShift,
    required this.workingSchedule,
    this.isReschedule = false,
    this.oldBookingData,
  });

  @override
  State<PatientInfoScreen> createState() => _PatientInfoScreenState();
}

class _PatientInfoScreenState extends State<PatientInfoScreen> {
  String? patientName;
  String? patientPhone;
  bool isLoading = false;
  String? selectedTime;
  bool showBookingSuccess = false;

  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  final FocusNode _nameFocus = FocusNode();
  final FocusNode _phoneFocus = FocusNode();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  String? facilityName;
  String? specializationName;
  String? doctorName;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _phoneController = TextEditingController();
    _loadFacilityData();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusScope.of(context).requestFocus(_nameFocus);
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _nameFocus.dispose();
    _phoneFocus.dispose();
    super.dispose();
  }

  Future<void> _loadFacilityData() async {
    try {
      // جلب اسم المركز
      final facilityDoc =
          await FirebaseFirestore.instance
              .collection('medicalFacilities')
              .doc(widget.facilityId)
              .get();

      if (facilityDoc.exists) {
        facilityName = facilityDoc.data()?['name'] ?? 'مركز طبي';
      }

      // جلب اسم التخصص
      final specializationDoc =
          await FirebaseFirestore.instance
              .collection('medicalFacilities')
              .doc(widget.facilityId)
              .collection('specializations')
              .doc(widget.specializationId)
              .get();

      if (specializationDoc.exists) {
        specializationName =
            specializationDoc.data()?['specName'] ?? 'تخصص طبي';
      }

      // جلب اسم الطبيب
      final doctorDoc =
          await FirebaseFirestore.instance
              .collection('medicalFacilities')
              .doc(widget.facilityId)
              .collection('specializations')
              .doc(widget.specializationId)
              .collection('doctors')
              .doc(widget.doctorId)
              .get();

      if (doctorDoc.exists) {
        final d = doctorDoc.data();
        // محاولة جلب اسم الطبيب من عدة مفاتيح محتملة بما فيها docName
        doctorName =
            (d?['docName'] ??
                    d?['name'] ??
                    d?['doctorName'] ??
                    d?['displayName'] ??
                    d?['fullName'] ??
                    d?['nameAr'] ??
                    d?['arabicName'])
                ?.toString()
                .trim();
        if (doctorName == null || doctorName!.isEmpty) {
          doctorName = 'طبيب';
        }
      }

      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      print('خطأ في جلب بيانات المركز: $e');
    }
  }

  Future<Map<String, String>?> getAvailableTime(DateTime date) async {
    final shiftKey = widget.selectedShift ?? 'morning';
    final dateStr = intl.DateFormat('yyyy-MM-dd').format(date);

    final shiftBookings =
        await FirebaseFirestore.instance
            .collection('medicalFacilities')
            .doc(widget.facilityId)
            .collection('specializations')
            .doc(widget.specializationId)
            .collection('doctors')
            .doc(widget.doctorId)
            .collection('appointments')
            .where('date', isEqualTo: dateStr)
            .where('period', isEqualTo: shiftKey)
            .get();

    

    return {'time': '', 'period': shiftKey};
  }

  Future<void> confirmBooking() async {
    print('TEST: بدء تأكيد الحجز');
    print('=== بدء تأكيد الحجز ===');
    print('اسم المريض: $patientName');
    print('رقم الهاتف: $patientPhone');
    print('التاريخ المحدد: ${widget.selectedDate}');
    print('الفترة المحددة: ${widget.selectedShift}');

    if (patientName == null ||
        patientName!.isEmpty ||
        patientPhone == null ||
        patientPhone!.isEmpty) {
      _showDialog("تنبيه", "يرجى إدخال الاسم ورقم الهاتف");
      return;
    }

    // التحقق من الاسم (اسمين على الأقل)
    List<String> nameParts =
        patientName!
            .trim()
            .split(' ')
            .where((part) => part.isNotEmpty)
            .toList();
    if (nameParts.length < 2) {
      _showDialog("تنبيه", "يرجى إدخال الاسم (اسمين على الأقل)");
      return;
    }

    // التحقق من رقم الهاتف (يجب أن يحتوي على أرقام فقط)
    String phoneDigits = patientPhone!.replaceAll(RegExp(r'[^0-9]'), '');
    if (phoneDigits.length < 10) return;

    // التحقق من عدم وجود حجز سابق لنفس الشخص في نفس اليوم (بالاسم الثلاثي فقط)
    final checkDateStr = intl.DateFormat(
      'yyyy-MM-dd',
    ).format(widget.selectedDate);
    final existingBooking =
        await FirebaseFirestore.instance
            .collection('medicalFacilities')
            .doc(widget.facilityId)
            .collection('specializations')
            .doc(widget.specializationId)
            .collection('doctors')
            .doc(widget.doctorId)
            .collection('appointments')
            .where('date', isEqualTo: checkDateStr)
            .where('patientName', isEqualTo: patientName)
            .get();

    if (existingBooking.docs.isNotEmpty) {
      _showDialog(
        "حجز موجود",
        "يوجد حجز سابق لنفس الاسم في نفس اليوم لهذا الطبيب. لا يمكن الحجز مرة اخرى",
      );
      return;
    }

    if (!mounted) return;
    setState(() => isLoading = true);

    final result = await getAvailableTime(widget.selectedDate);
    if (!mounted) return;

    if (result == null) {
      if (!mounted) return;
      setState(() => isLoading = false);

      return;
    }

    final availableTime = result['time']!;
    final period = result['period']!;
    final dateStr = intl.DateFormat('yyyy-MM-dd').format(widget.selectedDate);

    // Get current patient ID from SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    final patientId = prefs.getString('userId');

    if (widget.isReschedule && widget.oldBookingData != null) {
      // حذف الحجز القديم أولاً
      await FirebaseFirestore.instance
          .collection('medicalFacilities')
          .doc(widget.oldBookingData!['facilityId'])
          .collection('specializations')
          .doc(widget.oldBookingData!['specializationId'])
          .collection('doctors')
          .doc(widget.oldBookingData!['doctorId'])
          .collection('appointments')
          .doc(widget.oldBookingData!['id'])
          .delete();
    }

    // إضافة الحجز الجديد
    final bookingDocRef = await FirebaseFirestore.instance
        .collection('medicalFacilities')
        .doc(widget.facilityId)
        .collection('specializations')
        .doc(widget.specializationId)
        .collection('doctors')
        .doc(widget.doctorId)
        .collection('appointments')
        .add({
          'patientName': patientName,
          'patientPhone': patientPhone,
          'patientId': patientId,
          'date': dateStr,
          'time': availableTime,
          'period': period,
          'createdAt': FieldValue.serverTimestamp(),
          'isConfirmed': false,
          'createdById': patientId,
          'createdByName': 'by App',
        });

    final bookingId = bookingDocRef.id;
    // إضافة نسخة من الحجز داخل المركز
    await FirebaseFirestore.instance
        .collection('medicalFacilities')
        .doc(widget.facilityId)
        .collection('appointments')
        .doc(bookingId)
        .set({
          'patientName': patientName,
          'patientPhone': patientPhone,
          'patientId': patientId,
          'facilityId': widget.facilityId,
          'centralSpecialtyId': widget.specializationId,
          'doctorId': widget.doctorId,
          'doctorName': doctorName ?? 'طبيب',
          'specializationName': specializationName ?? 'تخصص طبي',
          'date': dateStr,
          'time': availableTime,
          'period': period,
          'createdAt': FieldValue.serverTimestamp(),
          'isConfirmed': false,
          'createdById': patientId,
          'createdByName': 'by App',
        });

    if (!mounted) return;

    setState(() {
      isLoading = false;
      selectedTime = availableTime;
      showBookingSuccess = true;
    });

    // توليد PDF للحجز
    print('=== بدء توليد PDF من confirmBooking ===');
    await _generateBookingPdf(
      dateStr: dateStr,
      availableTime: availableTime,
      period: period,
      bookingId: bookingId,
    );

    // الانتقال لصفحة نجاح الحجز
    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder:
              (context) => BookingSuccessScreen(
                bookingId: bookingId,
                patientName: patientName!,
                patientPhone: patientPhone!,
                bookingDate: widget.selectedDate,
                bookingTime: availableTime,
                period: period,
                facilityName: facilityName ?? 'مركز طبي',
                specializationName: specializationName ?? 'تخصص طبي',
                doctorName: doctorName ?? 'طبيب',
                periodStartTime: _getPeriodStartTime(period),
              ),
        ),
      );
    }
  }

  String? _getPeriodStartTime(String period) {
    try {
      final dayName =
          intl.DateFormat('EEEE', 'ar').format(widget.selectedDate).trim();

      // محاولة أسماء الأيام المختلفة
      String? alternativeDayName;
      switch (widget.selectedDate.weekday) {
        case 1:
          alternativeDayName = 'الاثنين';
          break;
        case 2:
          alternativeDayName = 'الثلاثاء';
          break;
        case 3:
          alternativeDayName = 'الأربعاء';
          break;
        case 4:
          alternativeDayName = 'الخميس';
          break;
        case 5:
          alternativeDayName = 'الجمعة';
          break;
        case 6:
          alternativeDayName = 'السبت';
          break;
        case 7:
          alternativeDayName = 'الأحد';
          break;
      }

      var schedule = widget.workingSchedule[dayName];

      // إذا لم يجد الجدول، جرب الاسم البديل
      if (schedule == null && alternativeDayName != null) {
        schedule = widget.workingSchedule[alternativeDayName];
      }

      if (schedule != null && schedule[period] != null) {
        return schedule[period]['start'];
      }
    } catch (e) {
      print('خطأ في جلب وقت بداية الفترة: $e');
    }
    return null;
  }

  Future<void> _generateBookingPdf({
    required String dateStr,
    required String availableTime,
    required String period,
    required String bookingId,
  }) async {
    try {
      print('TEST: بدء إنشاء PDF');
      print('=== بدء إنشاء PDF ===');
      print('التاريخ: $dateStr');
      print('الوقت المتاح: $availableTime');
      print('الفترة: $period');
      print('معرف الحجز: $bookingId');

      // التحقق من وجود البيانات المطلوبة
      if (patientName == null || patientName!.isEmpty) {
        throw Exception('اسم المريض مطلوب');
      }

      if (patientPhone == null || patientPhone!.isEmpty) {
        throw Exception('رقم الهاتف مطلوب');
      }

      // جلب وقت بداية الفترة من جدول العمل
      String? periodStartTime;
      try {
        final dayName =
            intl.DateFormat('EEEE', 'ar').format(widget.selectedDate).trim();

        // محاولة أسماء الأيام المختلفة
        String? alternativeDayName;
        switch (widget.selectedDate.weekday) {
          case 1:
            alternativeDayName = 'الاثنين';
            break;
          case 2:
            alternativeDayName = 'الثلاثاء';
            break;
          case 3:
            alternativeDayName = 'الأربعاء';
            break;
          case 4:
            alternativeDayName = 'الخميس';
            break;
          case 5:
            alternativeDayName = 'الجمعة';
            break;
          case 6:
            alternativeDayName = 'السبت';
            break;
          case 7:
            alternativeDayName = 'الأحد';
            break;
        }
        print('اسم اليوم: $dayName');
        print('الفترة: $period');
        print('جدول العمل: ${widget.workingSchedule}');

        var schedule = widget.workingSchedule[dayName];
        print('جدول اليوم: $schedule');

        // إذا لم يجد الجدول، جرب الاسم البديل
        if (schedule == null && alternativeDayName != null) {
          print('جرب الاسم البديل: $alternativeDayName');
          schedule = widget.workingSchedule[alternativeDayName];
          print('جدول اليوم البديل: $schedule');
        }

        if (schedule != null && schedule[period] != null) {
          periodStartTime = schedule[period]['start'];
          print('وقت بداية الفترة: $periodStartTime');
        } else {
          print(
            'لم يتم العثور على جدول للفترة $period في يوم $dayName أو $alternativeDayName',
          );
        }
      } catch (e) {
        print('خطأ في جلب وقت بداية الفترة: $e');
      }

      // إنشاء PDF وحفظه باسم محدد
      final pdfData = await SyncfusionPdfService.generateBookingPdfData(
        facilityName: facilityName ?? 'مركز طبي',
        specializationName: specializationName ?? 'تخصص طبي',
        doctorName: doctorName ?? 'طبيب',
        patientName: patientName!,
        patientPhone: patientPhone!,
        bookingDate: widget.selectedDate,
        bookingTime: availableTime,
        period: period,
        bookingId: bookingId,
        periodStartTime: periodStartTime,
      );

      // حفظ PDF في مجلد مؤقت
      final tempDir = await getTemporaryDirectory();
      final pdfFile = File('${tempDir.path}/booking_$bookingId.pdf');
      await pdfFile.writeAsBytes(pdfData);

      print('=== تم إنشاء PDF بنجاح ===');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('تم إنشاء PDF للحجز بنجاح'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('خطأ في توليد PDF: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في إنشاء PDF: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Future<void> _sendOtpAndVerify() async {
    setState(() => isLoading = true);
    try {
      final String phone = patientPhone!.trim();
      final String otp = SMSService.generateOTP();
      final result = await SMSService.sendOTP(phone, otp);
      if (!mounted) return;
      if (result['success'] == true) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => OTPVerificationScreen(
              phoneNumber: phone,
              name: patientName ?? '',
              password: '',
              initialOtp: otp,
              initialOtpCreatedAt: DateTime.now(),
              country: Country.countries.first,
              verificationMethod: 'sms',
              onVerified: confirmBooking,
            ),
          ),
        );
      } else {
        _showDialog('خطأ', 'فشل إرسال رمز التحقق. تحقق من رقم الهاتف وحاول مجدداً.');
      }
    } catch (e) {
      if (mounted) _showDialog('خطأ', 'حدث خطأ: $e');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _showDialog(String title, String message) {
    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: Center(
              child: Text(title, style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            content: Text(message, textAlign: TextAlign.center),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            actionsAlignment: MainAxisAlignment.center,
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text("موافق", style: TextStyle(fontSize: 16)),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            widget.isReschedule ? "تأجيل الحجز" : "إدخال البيانات",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: const Color(0xFF2FBDAF),
              fontSize: 30,
            ),
          ),
        ),
        body: SafeArea(
          child:
              isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          // حقل الاسم
                          TextFormField(
                            decoration: InputDecoration(
                              labelText: 'الاسم *',
                              hintText: 'أدخل الاسم (اسمين على الأقل)',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(
                                Icons.person,
                                color: const Color(0xFF2FBDAF),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderSide: BorderSide(
                                  color: const Color(0xFF2FBDAF),
                                  width: 2,
                                ),
                              ),
                              labelStyle: TextStyle(
                                color: const Color(0xFF2FBDAF),
                              ),
                            ),
                            focusNode: _nameFocus,
                            textInputAction: TextInputAction.next,
                            onFieldSubmitted:
                                (_) => FocusScope.of(
                                  context,
                                ).requestFocus(_phoneFocus),
                            onChanged: (val) => patientName = val,
                            textDirection: TextDirection.rtl,
                            controller: _nameController,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'يرجى إدخال الاسم';
                              }
                              List<String> nameParts =
                                  value
                                      .trim()
                                      .split(' ')
                                      .where((part) => part.isNotEmpty)
                                      .toList();
                              if (nameParts.length < 2) {
                                return 'يرجى إدخال الاسم (اسمين على الأقل)';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          // حقل رقم الهاتف
                          TextFormField(
                            decoration: InputDecoration(
                              labelText: 'رقم الهاتف *',
                              hintText: 'أدخل رقم الهاتف (10 أرقام على الأقل)',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(
                                Icons.phone,
                                color: const Color(0xFF2FBDAF),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderSide: BorderSide(
                                  color: const Color(0xFF2FBDAF),
                                  width: 2,
                                ),
                              ),
                              labelStyle: TextStyle(
                                color: const Color(0xFF2FBDAF),
                              ),
                            ),
                            focusNode: _phoneFocus,
                            textInputAction: TextInputAction.done,
                            onChanged: (val) => patientPhone = val,
                            keyboardType: TextInputType.phone,
                            textDirection: TextDirection.ltr,
                            controller: _phoneController,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'يرجى إدخال رقم الهاتف';
                              }
                              String phoneDigits = value.replaceAll(
                                RegExp(r'[^0-9]'),
                                '',
                              );
                              if (phoneDigits.length < 10) {
                                return 'رقم الهاتف يجب أن يكون 10 أرقام على الأقل';
                              }
                              return null;
                            },
                          ),

                          // مساحة فارغة لدفع الزر لأسفل
                          const Spacer(),

                          // زر حجز الآن - في نهاية الشاشة
                          SizedBox(
                            width: double.infinity,
                            height: 60,
                            child: OutlinedButton(
                              onPressed: () {
                                if (_formKey.currentState!.validate()) {
                                  _sendOtpAndVerify();
                                }
                              },
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(
                                  color: const Color(0xFF2FBDAF),
                                  width: 2,
                                ),
                                foregroundColor: const Color(0xFF2FBDAF),
                                backgroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Text(
                                widget.isReschedule
                                    ? "تأكيد التأجيل"
                                    : "حجز الآن",
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
        ),
      ),
    );
  }
}
