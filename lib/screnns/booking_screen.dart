import 'package:flutter/material.dart';
import 'package:hospital_app/screnns/patient_info_screen.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart' as intl;

class BookingScreen extends StatefulWidget {
  final String name;
  final Map<String, dynamic> workingSchedule;
  final String facilityId;
  final String specializationId;
  final String doctorId;

  const BookingScreen({
    super.key,
    required this.name,
    required this.workingSchedule,
    required this.facilityId,
    required this.specializationId,
    required this.doctorId,
  });

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  DateTime? selectedDate;
  String? selectedShift;
  bool localeInitialized = false;

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
  }

  List<DateTime> getAvailableDates() {
    final now = DateTime.now();
    final List<DateTime> dates = [];
    
    // فحص إذا كان workingSchedule فارغ أو null أو غير موجود
    if (widget.workingSchedule.isEmpty) {
      print('workingSchedule فارغ أو غير محدد أو غير موجود في قاعدة البيانات');
      return dates;
    }
    
    print('workingSchedule: ${widget.workingSchedule}');
    print('عدد أيام الجدول: ${widget.workingSchedule.length}');
    
    // أيام الأسبوع بالعربية
    final arabicDays = [
      'الأحد', 'الاثنين', 'الثلاثاء', 'الأربعاء', 
      'الخميس', 'الجمعة', 'السبت'
    ];
    
    for (int i = 0; i < 14; i++) {
      final day = now.add(Duration(days: i));
      final name = intl.DateFormat('EEEE', 'ar').format(day).trim();
      final schedule = widget.workingSchedule[name];
      
      print('اليوم: $name, الجدول: $schedule');
      
      if (schedule != null && schedule is Map<String, dynamic>) {
        final morning = schedule['morning'];
        final evening = schedule['evening'];
        
        if ((morning != null && morning is Map && morning.isNotEmpty) ||
            (evening != null && evening is Map && evening.isNotEmpty)) {
          dates.add(day);
          print('تم إضافة اليوم: $name (صباح: $morning, مساء: $evening)');
        }
      }
    }
    
    print('إجمالي الأيام المتاحة: ${dates.length}');
    return dates;
  }

  void _showDialog(String title, String message) {
    showDialog(
      context: context,
      builder:
          (_) => AlertDialog(
            title: Center(
              child: Text(title, style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            content: Text(message, textAlign: TextAlign.center),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text("موافق"),
              ),
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
    final schedule =
        selectedDate != null
            ? widget.workingSchedule[intl.DateFormat(
              'EEEE',
              'ar',
            ).format(selectedDate!).trim()]
            : null;

    final hasMorning = schedule?['morning'] != null;
    final hasEvening = schedule?['evening'] != null;

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
        body: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "اختر يوم من الأيام المتاحة:",
                style: TextStyle(fontSize: 18),
              ),
              SizedBox(height: 10),
              
              // التحقق من وجود أيام متاحة
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
                      Icon(
                        Icons.schedule,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'لا توجد أيام متاحة للحجز حالياً',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[600],
                        ),
                        textAlign: TextAlign.center,
                                              ),
                        
                      const SizedBox(height: 20),
                                              ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                          },
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
                final formatted = intl.DateFormat(
                  'EEEE - yyyy/MM/dd',
                  'ar',
                ).format(date);
                final isSelected =
                    selectedDate != null &&
                    intl.DateFormat('yyyy-MM-dd').format(selectedDate!) ==
                        intl.DateFormat('yyyy-MM-dd').format(date);
                return Column(
                  children: [
                    GestureDetector(
                      onTap: () {
                        final dayName =
                            intl.DateFormat('EEEE', 'ar').format(date).trim();
                        final schedule = widget.workingSchedule[dayName];
                        final hasMorning = schedule['morning'] != null;
                        final hasEvening = schedule['evening'] != null;
                        setState(() {
                          selectedDate = date;
                          if (hasMorning && !hasEvening) {
                            selectedShift = 'morning';
                          } else if (!hasMorning && hasEvening) {
                            selectedShift = 'evening';
                          } else {
                            selectedShift = null;
                          }
                        });
                      },
                      child: Container(
                        margin: EdgeInsets.symmetric(vertical: 4),
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color:
                              isSelected ? Colors.blue[100] : Colors.grey[200],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color:
                                isSelected ? Colors.blue : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isSelected
                                  ? Icons.check_circle
                                  : Icons.radio_button_unchecked,
                              color: isSelected ? Colors.blue : Colors.grey,
                            ),
                            SizedBox(width: 10),
                            Text(formatted, style: TextStyle(fontSize: 16)),
                          ],
                        ),
                      ),
                    ),
                    if (isSelected && hasMorning && hasEvening)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            ChoiceChip(
                              label: Text("الفترة الصباحية"),
                              selected: selectedShift == 'morning',
                              onSelected:
                                  (_) =>
                                      setState(() => selectedShift = 'morning'),
                            ),
                            SizedBox(width: 10),
                            ChoiceChip(
                              label: Text("الفترة المسائية"),
                              selected: selectedShift == 'evening',
                              onSelected:
                                  (_) =>
                                      setState(() => selectedShift = 'evening'),
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
                      if (selectedDate == null ||
                          (schedule?['morning'] != null &&
                              schedule?['evening'] != null &&
                              selectedShift == null)) {
                        _showDialog(
                          "تنبيه",
                          "يرجى اختيار يوم وفترة (صباحية/مسائية) أولاً",
                        );
                        return;
                      }
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder:
                              (_) => PatientInfoScreen(
                            facilityId: widget.facilityId,
                            specializationId: widget.specializationId,
                            doctorId: widget.doctorId,
                            selectedDate: selectedDate!,
                            selectedShift: selectedShift,
                            workingSchedule: widget.workingSchedule,
                          ),
                        ),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      child: Text(
                        "متابعة لإدخال البيانات",
                        style: TextStyle(
                          fontSize: 18,
                          color: Color.fromARGB(255, 78, 17, 175),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
