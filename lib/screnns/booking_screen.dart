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
  }

  List<DateTime> getAvailableDates() {
    final now = DateTime.now();
    final List<DateTime> dates = [];
    for (int i = 0; i < 14; i++) {
      final day = now.add(Duration(days: i));
      final name = intl.DateFormat('EEEE', 'ar').format(day).trim();
      final schedule = widget.workingSchedule[name];
      if (schedule != null &&
          (schedule['morning'] != null || schedule['evening'] != null)) {
        dates.add(day);
      }
    }
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
              }).toList(),
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
          ),
        ),
      ),
    );
  }
}
