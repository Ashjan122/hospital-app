import 'package:flutter/material.dart';
import 'package:hospital_app/screnns/patient_info_screen.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart' as intl;
import 'package:cloud_firestore/cloud_firestore.dart';

class BookingScreen extends StatefulWidget {
  final String name;
  final Map<String, dynamic> workingSchedule;
  final String facilityId;
  final String specializationId;
  final String doctorId;
  final bool isReschedule;
  final Map<String, dynamic>? oldBookingData;
  final bool showDoctorInfo; // جديد: لعرض معلومات الطبيب
  final String? doctorSpecialty; // جديد: تخصص الطبيب
  final String? centerName; // جديد: اسم المركز

  const BookingScreen({
    super.key,
    required this.name,
    required this.workingSchedule,
    required this.facilityId,
    required this.specializationId,
    required this.doctorId,
    this.isReschedule = false,
    this.oldBookingData,
    this.showDoctorInfo = false, // افتراضياً false
    this.doctorSpecialty,
    this.centerName,
  });

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  DateTime? selectedDate;
  String? selectedShift;
  bool localeInitialized = false;
  Set<String> blockedDates = {}; // لتخزين الأيام المحظورة
  int? _queuePosition; // رقم الحجز الحالي (n+1)
  int? _dailyCapacity; // السعة المحددة لليوم/الفترة
  bool _loadingQueue = false;
  bool _isFull = false;
  Map<String, dynamic>? _doctorData;
  
  // ملاحظة: هذا الكلاس يتحقق من الوقت الحالي مقارنة بجدول الطبيب
  // أمثلة:
  // 1. إذا كان جدول الطبيب الصباحي ينتهي 12 ظهراً والوقت الحالي 1 ظهراً
  //    فلن تظهر الفترة الصباحية في القائمة
  // 2. إذا كان جدول الطبيب المسائي ينتهي 8 مساءً والوقت الحالي 9 مساءً
  //    فلن تظهر الفترة المسائية في القائمة
  // 3. إذا كان اليوم فيه فترة صباحية فقط وانتهت، أو فترة مسائية فقط وانتهت
  //    فلن يظهر اليوم في القائمة
  // 4. إذا كان الوقت 10 صباحاً والفترة الصباحية تنتهي 12 ظهراً
  //    ستظهر الفترتان (صباحية ومسائية) للمريض للاختيار

  String _toEnglishDigits(String input) {
    const arabicIndic = ['٠','١','٢','٣','٤','٥','٦','٧','٨','٩'];
    const easternArabicIndic = ['۰','۱','۲','۳','۴','۵','۶','۷','۸','۹'];
    String out = input;
    for (int i = 0; i < 10; i++) {
      out = out.replaceAll(arabicIndic[i], i.toString());
      out = out.replaceAll(easternArabicIndic[i], i.toString());
    }
    return out;
  }

  bool _hasScheduleOn(DateTime day) {
    final dayName = intl.DateFormat('EEEE', 'ar').format(day).trim();
    final schedule = widget.workingSchedule[dayName];
    if (schedule == null || schedule is! Map<String, dynamic>) return false;
    final morning = schedule['morning'] as Map<String, dynamic>?;
    final evening = schedule['evening'] as Map<String, dynamic>?;
    
    // التحقق من وجود أي فترة (صباحية أو مسائية)
    final hasMorning = morning != null && morning.isNotEmpty;
    final hasEvening = evening != null && evening.isNotEmpty;
    
    return hasMorning || hasEvening;
  }

  Set<String> _computeBookableDateStrs() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final todayStr = intl.DateFormat('yyyy-MM-dd').format(today);
    final tomorrowStr = intl.DateFormat('yyyy-MM-dd').format(tomorrow);

    final Set<String> allowed = {};

