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

    if (!mounted) return;
    setState(() => isLoading = true);

    // التحقق من عدم وجود حجز سابق لنفس الشخص في نفس اليوم
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

    if (!mounted) return;

    if (existingBooking.docs.isNotEmpty) {
      setState(() => isLoading = false);
      _showDialog(
        "حجز موجود",
        "يوجد حجز سابق لنفس الاسم في نفس اليوم لهذا الطبيب. لا يمكن الحجز مرة اخرى",
      );
      return;
    }

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

    final prefs = await SharedPreferences.getInstance();
    final patientId = prefs.getString('userId');
    final bool bookingConfirmationRequired =
        await _isBookingConfirmationRequired();

    // جلب اسم صاحب الحساب الذي أنشأ الحجز من كولكشن patients
    String? accountOwnerName;

    if (patientId != null && patientId.isNotEmpty) {
      try {
        final accountDoc =
            await FirebaseFirestore.instance
                .collection('patients')
                .doc(patientId)
                .get();

        if (accountDoc.exists) {
          accountOwnerName = accountDoc.data()?['name'];
        }
      } catch (e) {
        print('خطأ في جلب اسم صاحب الحساب: $e');
      }
    }

    // حذف الحجز القديم في حالة إعادة الحجز
    if (widget.isReschedule && widget.oldBookingData != null) {
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

    try {
      final doctorAppRef =
          FirebaseFirestore.instance
              .collection('medicalFacilities')
              .doc(widget.facilityId)
              .collection('specializations')
              .doc(widget.specializationId)
              .collection('doctors')
              .doc(widget.doctorId)
              .collection('appointments')
              .doc();

      final facilityAppRef = FirebaseFirestore.instance
          .collection('medicalFacilities')
          .doc(widget.facilityId)
          .collection('appointments')
          .doc(doctorAppRef.id);

      final counterRef = FirebaseFirestore.instance
          .collection('medicalFacilities')
          .doc(widget.facilityId)
          .collection('counters')
          .doc('appointments');
      int? bookingNumber;

      // تنفيذ Transaction لتوليد رقم تسلسلي وتجنب التضارب
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final counterSnapshot = await transaction.get(counterRef);

        int nextNumber = 1;

        if (counterSnapshot.exists && counterSnapshot.data() != null) {
          nextNumber = (counterSnapshot.data()!['lastBookingNumber'] ?? 0) + 1;
        }
        bookingNumber = nextNumber;
        // تحديث العداد
        transaction.set(counterRef, {
          'lastBookingNumber': nextNumber,
        }, SetOptions(merge: true));

        final bookingData = {
          'bookingNumber': nextNumber,
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
          'isConfirmed': !bookingConfirmationRequired,
          'status': bookingConfirmationRequired ? 'pending' : 'confirmed',
          'createdById': patientId,
          'createdByName': 'by App',
          'accountOwnerName': accountOwnerName,
        };

        // حفظ البيانات في كلا المجموعتين
        transaction.set(doctorAppRef, bookingData);
        transaction.set(facilityAppRef, bookingData);
      });

      final bookingId = doctorAppRef.id;
      final bookingStatus =
          bookingConfirmationRequired ? 'pending' : 'confirmed';

      if (!mounted) return;

      setState(() {
        selectedTime = availableTime;
        showBookingSuccess = true;
      });

      // الانتقال لصفحة نجاح الحجز مباشرة (مع إبقاء مؤشر التحميل حتى اكتمال الانتقال
      // لتجنب ظهور صفحة الإدخال للحظة قبل الانتقال)
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder:
                (context) => BookingSuccessScreen(
                  bookingId: bookingId,
                  bookingNumber: bookingNumber.toString(),
                  bookingStatus: bookingStatus,
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
        ).then((_) {
          if (mounted) {
            setState(() => isLoading = false);
          }
        });
      }

      // توليد PDF فقط إذا كان الحجز مؤكد
      if (bookingStatus == 'confirmed') {
        _generateBookingPdf(
          dateStr: dateStr,
          availableTime: availableTime,
          period: period,
          bookingId: bookingId,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => isLoading = false);
        _showDialog('خطأ', 'حدث خطأ أثناء حفظ الحجز: $e');
      }
    }
  }

  String? _getPeriodStartTime(String period) {
    try {
      final dayName =
          intl.DateFormat('EEEE', 'ar').format(widget.selectedDate).trim();

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

      if (patientName == null || patientName!.isEmpty) {
        throw Exception('اسم المريض مطلوب');
      }

      if (patientPhone == null || patientPhone!.isEmpty) {
        throw Exception('رقم الهاتف مطلوب');
      }

      String? periodStartTime;

      try {
        final dayName =
            intl.DateFormat('EEEE', 'ar').format(widget.selectedDate).trim();

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

        if (schedule == null && alternativeDayName != null) {
          schedule = widget.workingSchedule[alternativeDayName];
        }

        if (schedule != null && schedule[period] != null) {
          periodStartTime = schedule[period]['start'];
        }
      } catch (e) {
        print('خطأ في جلب وقت بداية الفترة: $e');
      }

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

      final tempDir = await getTemporaryDirectory();

      final pdfFile = File('${tempDir.path}/booking_$bookingId.pdf');

      await pdfFile.writeAsBytes(pdfData);

      print('=== تم إنشاء PDF بنجاح ===');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم إنشاء PDF للحجز بنجاح'),
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
            duration: Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Future<bool> _isBookingConfirmationRequired() async {
    try {
      final doc =
          await FirebaseFirestore.instance
              .collection('medicalFacilities')
              .doc(widget.facilityId)
              .get();

      if (!doc.exists) {
        return false;
      }

      return doc.data()?['requireBookingConfirmation'] == true;
    } catch (e) {
      print('خطأ في قراءة إعداد تأكيد الحجز للمركز: $e');
      return false;
    }
  }

  Future<bool> _isOtpRequired() async {
    try {
      final doc =
          await FirebaseFirestore.instance
              .collection('appConfig')
              .doc('version')
              .get();

      if (!doc.exists) {
        return false;
      }

      return doc.data()?['requireOtp'] == true;
    } catch (e) {
      print('خطأ في قراءة إعداد OTP: $e');
      return false;
    }
  }

  Future<void> _sendOtpAndVerify() async {
    try {
      if (!mounted) return;
      setState(() => isLoading = true);

      final bool otpRequired = await _isOtpRequired();

      if (!mounted) return;

      if (!otpRequired) {
        await confirmBooking();
        return;
      }

      final String phone = patientPhone!.trim();
      final String otp = SMSService.generateOTP();

      final result = await SMSService.sendOTP(phone, otp);

      if (!mounted) return;

      if (result['success'] == true) {
        setState(() => isLoading = false);

        Navigator.push(
          context,
          MaterialPageRoute(
            builder:
                (context) => OTPVerificationScreen(
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
        setState(() => isLoading = false);

        _showDialog(
          'خطأ',
          'فشل إرسال رمز التحقق. تحقق من رقم الهاتف وحاول مجدداً.',
        );
      }
    } catch (e) {
      if (!mounted) return;

      setState(() => isLoading = false);

      _showDialog('خطأ', 'حدث خطأ: $e');
    }
  }

  void _showDialog(String title, String message) {
    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: Center(
              child: Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            content: Text(message, textAlign: TextAlign.center),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            actionsAlignment: MainAxisAlignment.center,
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text("موافق", style: TextStyle(fontSize: 16)),
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
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFF2FBDAF),
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
                          TextFormField(
                            decoration: const InputDecoration(
                              labelText: 'الاسم *',
                              hintText: 'أدخل الاسم (اسمين على الأقل)',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(
                                Icons.person,
                                color: Color(0xFF2FBDAF),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderSide: BorderSide(
                                  color: Color(0xFF2FBDAF),
                                  width: 2,
                                ),
                              ),
                              labelStyle: TextStyle(color: Color(0xFF2FBDAF)),
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

                          TextFormField(
                            decoration: const InputDecoration(
                              labelText: 'رقم الهاتف *',
                              hintText: 'أدخل رقم الهاتف (10 أرقام على الأقل)',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(
                                Icons.phone,
                                color: Color(0xFF2FBDAF),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderSide: BorderSide(
                                  color: Color(0xFF2FBDAF),
                                  width: 2,
                                ),
                              ),
                              labelStyle: TextStyle(color: Color(0xFF2FBDAF)),
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

                          const Spacer(),

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
                                side: const BorderSide(
                                  color: Color(0xFF2FBDAF),
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
