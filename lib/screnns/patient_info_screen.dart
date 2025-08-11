import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;

class PatientInfoScreen extends StatefulWidget {
  final String facilityId;
  final String specializationId;
  final String doctorId;
  final DateTime selectedDate;
  final String? selectedShift;
  final Map<String, dynamic> workingSchedule;

  const PatientInfoScreen({
    super.key,
    required this.facilityId,
    required this.specializationId,
    required this.doctorId,
    required this.selectedDate,
    required this.selectedShift,
    required this.workingSchedule,
  });

  @override
  State<PatientInfoScreen> createState() => _PatientInfoScreenState();
}

class _PatientInfoScreenState extends State<PatientInfoScreen> {
  String? patientName;
  String? patientPhone;
  bool isLoading = false;
  String? selectedTime;

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

    int startHour = int.parse(shiftData['start'].split(":")[0]);
    int endHour = int.parse(shiftData['end'].split(":")[0]);

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
    if (patientName == null ||
        patientName!.isEmpty ||
        patientPhone == null ||
        patientPhone!.isEmpty) {
      _showDialog("تنبيه", "يرجى إدخال الاسم ورقم الهاتف");
      return;
    }

    setState(() => isLoading = true);

    final result = await getAvailableTime(widget.selectedDate);
    if (result == null) {
      setState(() => isLoading = false);
      _showDialog("لا يوجد موعد", "لا توجد مواعيد متاحة في هذا اليوم");
      return;
    }

    final availableTime = result['time']!;
    final period = result['period']!;
    final dateStr = intl.DateFormat('yyyy-MM-dd').format(widget.selectedDate);

    await FirebaseFirestore.instance
        .collection('medicalFacilities')
        .doc(widget.facilityId)
        .collection('specializations')
        .doc(widget.specializationId)
        .collection('doctors')
        .doc(widget.doctorId)
        .collection('appointments')
        .add({
          'patientName': patientName,
          'patiantPhone': patientPhone,
          'date': dateStr,
          'time': availableTime,
          'period': period,
          'createdAt': FieldValue.serverTimestamp(),
        });

    setState(() {
      isLoading = false;
      selectedTime = availableTime;
    });

    _showDialog(
      "تم الحجز",
      "تم تأكيد الحجز بتاريخ $dateStr الساعة $availableTime (${period == 'morning' ? 'صباحاً' : 'مساءً'})",
    );
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
            "معلومات المريض",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: const Color.fromARGB(255, 78, 17, 175),
              fontSize: 30,
            ),
          ),
        ),
        body:
            isLoading
                ? Center(child: CircularProgressIndicator())
                : Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    children: [
                      _buildFormField("اسم المريض", (val) => patientName = val),
                      SizedBox(height: 16),
                      _buildFormField(
                        "رقم الهاتف",
                        (val) => patientPhone = val,
                        keyboard: TextInputType.phone,
                      ),
                      SizedBox(height: 30),
                      ElevatedButton(
                        onPressed: confirmBooking,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                          child: Text(
                            "تأكيد الحجز",
                            style: TextStyle(
                              fontSize: 18,
                              color: Color.fromARGB(255, 78, 17, 175),
                            ),
                          ),
                        ),
                      ),
                      if (selectedTime != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 16.0),
                          child: Text(
                            "✅ تم تأكيد الحجز الساعة $selectedTime (${widget.selectedShift == 'morning' ? 'صباحاً' : 'مساءً'})",
                            style: TextStyle(fontSize: 18, color: Colors.green),
                          ),
                        ),
                    ],
                  ),
                ),
      ),
    );
  }

  Widget _buildFormField(
    String label,
    Function(String) onChanged, {
    TextInputType keyboard = TextInputType.text,
  }) {
    return TextFormField(
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(),
      ),
      onChanged: onChanged,
      keyboardType: keyboard,
      textDirection: TextDirection.rtl,
    );
  }
}