    // التحقق من اليوم الحالي - يجب أن تكون الفترات صالحة حسب الوقت الحالي
    if (_hasScheduleOn(today) && !blockedDates.contains(todayStr)) {
      final dayName = intl.DateFormat('EEEE', 'ar').format(today).trim();
      final schedule = widget.workingSchedule[dayName] as Map<String, dynamic>?;
      
      bool hasValidPeriod = false;
      
      // التحقق من الفترة الصباحية
      final morning = schedule?['morning'] as Map<String, dynamic>?;
      if (morning != null && morning.isNotEmpty) {
        if (_isPeriodValid(morning, 'morning')) {
          hasValidPeriod = true;
        }
      }
      
      // التحقق من الفترة المسائية
      final evening = schedule?['evening'] as Map<String, dynamic>?;
      if (evening != null && evening.isNotEmpty) {
        if (_isPeriodValid(evening, 'evening')) {
          hasValidPeriod = true;
        }
      }
      
      if (hasValidPeriod) {
        allowed.add(todayStr);
      }
    }
    
    // التحقق من الغد - جميع الفترات متاحة بغض النظر عن الوقت الحالي
    if (_hasScheduleOn(tomorrow) && !blockedDates.contains(tomorrowStr)) {
      // للغد، نتحقق من أن له جدول عمل صحيح (أي فترة صباحية أو مسائية)
      final dayName = intl.DateFormat('EEEE', 'ar').format(tomorrow).trim();
      final schedule = widget.workingSchedule[dayName] as Map<String, dynamic>?;
      
      bool hasValidPeriod = false;
      
      // التحقق من الفترة الصباحية
      final morning = schedule?['morning'] as Map<String, dynamic>?;
      if (morning != null && morning.isNotEmpty) {
        hasValidPeriod = true;
      }
      
      // التحقق من الفترة المسائية
      final evening = schedule?['evening'] as Map<String, dynamic>?;
      if (evening != null && evening.isNotEmpty) {
        hasValidPeriod = true;
      }
      
      if (hasValidPeriod) {
      allowed.add(tomorrowStr);
      }
    }

