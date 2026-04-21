import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hospital_app/widgets/optimized_loading_widget.dart';
import 'package:hospital_app/services/syncfusion_pdf_service.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:intl/intl.dart';
import 'dart:ui' as ui;
import 'dart:io';

class PatientBookingsScreen extends StatefulWidget {
  const PatientBookingsScreen({super.key});

  static void clearBookingsCache() => _PatientBookingsScreenState.clearBookingsCache();

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

  // Cache للحجوزات
  static List<Map<String, dynamic>> _bookingsCache = [];
  static DateTime? _lastCacheTime;
  static String? _cachedPatientId;
  static const Duration _cacheExpiry = Duration(minutes: 5); // انتهاء صلاحية Cache بعد 5 دقائق

  // فحص صحة Cache
  bool _isCacheValid() {
    if (_bookingsCache.isEmpty || _lastCacheTime == null) {
      return false;
    }
    if (_cachedPatientId != patientId) {
      return false;
    }
    final now = DateTime.now();
    final cacheAge = now.difference(_lastCacheTime!);

    return cacheAge < _cacheExpiry;
  }

  // مسح Cache
  static void clearBookingsCache() {
    _bookingsCache.clear();
    _lastCacheTime = null;
    _cachedPatientId = null;
    print('تم مسح Cache الحجوزات');
  }

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
    
    print('👤 بيانات المريض:');
    print('   - البريد الإلكتروني: $patientEmail');
    print('   - معرف المريض: $patientId');
    
