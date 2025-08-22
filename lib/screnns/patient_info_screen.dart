import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;
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
  bool? isBookingForSelf; // null = لم يتم الاختيار بعد، true = لنفسه، false = لشخص آخر
  bool showBookingChoice = true; // عرض خيار الحجز لنفسه أم لشخص آخر


  @override
  void initState() {
    super.initState();
    
    // إذا كان هذا تأجيل حجز، استخدم البيانات القديمة
    if (widget.isReschedule && widget.oldBookingData != null) {
      patientName = widget.oldBookingData!['patientName'];
      patientPhone = widget.oldBookingData!['patientPhone'];
      isBookingForSelf = false; // تأجيل الحجز يعتبر لشخص آخر
      showBookingChoice = false; // لا نحتاج لخيار الحجز في التأجيل
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
    if (isBookingForSelf == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى اختيار نوع الحجز أولاً قبل إدخال البيانات'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    
    if (patientName == null ||
        patientName!.isEmpty ||
        patientPhone == null ||
        patientPhone!.isEmpty) {
      _showDialog("تنبيه", "يرجى إدخال الاسم ورقم الهاتف");
      return;
    }

    // التحقق من الاسم الرباعي
    List<String> nameParts = patientName!.trim().split(' ').where((part) => part.isNotEmpty).toList();
    if (nameParts.length != 4) {
      _showDialog("تنبيه", "يرجى إدخال الاسم الرباعي (4 أسماء)");
      return;
    }
    
    // التحقق من رقم الهاتف (10 أرقام)
    String phoneDigits = patientPhone!.replaceAll(RegExp(r'[^0-9]'), '');
    if (phoneDigits.length != 10) {
      _showDialog("تنبيه", "رقم الهاتف يجب أن يكون 10 أرقام");
      return;
    }

    // التحقق من عدم وجود حجز سابق لنفس الشخص في نفس اليوم
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
        .where('patientPhone', isEqualTo: patientPhone)
        .get();

    if (existingBooking.docs.isNotEmpty) {
      _showDialog("حجز موجود", "لديك حجز سابق في نفس اليوم لهذا الطبيب. لا يمكن الحجز مرة اخرى");
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
          'patientPhone': patientPhone,
          'patientId': patientId, // Save patient ID instead of phone

          'date': dateStr,
          'time': availableTime,
          'period': period,
          'createdAt': FieldValue.serverTimestamp(),
          'isConfirmed': false, // الحجز الجديد يحتاج تأكيد
        });

    if (!mounted) return;

    setState(() {
      isLoading = false;
      selectedTime = availableTime;
    });

    final actionText = widget.isReschedule ? "تم تأجيل الحجز" : "تم الحجز";
    
    // مسح البيانات بعد تأكيد الحجز
    setState(() {
      patientName = null;
      patientPhone = null;
      isBookingForSelf = null;
      showBookingChoice = true;
    });

    _showDialog(
      actionText,
      "تم تأكيد $actionText بتاريخ $dateStr الساعة $availableTime (${period == 'morning' ? 'صباحاً' : 'مساءً'})",
    );
  }

  void _selectBookingType(bool forSelf) async {
    if (!mounted) return;
    
    setState(() {
      isBookingForSelf = forSelf;
      showBookingChoice = false;
    });

    if (forSelf) {
      // جلب بيانات المريض من SharedPreferences
      await loadPatientData();
    } else {
      // إذا اختار لشخص آخر، اعرض رسالة
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
              color: const Color.fromARGB(255, 78, 17, 175),
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
                        // خيار نوع الحجز
                        if (showBookingChoice) ...[
                          const Text(
                            'اختر نوع الحجز:',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color.fromARGB(255, 78, 17, 175),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () => _selectBookingType(true),
                                  icon: const Icon(Icons.person),
                                  label: const Text('لنفسي'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: isBookingForSelf == true 
                                        ? const Color.fromARGB(255, 78, 17, 175)
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
                                  icon: const Icon(Icons.person_add),
                                  label: const Text('لشخص آخر'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: isBookingForSelf == false 
                                        ? const Color.fromARGB(255, 78, 17, 175)
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
                        ] else ...[
                          // عرض نوع الحجز المختار
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color.fromARGB(255, 78, 17, 175).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: const Color.fromARGB(255, 78, 17, 175).withOpacity(0.3),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  isBookingForSelf == true ? Icons.person : Icons.person_add,
                                  color: const Color.fromARGB(255, 78, 17, 175),
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  isBookingForSelf == true 
                                      ? 'الحجز لنفسك'
                                      : 'الحجز لشخص آخر',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Color.fromARGB(255, 78, 17, 175),
                                  ),
                                ),
                                const Spacer(),
                                TextButton(
                                  onPressed: () {
                                    if (!mounted) return;
                                    setState(() {
                                      showBookingChoice = true;
                                      isBookingForSelf = null;
                                      patientName = null;
                                      patientPhone = null;
                                    });
                                  },
                                  child: const Text(
                                    'تغيير',
                                    style: TextStyle(
                                      color: Color.fromARGB(255, 78, 17, 175),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                        

                        
                        // حقل الاسم الرباعي
                        TextFormField(
                          decoration: InputDecoration(
                            labelText: 'الاسم الرباعي *',
                            hintText: 'الاسم الأول - اسم الأب - اسم الجد - اسم العائلة',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.person),
                          ),
                          onTap: () {
                            if (isBookingForSelf == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('يرجى اختيار نوع الحجز أولاً قبل إدخال البيانات'),
                                  backgroundColor: Colors.red,
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            }
                          },
                          onChanged: (val) => patientName = val,
                          textDirection: TextDirection.rtl,
                          controller: patientName != null ? TextEditingController(text: patientName) : null,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'يرجى إدخال الاسم الرباعي';
                            }
                            
                            List<String> nameParts = value.trim().split(' ').where((part) => part.isNotEmpty).toList();
                            
                            if (nameParts.length != 4) {
                              return 'يرجى إدخال الاسم الرباعي (4 أسماء)';
                            }
                            
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        
                        // حقل رقم الهاتف
                        TextFormField(
                          decoration: InputDecoration(
                            labelText: 'رقم الهاتف *',
                            hintText: '01XXXXXXXX أو 09XXXXXXXX',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.phone),
                          ),
                          onTap: () {
                            if (isBookingForSelf == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('يرجى اختيار نوع الحجز أولاً قبل إدخال البيانات'),
                                  backgroundColor: Colors.red,
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            }
                          },
                          onChanged: (val) => patientPhone = val,
                          keyboardType: TextInputType.phone,
                          textDirection: TextDirection.rtl,
                          controller: patientPhone != null ? TextEditingController(text: patientPhone) : null,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'يرجى إدخال رقم الهاتف';
                            }
                            
                            String phoneDigits = value.replaceAll(RegExp(r'[^0-9]'), '');
                            if (phoneDigits.length != 10) {
                              return 'رقم الهاتف يجب أن يكون 10 أرقام';
                            }
                            
                            return null;
                          },
                        ),
                        const SizedBox(height: 30),
                      ElevatedButton(
                        onPressed: confirmBooking,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color.fromARGB(255, 78, 17, 175),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          widget.isReschedule ? "تأكيد التأجيل" : "تأكيد الحجز",
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (selectedTime != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 16.0),
                          child: Text(
                            "✅ تم تأكيد الحجز الساعة $selectedTime (${widget.selectedShift == 'morning' ? 'صباحاً' : 'مساءً'})",
                              style: const TextStyle(fontSize: 18, color: Colors.green),
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
