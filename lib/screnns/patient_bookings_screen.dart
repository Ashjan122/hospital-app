import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart' as intl;
import 'package:hospital_app/screnns/booking_screen.dart';
import 'package:hospital_app/widgets/optimized_loading_widget.dart';
import 'package:hospital_app/services/syncfusion_pdf_service.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io';
import 'dart:typed_data';

class PatientBookingsScreen extends StatefulWidget {
  const PatientBookingsScreen({super.key});

  @override
  State<PatientBookingsScreen> createState() => _PatientBookingsScreenState();
}

class _PatientBookingsScreenState extends State<PatientBookingsScreen> {
  String? patientEmail;
  String? patientId;
  List<Map<String, dynamic>> _bookings = [];
  bool _isLoading = true;
  String _selectedFilter = 'all'; // all, today, upcoming, past
  Set<String> _cancellingBookings = {}; // لتتبع الحجوزات التي يتم إلغاؤها

  @override
  void initState() {
    super.initState();
    _loadPatientData();
  }

  Future<void> _loadPatientData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      patientEmail = prefs.getString('userEmail');
      patientId = prefs.getString('userId');
    });
    // تحميل البيانات فوراً بعد الحصول على معرف المريض
    if (patientId != null) {
      await _fetchBookings();
    }
  }

  Future<void> _fetchBookings() async {
    if (patientId == null) {
      setState(() {
        _isLoading = false;
      });
      return;
    }

    try {
      setState(() {
        _isLoading = true;
      });

      // استخدام استعلام محسن للحصول على الحجوزات بشكل أسرع
      // البحث في المرافق المتاحة فقط
      final facilitiesSnapshot = await FirebaseFirestore.instance
          .collection('medicalFacilities')
          .where('available', isEqualTo: true) // فقط المرافق المتاحة
          .limit(10) // تحديد عدد المرافق للبحث
          .get()
          .timeout(const Duration(seconds: 5));

      List<Map<String, dynamic>> allBookings = [];
      List<Future<void>> futures = [];

      for (var facilityDoc in facilitiesSnapshot.docs) {
        futures.add(_fetchBookingsFromFacility(facilityDoc, allBookings));
      }

      // انتظار جميع العمليات في نفس الوقت
      await Future.wait(futures);

      // ترتيب الحجوزات حسب التاريخ (الأحدث أولاً)
      allBookings.sort((a, b) {
        final dateA = DateTime.tryParse(a['date'] ?? '');
        final dateB = DateTime.tryParse(b['date'] ?? '');
        if (dateA == null && dateB == null) return 0;
        if (dateA == null) return 1;
        if (dateB == null) return -1;
        return dateB.compareTo(dateA);
      });

      setState(() {
        _bookings = allBookings;
        _isLoading = false;
      });
    } catch (e) {
      print('خطأ في تحميل الحجوزات: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchBookingsFromFacility(QueryDocumentSnapshot facilityDoc, List<Map<String, dynamic>> allBookings) async {
    try {
      final specializationsSnapshot = await FirebaseFirestore.instance
          .collection('medicalFacilities')
          .doc(facilityDoc.id)
          .collection('specializations')
          .where('isActive', isEqualTo: true) // فقط التخصصات النشطة
          .get()
          .timeout(const Duration(seconds: 3));

      List<Future<void>> specFutures = [];

      for (var specDoc in specializationsSnapshot.docs) {
        specFutures.add(_fetchBookingsFromSpecialization(facilityDoc, specDoc, allBookings));
      }

      await Future.wait(specFutures);
    } catch (e) {
      print('خطأ في تحميل الحجوزات من المرفق ${facilityDoc.id}: $e');
    }
  }

  Future<void> _fetchBookingsFromSpecialization(
    QueryDocumentSnapshot facilityDoc, 
    QueryDocumentSnapshot specDoc, 
    List<Map<String, dynamic>> allBookings
  ) async {
    try {
      final doctorsSnapshot = await FirebaseFirestore.instance
          .collection('medicalFacilities')
          .doc(facilityDoc.id)
          .collection('specializations')
          .doc(specDoc.id)
          .collection('doctors')
          .where('isActive', isEqualTo: true) // فقط الأطباء النشطين
          .get()
          .timeout(const Duration(seconds: 3));

      List<Future<void>> doctorFutures = [];

      for (var doctorDoc in doctorsSnapshot.docs) {
        doctorFutures.add(_fetchBookingsFromDoctor(facilityDoc, specDoc, doctorDoc, allBookings));
      }

      await Future.wait(doctorFutures);
    } catch (e) {
      print('خطأ في تحميل الحجوزات من التخصص ${specDoc.id}: $e');
    }
  }

  Future<void> _fetchBookingsFromDoctor(
    QueryDocumentSnapshot facilityDoc,
    QueryDocumentSnapshot specDoc,
    QueryDocumentSnapshot doctorDoc,
    List<Map<String, dynamic>> allBookings
  ) async {
    try {
      final appointmentsSnapshot = await FirebaseFirestore.instance
          .collection('medicalFacilities')
          .doc(facilityDoc.id)
          .collection('specializations')
          .doc(specDoc.id)
          .collection('doctors')
          .doc(doctorDoc.id)
          .collection('appointments')
          .where('patientId', isEqualTo: patientId)
          .get()
          .timeout(const Duration(seconds: 3));

      for (var appointmentDoc in appointmentsSnapshot.docs) {
        final appointmentData = appointmentDoc.data();
        final facilityData = facilityDoc.data() as Map<String, dynamic>?;
        final specData = specDoc.data() as Map<String, dynamic>?;
        final doctorData = doctorDoc.data() as Map<String, dynamic>?;
        
        allBookings.add({
          ...appointmentData,
          'id': appointmentDoc.id,
          'facilityId': facilityDoc.id,
          'facilityName': facilityData?['name'] ?? 'غير محدد',
          'specializationId': specDoc.id,
          'specializationName': specData?['specName'] ?? 'غير محدد',
          'doctorId': doctorDoc.id,
          'doctorName': doctorData?['docName'] ?? 'غير محدد',
        });
      }
    } catch (e) {
      print('خطأ في تحميل الحجوزات من الطبيب ${doctorDoc.id}: $e');
    }
  }

  List<Map<String, dynamic>> getFilteredBookings() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    switch (_selectedFilter) {
      case 'today':
        return _bookings.where((booking) {
          final bookingDate = DateTime.tryParse(booking['date'] ?? '');
          if (bookingDate == null) return false;
          final bookingDay = DateTime(bookingDate.year, bookingDate.month, bookingDate.day);
          return bookingDay.isAtSameMomentAs(today);
        }).toList();
      
      case 'upcoming':
        return _bookings.where((booking) {
          final bookingDate = DateTime.tryParse(booking['date'] ?? '');
          if (bookingDate == null) return false;
          final bookingDay = DateTime(bookingDate.year, bookingDate.month, bookingDate.day);
          return bookingDay.isAfter(today);
        }).toList();
      
      case 'past':
        return _bookings.where((booking) {
          final bookingDate = DateTime.tryParse(booking['date'] ?? '');
          if (bookingDate == null) return false;
          final bookingDay = DateTime(bookingDate.year, bookingDate.month, bookingDate.day);
          return bookingDay.isBefore(today);
        }).toList();
      
      default:
        return _bookings;
    }
  }

  String _getStatusText(Map<String, dynamic> booking) {
    // Check if booking is confirmed
    final isConfirmed = booking['isConfirmed'] ?? false;
    
    if (!isConfirmed) {
      return 'في انتظار التأكيد';
    }
    
    final bookingDate = DateTime.tryParse(booking['date'] ?? '');
    if (bookingDate == null) return 'غير محدد';
    
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final bookingDay = DateTime(bookingDate.year, bookingDate.month, bookingDate.day);
    
    if (bookingDay.isBefore(today)) {
      return 'منتهي';
    } else if (bookingDay.isAtSameMomentAs(today)) {
      return 'اليوم';
    } else {
      return 'قادم';
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'في انتظار التأكيد':
        return Colors.orange;
      case 'منتهي':
        return Colors.grey;
      case 'اليوم':
        return const Color(0xFF2FBDAF);
      case 'قادم':
        return const Color(0xFF2FBDAF);
      default:
        return Colors.grey;
    }
  }

  Future<void> _cancelBooking(Map<String, dynamic> booking) async {
    final bookingId = booking['id'] as String;
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأكيد الإلغاء'),
        content: const Text('هل أنت متأكد من إلغاء هذا الحجز؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('تأكيد الإلغاء'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      // إضافة loading محلي للحجز المحدد
      setState(() {
        _cancellingBookings.add(bookingId);
      });

      try {
        await FirebaseFirestore.instance
            .collection('medicalFacilities')
            .doc(booking['facilityId'])
            .collection('specializations')
            .doc(booking['specializationId'])
            .collection('doctors')
            .doc(booking['doctorId'])
            .collection('appointments')
            .doc(bookingId)
            .delete()
            .timeout(const Duration(seconds: 5));

        // إزالة الحجز من القائمة المحلية بدلاً من إعادة تحميل جميع الحجوزات
        setState(() {
          _bookings.removeWhere((b) => b['id'] == bookingId);
          _cancellingBookings.remove(bookingId);
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم إلغاء الحجز بنجاح'),
            backgroundColor: Color(0xFF2FBDAF),
          ),
        );
      } catch (e) {
        setState(() {
          _cancellingBookings.remove(bookingId);
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في إلغاء الحجز: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _rescheduleBooking(Map<String, dynamic> booking) async {
    try {
      // جلب جدول عمل الطبيب
      final doctorDoc = await FirebaseFirestore.instance
          .collection('medicalFacilities')
          .doc(booking['facilityId'])
          .collection('specializations')
          .doc(booking['specializationId'])
          .collection('doctors')
          .doc(booking['doctorId'])
          .get();

      if (!doctorDoc.exists) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('لم يتم العثور على بيانات الطبيب'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final doctorData = doctorDoc.data()!;
      final workingSchedule = doctorData['workingSchedule'] as Map<String, dynamic>? ?? {};

      if (workingSchedule.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('لا توجد أيام متاحة للطبيب حالياً'),
            backgroundColor: Color(0xFF2FBDAF),
          ),
        );
        return;
      }

      // الانتقال إلى صفحة الأيام المتاحة مع البيانات القديمة
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => BookingScreen(
            name: booking['doctorName'] ?? 'طبيب',
            workingSchedule: workingSchedule,
            facilityId: booking['facilityId'],
            specializationId: booking['specializationId'],
            doctorId: booking['doctorId'],
            isReschedule: true, // إشارة أن هذا تأجيل حجز
            oldBookingData: booking, // البيانات القديمة
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطأ في جلب بيانات الطبيب: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredBookings = getFilteredBookings();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            "حجوزاتي",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: const Color(0xFF2FBDAF),
              fontSize: 30,
            ),
          ),
        ),
        body: SafeArea(
          child: Column(
            children: [
              // Filter chips
              Container(
                padding: const EdgeInsets.all(16),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      FilterChip(
                        label: Text('الكل'),
                        selected: _selectedFilter == 'all',
                        onSelected: (selected) {
                          setState(() {
                            _selectedFilter = 'all';
                          });
                        },
                      ),
                      const SizedBox(width: 8),
                      FilterChip(
                        label: Text('اليوم'),
                        selected: _selectedFilter == 'today',
                        onSelected: (selected) {
                          setState(() {
                            _selectedFilter = 'today';
                          });
                        },
                      ),
                      const SizedBox(width: 8),
                      FilterChip(
                        label: Text('القادمة'),
                        selected: _selectedFilter == 'upcoming',
                        onSelected: (selected) {
                          setState(() {
                            _selectedFilter = 'upcoming';
                          });
                        },
                      ),
                      const SizedBox(width: 8),
                      FilterChip(
                        label: Text('المنتهية'),
                        selected: _selectedFilter == 'past',
                        onSelected: (selected) {
                          setState(() {
                            _selectedFilter = 'past';
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ),

              // Bookings list
              Expanded(
                child: _isLoading
                    ? const OptimizedLoadingWidget(
                        message: 'جاري تحميل الحجوزات...',
                        color: Color(0xFF2FBDAF),
                      )
                    : filteredBookings.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.calendar_today,
                                  size: 64,
                                  color: Colors.grey[400],
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'لا توجد حجوزات',
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: Colors.grey[600],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: filteredBookings.length,
                            itemBuilder: (context, index) {
                              final booking = filteredBookings[index];
                              final status = _getStatusText(booking);
                              final statusColor = _getStatusColor(status);

                              return Card(
                                margin: const EdgeInsets.only(bottom: 12),
                                elevation: 4,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  booking['patientName'] ?? 'غير محدد',
                                                  style: const TextStyle(
                                                    fontSize: 18,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  'د. ${booking['doctorName']}',
                                                  style: TextStyle(
                                                    fontSize: 16,
                                                    color: Colors.grey[600],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 6,
                                            ),
                                            decoration: BoxDecoration(
                                              color: statusColor.withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(20),
                                              border: Border.all(color: statusColor),
                                            ),
                                            child: Text(
                                              status,
                                              style: TextStyle(
                                                color: statusColor,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      Row(
                                        children: [
                                          Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              booking['facilityName'],
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: Colors.grey[600],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          Icon(Icons.medical_services, size: 16, color: Colors.grey[600]),
                                          const SizedBox(width: 8),
                                          Text(
                                            booking['specializationName'],
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                                          const SizedBox(width: 8),
                                          Text(
                                            booking['date'] ?? 'غير محدد',
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                          const SizedBox(width: 16),
                                          Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                                          const SizedBox(width: 8),
                                          Text(
                                            '${booking['time']} (${booking['period'] == 'morning' ? 'صباحاً' : 'مساءً'})',
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      // Action buttons
                                      Row(
                                        children: [
                                          Expanded(
                                            child: OutlinedButton.icon(
                                              onPressed: () => _rescheduleBooking(booking),
                                              icon: const Icon(Icons.schedule, size: 16, color: Color(0xFF2FBDAF)),
                                              label: const Text('تأجيل'),
                                              style: OutlinedButton.styleFrom(
                                                foregroundColor: const Color(0xFF2FBDAF),
                                                side: const BorderSide(color: Color(0xFF2FBDAF)),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: OutlinedButton.icon(
                                              onPressed: () => _generatePdfForBooking(booking),
                                              icon: const Icon(Icons.picture_as_pdf, size: 16, color: Colors.orange),
                                              label: const Text('PDF'),
                                              style: OutlinedButton.styleFrom(
                                                foregroundColor: Colors.orange,
                                                side: const BorderSide(color: Colors.orange),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: OutlinedButton.icon(
                                              onPressed: _cancellingBookings.contains(booking['id'])
                                                  ? null
                                                  : () => _cancelBooking(booking),
                                              icon: _cancellingBookings.contains(booking['id'])
                                                  ? const SizedBox(
                                                      width: 16,
                                                      height: 16,
                                                      child: CircularProgressIndicator(
                                                        strokeWidth: 2,
                                                        color: Colors.red,
                                                      ),
                                                    )
                                                  : const Icon(Icons.cancel, size: 16, color: Colors.red),
                                              label: Text(
                                                _cancellingBookings.contains(booking['id'])
                                                    ? 'جاري الإلغاء...'
                                                    : 'إلغاء',
                                              ),
                                              style: OutlinedButton.styleFrom(
                                                foregroundColor: Colors.red,
                                                side: const BorderSide(color: Colors.red),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _generatePdfForBooking(Map<String, dynamic> booking) async {
    try {
      // التحقق من البيانات المطلوبة
      if (booking['patientName'] == null || booking['patientName'].toString().isEmpty) {
        _showDialog("خطأ", "اسم المريض مطلوب");
        return;
      }
      
      if (booking['patientPhone'] == null || booking['patientPhone'].toString().isEmpty) {
        _showDialog("خطأ", "رقم الهاتف مطلوب");
        return;
      }

      // تحويل التاريخ من string إلى DateTime
      final bookingDate = DateTime.tryParse(booking['date'] ?? '');
      if (bookingDate == null) {
        _showDialog("خطأ", "تاريخ الحجز غير صحيح");
        return;
      }

              // إنشاء PDF وحفظه
      final Directory appDocDir = await getApplicationDocumentsDirectory();
      final String filePath = '${appDocDir.path}/booking_confirmation.pdf';
      final File file = File(filePath);
      
      // إنشاء PDF
      await SyncfusionPdfService.generateBookingPdf(
        facilityName: booking['facilityName'] ?? 'مركز طبي',
        specializationName: booking['specializationName'] ?? 'تخصص طبي',
        doctorName: booking['doctorName'] ?? 'طبيب',
        patientName: booking['patientName'].toString(),
        patientPhone: booking['patientPhone'].toString(),
        bookingDate: bookingDate,
        bookingTime: booking['time'] ?? '',
        period: booking['period'] ?? 'morning',
        bookingId: booking['id'] ?? 'UNKNOWN',
      );
      
      // عرض خيارات فتح ومشاركة
      showModalBottomSheet(
        context: context,
        builder: (context) => Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '  تفاصيل الحجز PDF',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _openPdf(file);
                      },
                      icon: const Icon(Icons.open_in_new),
                      label: const Text('فتح'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2FBDAF),
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _shareToWhatsApp(file);
                      },
                      icon: const Icon(Icons.share),
                      label: const Text('واتساب'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      print('خطأ في توليد PDF: $e');
      _showDialog("خطأ", "حدث خطأ في إنشاء PDF: ${e.toString()}");
    }
  }

  void _sharePdfData(Uint8List pdfData) async {
    try {
      // استخدام path_provider للحصول على مجلد مؤقت
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/booking_${DateTime.now().millisecondsSinceEpoch}.pdf');
      await tempFile.writeAsBytes(pdfData);
      
      print('تم حفظ PDF في: ${tempFile.path}');
      
      Share.shareXFiles(
        [XFile(tempFile.path)],
        text: 'تأكيد الحجز الطبي',
      );
    } catch (e) {
      print('خطأ في مشاركة PDF: $e');
      _showDialog("خطأ", "حدث خطأ في مشاركة PDF: ${e.toString()}");
    }
  }

  void _openPdfData(Uint8List pdfData) async {
    try {
      // استخدام path_provider للحصول على مجلد مؤقت
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/booking_${DateTime.now().millisecondsSinceEpoch}.pdf');
      await tempFile.writeAsBytes(pdfData);
      
      print('تم حفظ PDF في: ${tempFile.path}');
      
      // استخدام open_file لفتح PDF
      final result = await OpenFile.open(tempFile.path);
      
      if (result.type != ResultType.done) {
        _showDialog("خطأ", "لا يمكن فتح الملف: ${result.message}");
      }
    } catch (e) {
      print('خطأ في فتح PDF: $e');
      _showDialog("خطأ", "حدث خطأ في فتح PDF: ${e.toString()}");
    }
  }

  void _sharePdf(File pdfFile) {
    Share.shareXFiles(
      [XFile(pdfFile.path)],
      text: 'تأكيد الحجز الطبي',
    );
  }

  void _openPdf(File pdfFile) async {
    try {
      // استخدام open_file لفتح PDF
      final result = await OpenFile.open(pdfFile.path);
      
      if (result.type != ResultType.done) {
        _showDialog("خطأ", "لا يمكن فتح الملف: ${result.message}");
      }
    } catch (e) {
      print('خطأ في فتح PDF: $e');
      _showDialog("خطأ", "حدث خطأ في فتح PDF: ${e.toString()}");
    }
  }

  void _shareToWhatsApp(File pdfFile) async {
    try {
      // مشاركة الملف مباشرة مع تحديد واتساب كهدف
      await Share.shareXFiles(
        [XFile(pdfFile.path)],
        text: 'تأكيد الحجز الطبي - مركز جودة الطبي\n\nمركز جودة الطبي\n📞 +249991961111',
        subject: 'تأكيد الحجز الطبي',
      );
    } catch (e) {
      print('خطأ في مشاركة الملف: $e');
      _showDialog("خطأ", "حدث خطأ في مشاركة الملف: ${e.toString()}");
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
}