    // تحميل البيانات فوراً بعد الحصول على معرف المريض
    if (patientId != null && patientId!.isNotEmpty) {
      await _fetchBookings();
    } else {
      print('❌ معرف المريض فارغ أو غير موجود');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchBookings() async {
    if (patientId == null) {
      setState(() => _isLoading = false);
      return;
    }

    if (_isCacheValid()) {
      setState(() {
        _bookings = List.from(_bookingsCache);
        _isLoading = false;
      });
      return;
    }

    try {
      setState(() => _isLoading = true);

      // استعلام واحد يجلب حجوزات المريض من كل المراكز
      final snapshot = await FirebaseFirestore.instance
          .collectionGroup('appointments')
          .where('patientId', isEqualTo: patientId)
          .get()
          .timeout(const Duration(seconds: 10));

      // جلب أسماء المراكز لكل facilityId فريد
      final facilityIds = snapshot.docs
          .map((doc) => doc.data()['facilityId'] as String? ?? doc.reference.parent.parent?.id ?? '')
          .where((id) => id.isNotEmpty)
          .toSet();

      final Map<String, String> facilityNames = {};
      await Future.wait(facilityIds.map((id) async {
        final facilityDoc = await FirebaseFirestore.instance
            .collection('medicalFacilities')
            .doc(id)
            .get();
        facilityNames[id] = facilityDoc.data()?['name'] ?? 'مركز طبي';
      }));

      // فلتر: فقط medicalFacilities/{id}/appointments/{docId} (4 أجزاء)
      // تجاهل: medicalFacilities/{id}/specializations/{id}/doctors/{id}/appointments/{docId} (8 أجزاء)
      final validDocs = snapshot.docs.where((doc) {
        final segments = doc.reference.path.split('/');
        return segments.length == 4;
      }).toList();

      final List<Map<String, dynamic>> allBookings = validDocs.map((doc) {
        final data = doc.data();
        final fId = data['facilityId'] as String? ?? doc.reference.parent.parent?.id ?? '';
        return {
          ...data,
          'id': doc.id,
          'facilityId': fId,
          'facilityName': facilityNames[fId] ?? 'مركز طبي',
          'specializationId': data['centralSpecialtyId'] ?? data['specializationId'] ?? '',
        };
      }).toList();

      // ترتيب الحجوزات: آخر حجز تم إنشاؤه أولاً
      allBookings.sort((a, b) {
        // أولاً: استخدم createdAt إن وُجد
        final createdA = a['createdAt'];
        final createdB = b['createdAt'];
        if (createdA != null && createdB != null) {
          DateTime? dtA, dtB;
          if (createdA is DateTime) {
            dtA = createdA;
          } else if (createdA.runtimeType.toString().contains('Timestamp')) {
            dtA = (createdA as dynamic).toDate() as DateTime;
          }
          if (createdB is DateTime) {
            dtB = createdB;
          } else if (createdB.runtimeType.toString().contains('Timestamp')) {
            dtB = (createdB as dynamic).toDate() as DateTime;
          }
          if (dtA != null && dtB != null) return dtB.compareTo(dtA);
        }
        // ثانياً: استخدم تاريخ الموعد
        final dateA = DateTime.tryParse(a['date'] ?? '');
        final dateB = DateTime.tryParse(b['date'] ?? '');
        if (dateA == null && dateB == null) return 0;
        if (dateA == null) return 1;
        if (dateB == null) return -1;
        return dateB.compareTo(dateA);
      });

      _bookingsCache = List.from(allBookings);
      _lastCacheTime = DateTime.now();
      _cachedPatientId = patientId;

      setState(() {
        _bookings = allBookings;
        _isLoading = false;
      });
    } catch (e) {
      print('❌ خطأ في تحميل الحجوزات: $e');
      setState(() => _isLoading = false);
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
    if (booking['status'] == 'canceled') return 'ملغي';

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
      case 'ملغي':
        return Colors.red;
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
      setState(() {
        _cancellingBookings.add(bookingId);
      });

      try {
        await FirebaseFirestore.instance
            .collection('medicalFacilities')
            .doc(booking['facilityId'])
            .collection('appointments')
            .doc(bookingId)
            .update({'status': 'canceled'})
            .timeout(const Duration(seconds: 5));

        // تحديث الحالة محلياً بدلاً من الحذف
        setState(() {
          final idx = _bookings.indexWhere((b) => b['id'] == bookingId);
          if (idx != -1) _bookings[idx] = {..._bookings[idx], 'status': 'canceled'};
          _cancellingBookings.remove(bookingId);
        });

        clearBookingsCache();

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

  // دالة تأجيل الحجز - معلقة حالياً حسب طلب المستخدم
  // يمكن إعادة تفعيلها لاحقاً إذا لزم الأمر
  /*
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
  */

  @override
  Widget build(BuildContext context) {
    final filteredBookings = getFilteredBookings();

    return Directionality(
      textDirection: ui.TextDirection.rtl,
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
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh, color: Color(0xFF2FBDAF)),
              onPressed: () {
                print('🔄 تحديث يدوي للحجوزات...');
                clearBookingsCache();
                _fetchBookings();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('تم تحديث الحجوزات'),
                    duration: Duration(seconds: 1),
                    backgroundColor: Color(0xFF2FBDAF),
                  ),
                );
              },
            ),
          ],
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
                                color: status == 'ملغي'
                                    ? Colors.red.withValues(alpha: 0.07)
                                    : status == 'منتهي'
                                        ? Colors.grey.withValues(alpha: 0.07)
                                        : Colors.white,
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
                                        '${booking['doctorName']} (${booking['specializationName']})',
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
                                              color: statusColor.withValues(alpha: 0.1),
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
                                      const SizedBox(height: 8),
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
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                                          const SizedBox(width: 8),
                                          Text(
                                            '${booking['date'] ?? 'غير محدد'} - ${booking['period'] == 'morning' ? 'صباحاً' : 'مساءً'}',
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                        ],
                                      ),
                                      // Action buttons - إخفاء الأزرار للحجوزات المنتهية والملغاة
                                      if (status != 'منتهي' && status != 'ملغي') ...[
                                        const SizedBox(height: 8),
                                      Row(
                                        children: [
                                            // زر PDF (على اليمين)
                                          Expanded(
                                            child: OutlinedButton.icon(
                                              onPressed: () => _generatePdfForBooking(booking),
                                                icon: const Icon(Icons.picture_as_pdf, size: 16, color: Colors.black),
                                              label: const Text('PDF'),
                                              style: OutlinedButton.styleFrom(
                                                  foregroundColor: Colors.black,
                                                  side: const BorderSide(color: Colors.black),
                                                backgroundColor: Colors.white,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                            // زر إلغاء الحجز (على اليسار)
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
                                                          color: Colors.black,
                                                      ),
                                                    )
                                                  : const Icon(Icons.close, size: 16, color: Colors.black),
                                              label: Text(
                                                _cancellingBookings.contains(booking['id'])
                                                    ? 'جاري الإلغاء...'
                                                    : 'إلغاء',
                                              ),
                                              style: OutlinedButton.styleFrom(
                                                foregroundColor: Colors.black,
                                                side: const BorderSide(color: Colors.black),
                                                backgroundColor: Colors.white,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      ],
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
      
      // حساب وقت الحضور: أول حجز للطبيب في يوم الحجز (ليس أول حجز للمريض)
      String? periodStartTime;
      try {
        if (booking['facilityId'] != null && booking['specializationId'] != null && booking['doctorId'] != null) {
          // المسار الصحيح لبيانات الطبيب
          final doctorSnap = await FirebaseFirestore.instance
              .collection('medicalFacilities')
              .doc(booking['facilityId'])
              .collection('specializations')
              .doc(booking['specializationId'])
              .collection('doctors')
              .doc(booking['doctorId'])
              .get();
          final doctorData = doctorSnap.data();
          final workingSchedule = (doctorData?['workingSchedule'] as Map<String, dynamic>?) ?? {};
          if (workingSchedule.isNotEmpty) {
            // يوم الحجز بصيغة عربية
            final dayName = DateFormat('EEEE', 'ar').format(bookingDate).trim();
            String? alternativeDayName;
            switch (bookingDate.weekday) {
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
            var schedule = workingSchedule[dayName];
            if (schedule == null && alternativeDayName != null) {
              schedule = workingSchedule[alternativeDayName];
            }
            // إذا لم نجد جدول اليوم، حاول إيجاد أي جدول يحتوي evening/morning
            if (schedule == null) {
              for (final entry in workingSchedule.entries) {
                final val = entry.value;
                if (val is Map && (val['evening'] != null || val['morning'] != null)) {
                  schedule = val;
                  break;
                }
              }
            }
            if (schedule != null) {
              // تحديد الفترة الهدف من بيانات الحجز أو الاستدلال من الوقت
              String targetPeriod = (booking['period']?.toString().isNotEmpty ?? false) ? booking['period'].toString() : 'evening';
              if (booking['period'] == null) {
                // محاولة الاستدلال من وقت الحجز
                String bookedTimeStr = (booking['time'] ?? '').toString();
                if (bookedTimeStr.isNotEmpty && !bookedTimeStr.contains(':') && RegExp(r'^\d{1,2}$').hasMatch(bookedTimeStr)) {
                    bookedTimeStr = bookedTimeStr.padLeft(2, '0') + ':00';
                  }
                DateTime? _timeOf(String? hhmm) {
                  if (hhmm == null || !hhmm.contains(':')) return null;
                  final parts = hhmm.split(':');
                  return DateTime(bookingDate.year, bookingDate.month, bookingDate.day,
                      int.tryParse(parts[0]) ?? 0, int.tryParse(parts[1]) ?? 0);
                }
                final DateTime? bookedTime = _timeOf(bookedTimeStr);
                final String? eveningStart = schedule['evening']?['start']?.toString();
                final String? eveningEnd = schedule['evening']?['end']?.toString();
                final String? morningStart = schedule['morning']?['start']?.toString();
                final String? morningEnd = schedule['morning']?['end']?.toString();
                DateTime? _toDT(String? t) => (t == null || !t.contains(':')) ? null : DateTime(bookingDate.year, bookingDate.month, bookingDate.day, int.tryParse(t.split(':')[0]) ?? 0, int.tryParse(t.split(':')[1]) ?? 0);
                final eveStart = _toDT(eveningStart);
                final eveEnd = _toDT(eveningEnd);
                final morStart = _toDT(morningStart);
                final morEnd = _toDT(morningEnd);
                bool inRange(DateTime? t, DateTime? s, DateTime? e) => t != null && s != null && e != null && (t.isAtSameMomentAs(s) || t.isAfter(s)) && t.isBefore(e);
                if (bookedTime != null && inRange(bookedTime, morStart, morEnd)) targetPeriod = 'morning';
                if (bookedTime != null && inRange(bookedTime, eveStart, eveEnd)) targetPeriod = 'evening';
              }

              // استعلام: أول موعد للطبيب في نفس اليوم والفترة
              try {
                final qs = await FirebaseFirestore.instance
                    .collection('medicalFacilities')
                    .doc(booking['facilityId'])
                    .collection('specializations')
                    .doc(booking['specializationId'])
                    .collection('doctors')
                    .doc(booking['doctorId'])
                    .collection('appointments')
                    .where('date', isEqualTo: booking['date'])
                    .where('period', isEqualTo: targetPeriod)
                    .orderBy('time')
                    .limit(1)
                    .get();
                if (qs.docs.isNotEmpty) {
                  String t = (qs.docs.first.data()['time'] ?? '').toString();
                  if (t.isNotEmpty && !t.contains(':') && RegExp(r'^\d{1,2}$').hasMatch(t)) {
                    t = t.padLeft(2, '0') + ':00';
                  }
                  if (t.isNotEmpty) {
                    periodStartTime = t;
                  }
                }
              } catch (_) {}

              // إن لم نجد من الاستعلام، يمكن استخدام بداية الفترة من الجدول كحل احتياطي
              if ((periodStartTime == null || periodStartTime.isEmpty) && booking['period'] != null && schedule[booking['period']] != null) {
                periodStartTime = schedule[booking['period']]['start'];
              }
            }
          }
        }
      } catch (_) {}

      // Fallback: إذا تعذر الحصول على أول وقت من استعلام المواعيد أو الجدول، استخدم أول وقت حجز في نفس اليوم والفترة للطبيب من مجموعة bookings العامة (إن وُجدت)
      try {
        if ((periodStartTime == null || periodStartTime.isEmpty) &&
            booking['doctorId'] != null &&
            booking['date'] != null) {
          final String targetPeriod = (booking['period']?.toString().isNotEmpty ?? false)
              ? booking['period'].toString()
              : 'evening';

          final qs = await FirebaseFirestore.instance
              .collection('bookings')
              .where('doctorId', isEqualTo: booking['doctorId'])
              .where('date', isEqualTo: booking['date'])
              .where('period', isEqualTo: targetPeriod)
              .orderBy('time')
              .limit(1)
              .get();

          if (qs.docs.isNotEmpty) {
            final first = qs.docs.first.data();
            String t = (first['time'] ?? '').toString();
            // تطبيع مثل 16 -> 16:00
            if (t.isNotEmpty && !t.contains(':') && RegExp(r'^\d{1,2}$').hasMatch(t)) {
              t = t.padLeft(2, '0') + ':00';
            }
            if (t.isNotEmpty) {
              periodStartTime = t;
            }
          }
        }
      } catch (e) {
        // تجاهل أي أخطاء في الاستعلام الاحتياطي
      }

      // Fallback إضافي: استخدام حجوزات هذه الشاشة (خاصة بالمريض) كحل أخير لاشتقاق وقت قريب منطقي
      if ((periodStartTime == null || periodStartTime.isEmpty)) {
        try {
          String targetPeriod = (booking['period']?.toString().isNotEmpty ?? false)
              ? booking['period'].toString()
              : 'evening';

          // اجلب جميع الحجوزات المطابقة من الذاكرة
          final sameDayDoctor = _bookings.where((b) {
            return b['doctorId'] == booking['doctorId'] &&
                   b['date'] == booking['date'] &&
                   (b['period']?.toString() ?? '') == targetPeriod;
          }).toList();

          int _toMinutes(String t) {
            // تطبيع الوقت: "16" -> "16:00"
            if (t.isNotEmpty && !t.contains(':') && RegExp(r'^\d{1,2}$').hasMatch(t)) {
              t = t.padLeft(2, '0') + ':00';
            }
            final parts = t.split(':');
            final h = int.tryParse(parts[0]) ?? 0;
            final m = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
            return h * 60 + m;
          }

          if (sameDayDoctor.isNotEmpty) {
            sameDayDoctor.sort((a, b) => _toMinutes((a['time'] ?? '').toString())
                .compareTo(_toMinutes((b['time'] ?? '').toString())));
            String t = (sameDayDoctor.first['time'] ?? '').toString();
            if (t.isNotEmpty && !t.contains(':') && RegExp(r'^\d{1,2}$').hasMatch(t)) {
              t = t.padLeft(2, '0') + ':00';
            }
            if (t.isNotEmpty) {
              periodStartTime = t;
            }
          }
        } catch (_) {}
      }

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
        periodStartTime: periodStartTime,
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