    return allowed;
  }

  int _extractCapacity(Map<String, dynamic>? periodData) {
    return _extractCapacityWithShift(periodData, selectedShift);
  }

  int _extractCapacityWithShift(Map<String, dynamic>? periodData, String? shift) {
    int parseCap(dynamic v) {
      if (v is int) return v;
      if (v is double) return v.toInt();
      if (v is String) return int.tryParse(v) ?? 0;
      return 0;
    }

    // 1) سعة من بيانات الفترة (morning/evening)
    if (periodData != null) {
      final dynamic cap = periodData['capacity'] ?? periodData['maxPatients'] ?? periodData['maxBookings'];
      final c1 = parseCap(cap);
      if (c1 > 0) return c1;
      final dynamic slots = periodData['slots'] ?? periodData['times'];
      if (slots is List && slots.isNotEmpty) return slots.length;
    }

    // 2) سعة على مستوى الطبيب (عام أو حسب الفترة)
    final d = _doctorData;
    if (d != null) {
      // مفاتيح صريحة كما في شاشة تفاصيل الطبيب
      if (shift == 'morning') {
        final cm0 = parseCap(d['morningPatientLimit']);
        if (cm0 > 0) return cm0;
      } else if (shift == 'evening') {
        final ce0 = parseCap(d['eveningPatientLimit']);
        if (ce0 > 0) return ce0;
      }
      // حسب الفترة أولاً
      if (shift == 'morning') {
        final c = parseCap(d['capacityMorning'] ?? d['morningCapacity'] ?? d['maxPatientsMorning'] ?? d['morningMax'] ?? d['morningLimit']);
        if (c > 0) return c;
      } else if (shift == 'evening') {
        final c = parseCap(d['capacityEvening'] ?? d['eveningCapacity'] ?? d['maxPatientsEvening'] ?? d['eveningMax'] ?? d['eveningLimit']);
        if (c > 0) return c;
      }
      // عام
      final cg = parseCap(d['dailyCapacity'] ?? d['maxDailyPatients'] ?? d['maxPatients'] ?? d['maxBookings'] ?? d['capacity'] ?? d['limit']);
      if (cg > 0) return cg;
    }

    return 0;
  }

  Future<void> _updateQueueInfo(DateTime date) async {
    final allowed = _computeBookableDateStrs();
    final dayStr = intl.DateFormat('yyyy-MM-dd').format(date);
    if (!allowed.contains(dayStr)) {
      setState(() {
        _queuePosition = null;
        _dailyCapacity = null;
        _isFull = false;
      });
      return;
    }

    final dayName = intl.DateFormat('EEEE', 'ar').format(date).trim();
    final schedule = widget.workingSchedule[dayName] as Map<String, dynamic>?;

    // لو الفترتين متاحتين ولم يحدد المستخدم الفترة بعد، ننتظر اختيار الفترة
    final hasMorning = schedule?['morning'] != null;
    final hasEvening = schedule?['evening'] != null;
    final String? effectiveShift = (hasMorning && hasEvening)
        ? selectedShift
        : (hasMorning
            ? 'morning'
            : (hasEvening
                ? 'evening'
                : null));

    if (effectiveShift == null) {
      setState(() {
        _queuePosition = null;
        _dailyCapacity = null;
        _isFull = false;
      });
      return;
    }

    setState(() {
      _loadingQueue = true;
    });

    try {
      // قراءة السعة من جدول الطبيب
      final periodData = (schedule?[effectiveShift]) as Map<String, dynamic>?;
      final capacity = _extractCapacity(periodData);

      // حساب عدد الحجوزات الحالية لهذا اليوم والفترة
      final qs = await FirebaseFirestore.instance
          .collection('medicalFacilities')
          .doc(widget.facilityId)
          .collection('specializations')
          .doc(widget.specializationId)
          .collection('doctors')
          .doc(widget.doctorId)
          .collection('appointments')
          .where('date', isEqualTo: dayStr)
          .where('period', isEqualTo: effectiveShift)
          .get();

      final count = qs.docs.length;
      setState(() {
        _dailyCapacity = capacity > 0 ? capacity : null; // إن لم تكن معرفّة، نخليها null
        _queuePosition = count + 1; // موقعه إن حجز الآن
        _isFull = (_dailyCapacity != null) && (count >= _dailyCapacity!);
        _loadingQueue = false;
      });
    } catch (e) {
      setState(() {
        _queuePosition = null;
        _dailyCapacity = null;
        _isFull = false;
        _loadingQueue = false;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('ar', null).then((_) {
      setState(() => localeInitialized = true);
    });
    // تحميل الأيام المحظورة وبيانات الطبيب
    _loadBlockedDates();
    _loadDoctorInfo();
  }

  Future<void> _loadBlockedDates() async {
    try {
      final blockedSnapshot = await FirebaseFirestore.instance
          .collection('medicalFacilities')
          .doc(widget.facilityId)
          .collection('specializations')
          .doc(widget.specializationId)
          .collection('doctors')
          .doc(widget.doctorId)
          .collection('blockedDates')
          .get();
      setState(() {
        blockedDates = blockedSnapshot.docs.map((doc) => doc.id).toSet();
      });
    } catch (e) {
      print('خطأ في تحميل الأيام المحظورة: $e');
    }
  }

  Future<void> _loadDoctorInfo() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('medicalFacilities')
          .doc(widget.facilityId)
          .collection('specializations')
          .doc(widget.specializationId)
          .collection('doctors')
          .doc(widget.doctorId)
          .get();
      if (doc.exists) {
        setState(() {
          _doctorData = doc.data();
        });
      }
    } catch (e) {
      print('خطأ في تحميل بيانات الطبيب: $e');
    }
  }

  Future<bool> isDateBlocked(DateTime date) async {
    try {
      final dateStr = date.toIso8601String().split('T')[0]; // YYYY-MM-DD
      final blockedDoc = await FirebaseFirestore.instance
          .collection('medicalFacilities')
          .doc(widget.facilityId)
          .collection('specializations')
          .doc(widget.specializationId)
          .collection('doctors')
          .doc(widget.doctorId)
          .collection('blockedDates')
          .doc(dateStr)
          .get();
      if (blockedDoc.exists) {
        final blockedData = blockedDoc.data()!;
        final period = blockedData['period'] as String?;
        if (period == 'all' || period == selectedShift) {
          return true;
        }
      }
      return false;
    } catch (e) {
      print('خطأ في فحص اليوم المحظور: $e');
      return false;
    }
  }

  // دالة لتحويل الوقت من نص إلى ساعة
  // مثال: "14:30" -> 14, "09:00" -> 9
  int? _parseTimeToHour(String? timeStr) {
    if (timeStr == null || timeStr.isEmpty) return null;
    try {
      final parts = timeStr.split(':');
      if (parts.length >= 1) {
        return int.tryParse(parts[0]);
      }
    } catch (e) {
      print('خطأ في تحويل الوقت: $timeStr');
    }
    return null;
  }

  // دالة للتحقق من صلاحية الفترة بناءً على الوقت الحالي
  bool _isPeriodValid(Map<String, dynamic>? periodData, String periodType) {
    if (periodData == null || periodData.isEmpty) return false;
    
    final now = DateTime.now();
    final currentHour = now.hour;
    
    if (periodType == 'morning') {
      final endTime = periodData['end'] as String?;
      final endHour = _parseTimeToHour(endTime);
      if (endHour != null) {
        // إذا انتهت الفترة الصباحية، لا تظهر
        return currentHour < endHour;
      }
    } else if (periodType == 'evening') {
      final endTime = periodData['end'] as String?;
      final endHour = _parseTimeToHour(endTime);
      if (endHour != null) {
        // إذا انتهت الفترة المسائية، لا تظهر
        return currentHour < endHour;
      }
    }
    
    // إذا لم نتمكن من تحديد الوقت، نعتبر الفترة صالحة
    return true;
  }

  // دالة لتحديد ما إذا كان اليوم متاح للحجز أم لا
  bool isDateBookable(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    
    // تحويل التواريخ إلى نصوص للمقارنة
    final todayStr = intl.DateFormat('yyyy-MM-dd').format(today);
    final tomorrowStr = intl.DateFormat('yyyy-MM-dd').format(tomorrow);
    final selectedDateStr = intl.DateFormat('yyyy-MM-dd').format(date);
    
    // التحقق من أن التاريخ هو اليوم الحالي أو الغد
    if (selectedDateStr == todayStr) {
      // اليوم الحالي - نتحقق من أن له جدول عمل وأن الفترات صالحة
      final dayName = intl.DateFormat('EEEE', 'ar').format(today).trim();
      final schedule = widget.workingSchedule[dayName] as Map<String, dynamic>?;
      
      if (schedule == null) return false;
      
      final morning = schedule['morning'] as Map<String, dynamic>?;
      final evening = schedule['evening'] as Map<String, dynamic>?;
      
      // التحقق من الفترة الصباحية
      if (morning != null && morning.isNotEmpty) {
        if (_isPeriodValid(morning, 'morning')) {
          return true;
        }
      }
      
      // التحقق من الفترة المسائية
      if (evening != null && evening.isNotEmpty) {
        if (_isPeriodValid(evening, 'evening')) {
          return true;
        }
      }
      
      return false;
    } else if (selectedDateStr == tomorrowStr) {
      // الغد - نتحقق من أن له جدول عمل
      final dayName = intl.DateFormat('EEEE', 'ar').format(tomorrow).trim();
      final schedule = widget.workingSchedule[dayName] as Map<String, dynamic>?;
      
      if (schedule == null) return false;
      
      final morning = schedule['morning'] as Map<String, dynamic>?;
      final evening = schedule['evening'] as Map<String, dynamic>?;
      
      // التحقق من وجود أي فترة (صباحية أو مسائية)
      final hasMorning = morning != null && morning.isNotEmpty;
      final hasEvening = evening != null && evening.isNotEmpty;
      
      return hasMorning || hasEvening;
    }
    
    // باقي الأيام غير متاحة للحجز
    return false;
  }

  // دالة جديدة لتحديد الفترة المناسبة بناءً على الوقت الحالي
  String? _getAppropriateShift(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final isToday = intl.DateFormat('yyyy-MM-dd').format(date) == intl.DateFormat('yyyy-MM-dd').format(today);
    
    final dayName = intl.DateFormat('EEEE', 'ar').format(date).trim();
    final schedule = widget.workingSchedule[dayName] as Map<String, dynamic>?;
    
    if (schedule == null) return null;
    
    final morning = schedule['morning'] as Map<String, dynamic>?;
    final evening = schedule['evening'] as Map<String, dynamic>?;
    
    final hasMorning = morning != null && morning.isNotEmpty;
    final hasEvening = evening != null && evening.isNotEmpty;
    
    // إذا كان هناك فترة واحدة فقط
    if (hasMorning && !hasEvening) {
      if (isToday) {
        return _isPeriodValid(morning, 'morning') ? 'morning' : null;
      } else {
        return 'morning';
      }
    } else if (!hasMorning && hasEvening) {
      if (isToday) {
        return _isPeriodValid(evening, 'evening') ? 'evening' : null;
      } else {
        return 'evening';
      }
    } else if (hasMorning && hasEvening) {
      // إذا كان هناك فترتين
      if (isToday) {
        final isMorningValid = _isPeriodValid(morning, 'morning');
        final isEveningValid = _isPeriodValid(evening, 'evening');
        
        if (isMorningValid && isEveningValid) {
          // الفترتان صالحتان - نختار الصباحية افتراضياً
          return 'morning';
        } else if (isMorningValid) {
          return 'morning';
        } else if (isEveningValid) {
          return 'evening';
        } else {
          return null; // لا توجد فترة صالحة
        }
      } else {
        // الغد - لا نحدد فترة، نترك المستخدم يختار
        return null;
      }
    }
    
    return null;
  }

  // دالة جديدة للحصول على رسالة الفترة المنتهية
  String? _getPeriodEndedMessage(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final isToday = intl.DateFormat('yyyy-MM-dd').format(date) == intl.DateFormat('yyyy-MM-dd').format(today);
    
    if (!isToday) return null; // لا توجد رسائل للغد
    
    // لا تظهر الرسالة إلا إذا كان المستخدم قد اختار فترة
    if (selectedShift == null) return null;
    
    final dayName = intl.DateFormat('EEEE', 'ar').format(date).trim();
    final schedule = widget.workingSchedule[dayName] as Map<String, dynamic>?;
    
    if (schedule == null) return null;
    
    final morning = schedule['morning'] as Map<String, dynamic>?;
    final evening = schedule['evening'] as Map<String, dynamic>?;
    
    final hasMorning = morning != null && morning.isNotEmpty;
    final hasEvening = evening != null && evening.isNotEmpty;
    
    if (hasMorning && hasEvening) {
      // إذا كان هناك فترتين
      final isMorningValid = _isPeriodValid(morning, 'morning');
      final isEveningValid = _isPeriodValid(evening, 'evening');
      
      // تظهر الرسالة فقط إذا اختار المستخدم فترة منتهية
      if (selectedShift == 'morning' && !isMorningValid && isEveningValid) {
        return "انتهى زمن الفترة الصباحية، اختر الفترة المسائية";
      } else if (selectedShift == 'evening' && isMorningValid && !isEveningValid) {
        return "انتهى زمن الفترة المسائية، اختر الفترة الصباحية";
      } else if (selectedShift == 'morning' && !isMorningValid && !isEveningValid) {
        return "انتهى زمن جميع الفترات لهذا اليوم";
      } else if (selectedShift == 'evening' && !isMorningValid && !isEveningValid) {
        return "انتهى زمن جميع الفترات لهذا اليوم";
      }
    } else if (hasMorning && !hasEvening) {
      if (selectedShift == 'morning' && !_isPeriodValid(morning, 'morning')) {
        return "انتهى زمن الفترة الصباحية";
      }
    } else if (!hasMorning && hasEvening) {
      if (selectedShift == 'evening' && !_isPeriodValid(evening, 'evening')) {
        return "انتهى زمن الفترة المسائية";
      }
    }
    
    return null;
  }

  // دالة لجلب جميع الأيام التي لها جدول عمل
  // الأيام المتاحة للحجز: اليوم الحالي (إذا كانت الفترات صالحة) والغد
  // باقي الأيام تظهر لكنها غير متاحة للحجز
  List<DateTime> getAvailableDates() {
    final now = DateTime.now();
    final List<DateTime> dates = [];
    if (widget.workingSchedule.isEmpty) {
      print('workingSchedule فارغ أو غير محدد أو غير موجود في قاعدة البيانات');
      return dates;
    }
    
    // عرض جميع الأيام التي لها جدول عمل (لمدة 7 أيام)
    for (int i = 0; i < 7; i++) {
      final day = now.add(Duration(days: i));
      final dateStr = day.toIso8601String().split('T')[0];
      final name = intl.DateFormat('EEEE', 'ar').format(day).trim();
      final schedule = widget.workingSchedule[name];
      
      if (blockedDates.contains(dateStr)) {
        continue;
      }
      
      if (schedule != null && schedule is Map<String, dynamic>) {
        final morning = schedule['morning'] as Map<String, dynamic>?;
        final evening = schedule['evening'] as Map<String, dynamic>?;
        
        bool hasValidPeriod = false;
        
        // التحقق من الفترة الصباحية
        if (morning != null && morning.isNotEmpty) {
          if (i == 0) { // اليوم الحالي - نتحقق من الوقت الحالي
            if (_isPeriodValid(morning, 'morning')) {
              hasValidPeriod = true;
            }
          } else { // الغد وما بعده - لا نتحقق من الوقت الحالي
            hasValidPeriod = true;
          }
        }
        
        // التحقق من الفترة المسائية
        if (evening != null && evening.isNotEmpty) {
          if (i == 0) { // اليوم الحالي - نتحقق من الوقت الحالي
            if (_isPeriodValid(evening, 'evening')) {
              hasValidPeriod = true;
            }
          } else { // الغد وما بعده - لا نتحقق من الوقت الحالي
            hasValidPeriod = true;
          }
        }
        
        if (hasValidPeriod) {
          dates.add(day);
        }
      }
    }
    
    return dates;
  }

  void _showDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Center(child: Text(title, style: TextStyle(fontWeight: FontWeight.bold))),
            content: Text(message, textAlign: TextAlign.center),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text("موافق")),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!localeInitialized) {
      return Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final availableDates = getAvailableDates();
    final schedule = selectedDate != null ? widget.workingSchedule[intl.DateFormat('EEEE','ar',).format(selectedDate!).trim()] : null;
    
    // تحديد ما إذا كان اليوم المختار هو اليوم الحالي أم لا
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final isSelectedToday = selectedDate != null && intl.DateFormat('yyyy-MM-dd').format(selectedDate!) == intl.DateFormat('yyyy-MM-dd').format(today);
    
    // نعرض جميع الفترات الموجودة بغض النظر عن الوقت الحالي
    final hasMorning = schedule?['morning'] != null;
    final hasEvening = schedule?['evening'] != null;
    
    // إضافة رسائل تصحيح
    if (selectedDate != null) {
      print('DEBUG: selectedDate = ${intl.DateFormat('yyyy-MM-dd').format(selectedDate!)}');
      print('DEBUG: isSelectedToday = $isSelectedToday');
      print('DEBUG: schedule = $schedule');
      print('DEBUG: hasMorning = $hasMorning, hasEvening = $hasEvening');
      print('DEBUG: schedule?[\'morning\'] = ${schedule?['morning']}');
      print('DEBUG: schedule?[\'evening\'] = ${schedule?['evening']}');
      
      // إضافة تصحيح للفترة الصباحية
      if (schedule?['morning'] != null) {
        final morningValid = _isPeriodValid(schedule?['morning'] as Map<String, dynamic>?, 'morning');
        print('DEBUG: _isPeriodValid for morning = $morningValid');
      }
      
      // إضافة تصحيح للفترة المسائية
      if (schedule?['evening'] != null) {
        final eveningValid = _isPeriodValid(schedule?['evening'] as Map<String, dynamic>?, 'evening');
        print('DEBUG: _isPeriodValid for evening = $eveningValid');
      }
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: widget.showDoctorInfo 
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.name,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF2FBDAF),
                      fontSize: 20,
                    ),
                  ),
                  if (widget.doctorSpecialty != null || widget.centerName != null)
                    Text(
                      '${widget.doctorSpecialty ?? ''}${widget.doctorSpecialty != null && widget.centerName != null ? ' - ' : ''}${widget.centerName ?? ''}',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                ],
              )
            : Text(
                "اختيار الموعد",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF2FBDAF),
                  fontSize: 30,
                ),
              ),
        ),
        body: SafeArea(
          child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("اختر يوم من الأيام المتاحة:", style: TextStyle(fontSize: 18)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.info_outline, size: 16, color: Colors.grey),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'ملاحظة: الحجز متاح لليوم أو لليوم التالي فقط.',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
              if (availableDates.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(40),
                  margin: const EdgeInsets.symmetric(vertical: 20),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Column(
                    children: [
                                Icon(Icons.schedule, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                                Text('لا توجد أيام متاحة للحجز حالياً', style: TextStyle(fontSize: 18,fontWeight: FontWeight.bold,color: Colors.grey[600],), textAlign: TextAlign.center,),
                      const SizedBox(height: 20),
                                              ElevatedButton.icon(
                                  onPressed: () { Navigator.pop(context); },
                          icon: const Icon(Icons.arrow_back),
                          label: const Text('العودة لاختيار طبيب آخر'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2FBDAF),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        ),
                      ),
                    ],
                  ),
                )
              else
                ...availableDates.map((date) {
                            String formatted = intl.DateFormat('EEEE - yyyy/MM/dd', 'ar').format(date);
                            formatted = _toEnglishDigits(formatted);
                            final isSelected = selectedDate != null && intl.DateFormat('yyyy-MM-dd').format(selectedDate!) == intl.DateFormat('yyyy-MM-dd').format(date);
                            final isBookable = isDateBookable(date);
                            
                return Column(
                  children: [
                    GestureDetector(
                      onTap: () {
                        if (!isBookable) return;
                        
                        setState(() {
                          selectedDate = date;
                          // تحديد الفترة المناسبة بناءً على الوقت الحالي
                          selectedShift = _getAppropriateShift(date);
                        });
                        
                        _updateQueueInfo(date);
                      },
                      child: Container(
                        margin: EdgeInsets.symmetric(vertical: 4),
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                                      color: isSelected ? Colors.blue[100] : (isBookable ? Colors.grey[200] : Colors.grey[100]),
                          borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: isSelected ? Colors.blue : (isBookable ? Colors.transparent : Colors.grey[300]!), width: 2,),
                        ),
                        child: Row(
                          children: [
                            Icon(
                                          isBookable ? (isSelected ? Icons.check_circle : Icons.radio_button_unchecked) : Icons.block,
                                          color: isBookable ? (isSelected ? Colors.blue : Colors.grey) : Colors.grey,
                            ),
                            SizedBox(width: 10),
                                        Expanded(child: Text(formatted, style: TextStyle(fontSize: 16))),
                                        if (isSelected && isBookable && !_loadingQueue)
                                          Builder(builder: (_) {
                                            if (_isFull) {
                                              return Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                decoration: BoxDecoration(color: Colors.red[50], borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.red[200]!),),
                                                child: const Text('مكتمل', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600, fontSize: 12),),
                                              );
                                            }
                                            if (_queuePosition != null) {
                                              final capText = _dailyCapacity != null ? _toEnglishDigits(_dailyCapacity!.toString()) : '';
                                              final text = capText.isNotEmpty ? '${_toEnglishDigits(_queuePosition!.toString())} من $capText' : _toEnglishDigits(_queuePosition!.toString());
                                              return Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.blue[200]!),),
                                                child: Text(text, style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.w600, fontSize: 12),),
                                              );
                                            }
                                            return const SizedBox.shrink();
                                          }),
                          ],
                        ),
                      ),
                    ),
                                                        if (isSelected && isBookable)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Column(
                          children: [
                            // عرض رسالة الفترة المنتهية إذا وجدت
                            if (_getPeriodEndedMessage(date) != null)
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                margin: const EdgeInsets.only(bottom: 8),
                                decoration: BoxDecoration(
                                  color: Colors.orange[50],
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.orange[200]!),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.info_outline, color: Colors.orange[700], size: 20),
                                    SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        _getPeriodEndedMessage(date)!,
                                        style: TextStyle(
                                          color: Colors.orange[700],
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            // عرض اختيار الفترات إذا كان هناك فترتين
                            if (hasMorning && hasEvening) ...[
                              Builder(
                                builder: (context) {
                                  final now = DateTime.now();
                                  final today = DateTime(now.year, now.month, now.day);
                                  final isToday = intl.DateFormat('yyyy-MM-dd').format(date) == intl.DateFormat('yyyy-MM-dd').format(today);
                                  
                                  // نعرض جميع الفترات بغض النظر عن الوقت الحالي
                                  final showMorning = true;
                                  final showEvening = true;
                                  
                                  // إضافة رسائل تصحيح
                                  print('DEBUG: isToday = $isToday');
                                  print('DEBUG: hasMorning = $hasMorning, hasEvening = $hasEvening');
                                  print('DEBUG: showMorning = $showMorning, showEvening = $showEvening');
                                  print('DEBUG: schedule = $schedule');
                                  print('DEBUG: About to show choice chips');
                                  
                                  return Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      ChoiceChip(
                                        label: Text("الفترة الصباحية"),
                                        selected: selectedShift == 'morning',
                                        onSelected: (_) {
                                          setState(() => selectedShift = 'morning');
                                          if (selectedDate != null) { _updateQueueInfo(selectedDate!); }
                                        },
                                      ),
                                      SizedBox(width: 10),
                                      ChoiceChip(
                                        label: Text("الفترة المسائية"),
                                        selected: selectedShift == 'evening',
                                        onSelected: (_) {
                                          setState(() => selectedShift = 'evening');
                                          if (selectedDate != null) { _updateQueueInfo(selectedDate!); }
                                        },
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ],
                          ],
                        ),
                      ),
                  ],
                );
              }),
              if (availableDates.isNotEmpty) ...[
                SizedBox(height: 20),
                Center(
                  child: ElevatedButton(
                    onPressed: () {
                                if (selectedDate == null) {
                                  _showDialog("تنبيه","يرجى اختيار يوم أولاً",);
                                  return;
                                }
                                
                                // التحقق من الفترات المتاحة
                                if (selectedShift == null) {
                                  final appropriateShift = _getAppropriateShift(selectedDate!);
                                  if (appropriateShift != null) {
                                    selectedShift = appropriateShift;
                                  } else {
                                    _showDialog("تنبيه", "لا توجد فترة متاحة للحجز في هذا اليوم");
                                    return;
                                  }
                                }
                                
                                if (!isDateBookable(selectedDate!)) {
                                  _showDialog("تنبيه","هذا اليوم غير متاح للحجز، يرجى اختيار يوم آخر",);
                                  return;
                                }
                                if (_isFull) {
                                  _showDialog("تنبيه","العدد اكتمل لهذا اليوم/الفترة، لا يمكن الحجز",);
                        return;
                      }
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                                    builder: (_) => PatientInfoScreen(
                            facilityId: widget.facilityId,
                            specializationId: widget.specializationId,
                            doctorId: widget.doctorId,
                            selectedDate: selectedDate!,
                            selectedShift: selectedShift,
                            workingSchedule: widget.workingSchedule,
                                      isReschedule: widget.isReschedule,
                                      oldBookingData: widget.oldBookingData,
                          ),
                        ),
                      );
                    },
                    child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 24,vertical: 12,),
                                child: Text("متابعة لإدخال البيانات", style: TextStyle(fontSize: 18, color: Color(0xFF2FBDAF),),),
                      ),
                        ),
                      ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
