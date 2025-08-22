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

  const BookingScreen({
    super.key,
    required this.name,
    required this.workingSchedule,
    required this.facilityId,
    required this.specializationId,
    required this.doctorId,
    this.isReschedule = false,
    this.oldBookingData,
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
    
    // التحقق من الفترة الصباحية
    final hasValidMorning = morning != null && morning.isNotEmpty && _isPeriodValid(morning, 'morning');
    // التحقق من الفترة المسائية
    final hasValidEvening = evening != null && evening.isNotEmpty && _isPeriodValid(evening, 'evening');
    
    return hasValidMorning || hasValidEvening;
  }

  Set<String> _computeBookableDateStrs() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final todayStr = intl.DateFormat('yyyy-MM-dd').format(today);
    final tomorrowStr = intl.DateFormat('yyyy-MM-dd').format(tomorrow);

    final Set<String> allowed = {};

    // التحقق من اليوم الحالي
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
    
    // التحقق من الغد (جميع الفترات متاحة)
    if (_hasScheduleOn(tomorrow) && !blockedDates.contains(tomorrowStr)) {
      allowed.add(tomorrowStr);
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
    // فحص البيانات الواردة
    print('اسم الطبيب: ${widget.name}');
    print('workingSchedule: ${widget.workingSchedule}');
    print('نوع workingSchedule: ${widget.workingSchedule.runtimeType}');
    print('عدد أيام الجدول: ${widget.workingSchedule.length}');
    print('هل الجدول فارغ: ${widget.workingSchedule.isEmpty}');
    // فحص إذا كان الحقل موجود في قاعدة البيانات
    if (widget.workingSchedule.isEmpty) {
      print('⚠️ تحذير: حقل workingSchedule غير موجود أو فارغ في قاعدة البيانات');
    }
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
        // مثال: إذا كان الوقت الحالي 1 ظهراً والفترة الصباحية تنتهي 12 ظهراً
        return currentHour < endHour;
      }
    } else if (periodType == 'evening') {
      final endTime = periodData['end'] as String?;
      final endHour = _parseTimeToHour(endTime);
      if (endHour != null) {
        // إذا انتهت الفترة المسائية، لا تظهر
        // مثال: إذا كان الوقت الحالي 9 مساءً والفترة المسائية تنتهي 8 مساءً
        return currentHour < endHour;
      }
    }
    
    // إذا لم نتمكن من تحديد الوقت، نعتبر الفترة صالحة
    return true;
  }

  // دالة لجلب الأيام المتاحة للحجز مع التحقق من الوقت الحالي
  // إذا انتهت الفترة الصباحية أو المسائية، لن تظهر في القائمة
  // إذا كان اليوم فيه فترة واحدة فقط وانتهت، لن يظهر اليوم في القائمة
  List<DateTime> getAvailableDates() {
    final now = DateTime.now();
    final List<DateTime> dates = [];
    if (widget.workingSchedule.isEmpty) {
      print('workingSchedule فارغ أو غير محدد أو غير موجود في قاعدة البيانات');
      return dates;
    }
    print('workingSchedule: ${widget.workingSchedule}');
    print('عدد أيام الجدول: ${widget.workingSchedule.length}');
    final allowed = _computeBookableDateStrs();
    
    for (int i = 0; i < 14; i++) {
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
          if (i == 0) { // اليوم الحالي
            if (_isPeriodValid(morning, 'morning')) {
              hasValidPeriod = true;
            }
          } else { // أيام أخرى (جميع الفترات متاحة)
            hasValidPeriod = true;
          }
        }
        
        // التحقق من الفترة المسائية
        if (evening != null && evening.isNotEmpty) {
          if (i == 0) { // اليوم الحالي
            if (_isPeriodValid(evening, 'evening')) {
              hasValidPeriod = true;
            }
          } else { // أيام أخرى (جميع الفترات متاحة)
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
    final hasMorning = schedule?['morning'] != null && _isPeriodValid(schedule?['morning'] as Map<String, dynamic>?, 'morning');
    final hasEvening = schedule?['evening'] != null && _isPeriodValid(schedule?['evening'] as Map<String, dynamic>?, 'evening');

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            "اختيار الموعد",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: const Color.fromARGB(255, 78, 17, 175),
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
                          backgroundColor: const Color.fromARGB(255, 78, 17, 175),
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
                            final allowed = _computeBookableDateStrs();
                            final dayStr = intl.DateFormat('yyyy-MM-dd').format(date);
                            final isBookable = allowed.contains(dayStr);
                return Column(
                  children: [
                    GestureDetector(
                      onTap: () {
                                    if (!isBookable) return;
                                    final dayName = intl.DateFormat('EEEE', 'ar').format(date).trim();
                        final schedule = widget.workingSchedule[dayName];
                        final hasMorning = schedule['morning'] != null;
                        final hasEvening = schedule['evening'] != null;
                        setState(() {
                          selectedDate = date;
                          if (hasMorning && !hasEvening) {
                            selectedShift = 'morning';
                          } else if (!hasMorning && hasEvening) {
                            selectedShift = 'evening';
                                      } else if (hasMorning && hasEvening) {
                                        // إذا كان اليوم فيه فترتين، نحدد الفترة بناءً على الوقت الحالي
                                        final now = DateTime.now();
                                        final currentHour = now.hour;
                                        
                                        // تحديد أوقات الفترات من جدول الطبيب
                                        final morningSchedule = schedule['morning'] as Map<String, dynamic>?;
                                        final eveningSchedule = schedule['evening'] as Map<String, dynamic>?;
                                        
                                        // التحقق من صلاحية الفترات بناءً على الوقت الحالي
                                        final isMorningValid = _isPeriodValid(morningSchedule, 'morning');
                                        final isEveningValid = _isPeriodValid(eveningSchedule, 'evening');
                                        
                                        if (isMorningValid && isEveningValid) {
                                          // إذا كانت الفترتان صالحتان، نختار بناءً على الوقت
                                          String? morningEndTime;
                                          String? eveningStartTime;
                                          
                                          if (morningSchedule != null) {
                                            morningEndTime = morningSchedule['end'] as String?;
                                          }
                                          if (eveningSchedule != null) {
                                            eveningStartTime = eveningSchedule['start'] as String?;
                                          }
                                          
                                          // تحويل الأوقات إلى ساعات
                                          int? morningEndHour = _parseTimeToHour(morningEndTime);
                                          int? eveningStartHour = _parseTimeToHour(eveningStartTime);
                                          
                                          // تحديد الفترة المناسبة بناءً على الوقت الحالي
                                          if (morningEndHour != null && eveningStartHour != null) {
                                            // إذا كان لدينا أوقات محددة للفترتين
                                            if (currentHour < morningEndHour) {
                                              // إذا لم تنتهي الفترة الصباحية بعد
                                              selectedShift = 'morning';
                                            } else if (currentHour >= eveningStartHour) {
                                              // إذا بدأت الفترة المسائية أو تجاوزتها
                                              selectedShift = 'evening';
                                            } else {
                                              // إذا كان الوقت بين الفترتين، نختار المسائية تلقائياً
                                              selectedShift = 'evening';
                                            }
                                          } else if (morningEndHour != null) {
                                            // إذا كان لدينا فقط وقت انتهاء الفترة الصباحية
                                            if (currentHour < morningEndHour) {
                                              selectedShift = 'morning';
                                            } else {
                                              selectedShift = 'evening';
                                            }
                                          } else if (eveningStartHour != null) {
                                            // إذا كان لدينا فقط وقت بداية الفترة المسائية
                                            if (currentHour >= eveningStartHour) {
                                              selectedShift = 'evening';
                                            } else {
                                              selectedShift = 'morning';
                                            }
                                          } else {
                                            // إذا لم نتمكن من تحديد الأوقات، نختار المسائية افتراضياً
                                            selectedShift = 'evening';
                                          }
                                        } else if (isMorningValid) {
                                          // إذا كانت الفترة الصباحية فقط صالحة
                                          selectedShift = 'morning';
                                        } else if (isEveningValid) {
                                          // إذا كانت الفترة المسائية فقط صالحة
                                          selectedShift = 'evening';
                                        } else if (hasMorning && hasEvening) {
                                          // إذا كانت الفترتان موجودتان، نختار بناءً على الوقت الحالي
                                          final isMorningValid = _isPeriodValid(schedule['morning'] as Map<String, dynamic>?, 'morning');
                                          final isEveningValid = _isPeriodValid(schedule['evening'] as Map<String, dynamic>?, 'evening');
                                          
                                          if (isMorningValid && isEveningValid) {
                                            // إذا كانت الفترتان صالحتان، نختار الصباحية افتراضياً
                                            selectedShift = 'morning';
                                          } else if (isMorningValid) {
                                            selectedShift = 'morning';
                                          } else if (isEveningValid) {
                                            selectedShift = 'evening';
                                          } else {
                                            selectedShift = null;
                                          }
                                        } else {
                                          // إذا لم تكن أي فترة صالحة، لا نحدد فترة
                                          selectedShift = null;
                                        }
                          } else {
                            selectedShift = null;
                          }
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
                                                        if (isSelected && isBookable && hasMorning && hasEvening)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                                if (_isPeriodValid(schedule?['morning'] as Map<String, dynamic>?, 'morning'))
                            ChoiceChip(
                              label: Text("الفترة الصباحية"),
                              selected: selectedShift == 'morning',
                                    onSelected: (_) {
                                      setState(() => selectedShift = 'morning');
                                      if (selectedDate != null) { _updateQueueInfo(selectedDate!); }
                                    },
                                  ),
                                                                if (_isPeriodValid(schedule?['morning'] as Map<String, dynamic>?, 'morning') && 
                                    _isPeriodValid(schedule?['evening'] as Map<String, dynamic>?, 'evening'))
                                  SizedBox(width: 10),
                                if (_isPeriodValid(schedule?['evening'] as Map<String, dynamic>?, 'evening'))
                            ChoiceChip(
                              label: Text("الفترة المسائية"),
                              selected: selectedShift == 'evening',
                                    onSelected: (_) {
                                      setState(() => selectedShift = 'evening');
                                      if (selectedDate != null) { _updateQueueInfo(selectedDate!); }
                                    },
                            ),
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
                                if (selectedDate == null || (schedule?['morning'] != null && schedule?['evening'] != null && selectedShift == null)) {
                                  _showDialog("تنبيه","يرجى اختيار يوم وفترة (صباحية/مسائية) أولاً",);
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
                                child: Text("متابعة لإدخال البيانات", style: TextStyle(fontSize: 18, color: Color.fromARGB(255, 78, 17, 175),),),
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
