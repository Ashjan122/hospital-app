import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hospital_app/services/syncfusion_pdf_service.dart';
import 'package:path_provider/path_provider.dart';
import 'package:hospital_app/screnns/booking_success_screen.dart';
import 'dart:io';

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
  bool? isBookingForSelf; // null = لم يتم الاختيار بعد، true = لنفسه، false = لشخص آخر
  bool showBookingChoice = true; // عرض خيار الحجز لنفسه أم لشخص آخر
  bool showBookingSuccess = false; // إظهار رسالة نجاح الحجز
  
  // Controllers for text fields
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  
  // Data for PDF generation
  String? facilityName;
  String? specializationName;
  String? doctorName;


  @override
  void initState() {
    super.initState();
    
    // Initialize controllers
    _nameController = TextEditingController();
    _phoneController = TextEditingController();
    
    // إذا كان هذا تأجيل حجز، استخدم البيانات القديمة
    if (widget.isReschedule && widget.oldBookingData != null) {
      patientName = widget.oldBookingData!['patientName'];
      patientPhone = widget.oldBookingData!['patientPhone'];
      _nameController.text = patientName ?? '';
      _phoneController.text = patientPhone ?? '';
      isBookingForSelf = false; // تأجيل الحجز يعتبر لشخص آخر
      showBookingChoice = false; // لا نحتاج لخيار الحجز في التأجيل
    } else {
      // اختيار الحجز لنفسي تلقائياً وملء البيانات
      isBookingForSelf = true;
      showBookingChoice = true; // إظهار الخيارات مع تظليل المختار
      _loadPatientDataOnInit();
    }
    
    // جلب بيانات المركز والتخصص والطبيب
    _loadFacilityData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }



  Future<void> _loadPatientDataOnInit() async {
    final prefs = await SharedPreferences.getInstance();
    final userName = prefs.getString('userName');
    final userEmail = prefs.getString('userEmail'); // userEmail يحتوي على رقم الهاتف
    
    if (userName != null && userEmail != null) {
      // تنسيق رقم الهاتف ليكون 10 أرقام يبدأ بـ 0
      String formattedPhone = userEmail;
      
      // إزالة المفتاح الدولي إذا كان موجوداً
      if (formattedPhone.startsWith('249')) {
        formattedPhone = '0' + formattedPhone.substring(3);
      }
      
      // التأكد من أن الرقم يبدأ بـ 0
      if (!formattedPhone.startsWith('0')) {
        formattedPhone = '0' + formattedPhone;
      }
      
      // التأكد من أن الرقم 10 أرقام
      if (formattedPhone.length > 10) {
        formattedPhone = formattedPhone.substring(0, 10);
      }
      
      if (mounted) {
        setState(() {
          patientName = userName;
          patientPhone = formattedPhone;
          _nameController.text = userName;
          _phoneController.text = formattedPhone;
        });
      }
    }
  }

  Future<void> _loadFacilityData() async {
    try {
      // جلب اسم المركز
      final facilityDoc = await FirebaseFirestore.instance
          .collection('medicalFacilities')
          .doc(widget.facilityId)
          .get();
      
      if (facilityDoc.exists) {
        facilityName = facilityDoc.data()?['name'] ?? 'مركز طبي';
      }
      
      // جلب اسم التخصص
      final specializationDoc = await FirebaseFirestore.instance
          .collection('medicalFacilities')
          .doc(widget.facilityId)
          .collection('specializations')
          .doc(widget.specializationId)
          .get();
      
      if (specializationDoc.exists) {
        specializationName = specializationDoc.data()?['specName'] ?? 'تخصص طبي';
      }
      
      // جلب اسم الطبيب
      final doctorDoc = await FirebaseFirestore.instance
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
        doctorName = (d?['docName']
                ?? d?['name']
                ?? d?['doctorName']
                ?? d?['displayName']
                ?? d?['fullName']
                ?? d?['nameAr']
                ?? d?['arabicName'])
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

  Future<void> loadPatientData() async {
    final prefs = await SharedPreferences.getInstance();
    final userName = prefs.getString('userName');
    final userEmail = prefs.getString('userEmail'); // userEmail يحتوي على رقم الهاتف
    
    if (!mounted) return;
    
    if (userName != null && userEmail != null) {
      // تنسيق رقم الهاتف ليكون 10 أرقام يبدأ بـ 0
      String formattedPhone = userEmail;
      
      // إزالة المفتاح الدولي إذا كان موجوداً
      if (formattedPhone.startsWith('249')) {
        formattedPhone = '0' + formattedPhone.substring(3);
      }
      
      // التأكد من أن الرقم يبدأ بـ 0
      if (!formattedPhone.startsWith('0')) {
        formattedPhone = '0' + formattedPhone;
      }
      
      // التأكد من أن الرقم 10 أرقام
      if (formattedPhone.length > 10) {
        formattedPhone = formattedPhone.substring(0, 10);
      }
      
      setState(() {
        patientName = userName;
        patientPhone = formattedPhone;
        _nameController.text = userName;
        _phoneController.text = formattedPhone;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم ملء البيانات تلقائياً من حسابك'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } else {
      // إذا لم توجد بيانات، اعرض رسالة
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('لم يتم العثور على بيانات الحساب، يرجى إدخال البيانات يدوياً'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  Future<Set<String>> getBookedTimes(DateTime date) async {
    final dateStr = intl.DateFormat('yyyy-MM-dd').format(date);
    final snapshot =
        await FirebaseFirestore.instance
            .collection('medicalFacilities')
            .doc(widget.facilityId)
            .collection('specializations')
            .doc(widget.specializationId)
            .collection('doctors')
            .doc(widget.doctorId)
            .collection('appointments')
            .where('date', isEqualTo: dateStr)
            .get();

    return snapshot.docs.map((doc) => doc['time'] as String).toSet();
  }

  Future<Map<String, String>?> getAvailableTime(DateTime date) async {
    final bookedTimes = await getBookedTimes(date);
    final now = DateTime.now();
    final dayName = intl.DateFormat('EEEE', 'ar').format(date).trim();
    final schedule = widget.workingSchedule[dayName];
    final shiftKey = widget.selectedShift ?? 'morning';
    final shiftData = schedule[shiftKey];
    
    if (shiftData == null) return null;

    // فحص عدد المرضى المحجوزين في هذا اليوم والفترة
    final dateStr = intl.DateFormat('yyyy-MM-dd').format(date);
    final shiftBookings = await FirebaseFirestore.instance
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

    // الحصول على حد المرضى للطبيب
    final doctorDoc = await FirebaseFirestore.instance
        .collection('medicalFacilities')
        .doc(widget.facilityId)
        .collection('specializations')
        .doc(widget.specializationId)
        .collection('doctors')
        .doc(widget.doctorId)
        .get();

    final doctorData = doctorDoc.data();
    final patientLimit = shiftKey == 'morning' 
        ? (doctorData?['morningPatientLimit'] ?? 20)
        : (doctorData?['eveningPatientLimit'] ?? 20);

    // فحص إذا كان العدد قد اكتمل
    if (shiftBookings.docs.length >= patientLimit) {
      return null; // لا توجد مواعيد متاحة
    }

    // تحويل الوقت من 12 ساعة إلى 24 ساعة
    int startHour = int.parse(shiftData['start'].split(":")[0]);
    int endHour = int.parse(shiftData['end'].split(":")[0]);
    
    // إذا كان وقت النهاية أقل من وقت البداية، فهذا يعني أنه بعد الظهر
    if (endHour < startHour) {
      endHour += 12; // تحويل إلى 24 ساعة
    }

    for (int hour = startHour; hour <= endHour; hour++) {
      for (String suffix in [":00", ":30"]) {
        final timeStr = '${hour.toString().padLeft(2, '0')}$suffix';
        final timeObj = DateTime(
          date.year,
          date.month,
          date.day,
          hour,
          suffix == ":30" ? 30 : 0,
        );
        if (date.day == now.day && timeObj.isBefore(now)) continue;
        if (!bookedTimes.contains(timeStr)) {
          return {'time': timeStr, 'period': shiftKey};
        }
      }
    }
    return null;
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
    List<String> nameParts = patientName!.trim().split(' ').where((part) => part.isNotEmpty).toList();
    if (nameParts.length < 2) {
      _showDialog("تنبيه", "يرجى إدخال الاسم (اسمين على الأقل)");
      return;
    }
    
    // التحقق من رقم الهاتف (يجب أن يحتوي على أرقام فقط)
    String phoneDigits = patientPhone!.replaceAll(RegExp(r'[^0-9]'), '');
    if (phoneDigits.isEmpty) {
      _showDialog("تنبيه", "يرجى إدخال رقم هاتف صحيح");
      return;
    }

    // التحقق من عدم وجود حجز سابق لنفس الشخص في نفس اليوم (بالاسم الثلاثي فقط)
    final checkDateStr = intl.DateFormat('yyyy-MM-dd').format(widget.selectedDate);
    final existingBooking = await FirebaseFirestore.instance
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
      _showDialog("حجز موجود", "يوجد حجز سابق لنفس الاسم في نفس اليوم لهذا الطبيب. لا يمكن الحجز مرة اخرى");
      return;
    }
    


    if (!mounted) return;
    setState(() => isLoading = true);

    final result = await getAvailableTime(widget.selectedDate);
    if (!mounted) return;
    
    if (result == null) {
      if (!mounted) return;
      setState(() => isLoading = false);
      
      // فحص إذا كان السبب هو اكتمال العدد
      final dateStr = intl.DateFormat('yyyy-MM-dd').format(widget.selectedDate);
      final shiftKey = widget.selectedShift ?? 'morning';
      final shiftBookings = await FirebaseFirestore.instance
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

      final doctorDoc = await FirebaseFirestore.instance
          .collection('medicalFacilities')
          .doc(widget.facilityId)
          .collection('specializations')
          .doc(widget.specializationId)
          .collection('doctors')
          .doc(widget.doctorId)
          .get();

      final doctorData = doctorDoc.data();
      final patientLimit = shiftKey == 'morning' 
          ? (doctorData?['morningPatientLimit'] ?? 20)
          : (doctorData?['eveningPatientLimit'] ?? 20);

      if (shiftBookings.docs.length >= patientLimit) {
        final periodText = shiftKey == 'morning' ? 'الصباحية' : 'المسائية';
        _showDialog(
          "اكتمل العدد", 
          "عذراً، اكتمل العدد المحدد للمرضى في الفترة $periodText لهذا اليوم (${patientLimit} مريض).\nيرجى اختيار يوم آخر أو فترة أخرى."
        );
      } else {
        _showDialog("لا يوجد موعد", "لا توجد مواعيد متاحة في هذا اليوم");
      }
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
          'patientId': patientId, // Save patient ID instead of phone

          'date': dateStr,
          'time': availableTime,
          'period': period,
          'createdAt': FieldValue.serverTimestamp(),
          'isConfirmed': false, // الحجز الجديد يحتاج تأكيد
        });
    
    final bookingId = bookingDocRef.id;

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
          builder: (context) => BookingSuccessScreen(
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
      final dayName = intl.DateFormat('EEEE', 'ar').format(widget.selectedDate).trim();
      
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

  void _selectBookingType(bool forSelf) async {
    if (!mounted) return;
    
    setState(() {
      isBookingForSelf = forSelf;
      // لا نغير showBookingChoice، نبقيه true لإظهار الخيارات
    });

    if (forSelf) {
      // جلب بيانات المريض من SharedPreferences
      await loadPatientData();
    } else {
      // إذا اختار لشخص آخر، امسح البيانات من الحقول
      setState(() {
        patientName = null;
        patientPhone = null;
        _nameController.clear();
        _phoneController.clear();
      });
      
      // اعرض رسالة
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('يرجى إدخال بيانات الشخص المراد الحجز له'),
            backgroundColor: Colors.blue,
          ),
        );
      }
    }
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
        final dayName = intl.DateFormat('EEEE', 'ar').format(widget.selectedDate).trim();
        
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
          print('لم يتم العثور على جدول للفترة $period في يوم $dayName أو $alternativeDayName');
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




  void _showDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
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
          child: isLoading
              ? const Center(child: CircularProgressIndicator())
              : Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    children: [
                        // خيار نوع الحجز - يظهر دائماً
                          const Text(
                            'اختر نوع الحجز:',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2FBDAF),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () => _selectBookingType(true),
                                  icon: Icon(Icons.person, color: isBookingForSelf == true ? Colors.white : const Color(0xFF2FBDAF)),
                                  label: const Text('لنفسي'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: isBookingForSelf == true 
                                        ? const Color(0xFF2FBDAF)
                                        : Colors.grey[200],
                                    foregroundColor: isBookingForSelf == true 
                                        ? Colors.white
                                        : Colors.grey[700],
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () => _selectBookingType(false),
                                  icon: Icon(Icons.person_add, color: isBookingForSelf == false ? Colors.white : const Color(0xFF2FBDAF)),
                                  label: const Text('لشخص آخر'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: isBookingForSelf == false 
                                        ? const Color(0xFF2FBDAF)
                                        : Colors.grey[200],
                                    foregroundColor: isBookingForSelf == false 
                                        ? Colors.white
                                        : Colors.grey[700],
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                        

                        
                        // حقل الاسم
                        TextFormField(
                          decoration: InputDecoration(
                            labelText: 'الاسم *',
                            hintText: 'أدخل الاسم (اسمين على الأقل)',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.person, color: const Color(0xFF2FBDAF)),
                            focusedBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: const Color(0xFF2FBDAF), width: 2),
                            ),
                            labelStyle: TextStyle(color: const Color(0xFF2FBDAF)),
                          ),
                          onChanged: (val) => patientName = val,
                          textDirection: TextDirection.rtl,
                          controller: _nameController,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'يرجى إدخال الاسم';
                            }
                            
                            List<String> nameParts = value.trim().split(' ').where((part) => part.isNotEmpty).toList();
                            
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
                            hintText: 'أدخل رقم الهاتف',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.phone, color: const Color(0xFF2FBDAF)),
                            focusedBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: const Color(0xFF2FBDAF), width: 2),
                            ),
                            labelStyle: TextStyle(color: const Color(0xFF2FBDAF)),
                          ),
                          onChanged: (val) => patientPhone = val,
                          keyboardType: TextInputType.phone,
                          textDirection: TextDirection.rtl,
                          controller: _phoneController,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'يرجى إدخال رقم الهاتف';
                            }
                            
                            String phoneDigits = value.replaceAll(RegExp(r'[^0-9]'), '');
                            if (phoneDigits.isEmpty) {
                              return 'يرجى إدخال رقم هاتف صحيح';
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
                        onPressed: confirmBooking,
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
                          widget.isReschedule ? "تأكيد التأجيل" : "حجز الآن",
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
    );
  }
}
