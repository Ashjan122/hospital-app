import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hospital_app/screnns/hospital_screen.dart';
import 'package:hospital_app/screnns/patient_bookings_screen.dart';
import 'package:hospital_app/screnns/booking_screen.dart';
import 'package:hospital_app/screnns/login_screen.dart';
import 'package:hospital_app/screnns/about_screen.dart';
import 'package:hospital_app/screnns/home_clinic_screen.dart';
import 'package:hospital_app/services/central_data_service.dart';
import 'package:hospital_app/services/presence_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PatientHomeScreen extends StatefulWidget {
  const PatientHomeScreen({super.key});

  @override
  State<PatientHomeScreen> createState() => _PatientHomeScreenState();
}

class _PatientHomeScreenState extends State<PatientHomeScreen> {
  String? patientEmail;
  String? patientName;
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;
  Timer? _debounceTimer;
  bool _searchCacheReady = false;
  List<String> _supportPhones = [];
  StreamSubscription? _supportPhonesSub;

  @override
  void initState() {
    super.initState();
    _loadPatientData();
    _searchController.addListener(_onSearchChanged);
    _checkDatabaseConnection();
    _initPresence();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShowAdDialog());
    // Warm up search cache to speed up the first search
    WidgetsBinding.instance.addPostFrameCallback((_) => _warmupSearchCache());
    // Listen to technical support phone numbers from Firestore (live updates)
    WidgetsBinding.instance.addPostFrameCallback((_) => _listenSupportPhones());
    // Also load once immediately
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadSupportPhonesOnce());
  }

  Future<void> _initPresence() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final patientId = prefs.getString('userId') ?? '';
      if (patientId.isNotEmpty) {
        await PresenceService.setOnline(patientId: patientId);
      }
    } catch (_) {}
  }

  Future<void> _checkDatabaseConnection() async {
    try {
      // فحص الاتصال بقاعدة البيانات
      print('فحص الاتصال بقاعدة البيانات...');
      await CentralDataService.checkExistingData();
      
      // مسح Cache للتأكد من تطبيق التحديثات
      CentralDataService.clearAllCache();
      print('تم مسح Cache - البحث محدث للبحث في الأطباء والتخصصات فقط');
      
      // مسح Cache إضافي للتأكد
      await Future.delayed(const Duration(milliseconds: 100));
      CentralDataService.clearAllCache();
      print('تم مسح Cache - جاهز لاختبار عرض الأيام مع تحسين جلب workingSchedule');
      
      // تحميل البيانات مسبقاً في Cache للبحث السريع
      print('تحميل البيانات مسبقاً للبحث السريع...');
      // تسخين الكاش مباشرة بعد تنظيفه (بانتظار الاكتمال)
      await _prefetchSearchData();
      if (mounted) {
        setState(() {
          _searchCacheReady = true;
        });
      }
      
      print('تم تحميل البيانات بنجاح - البحث جاهز!');
    } catch (e) {
      print('خطأ في الاتصال بقاعدة البيانات: $e');
    }
  }

  @override
  void dispose() {
    // Mark offline on screen dispose
    SharedPreferences.getInstance().then((prefs) {
      final patientId = prefs.getString('userId') ?? '';
      PresenceService.setOffline(patientId: patientId);
    });
    _searchController.dispose();
    _debounceTimer?.cancel();
    _supportPhonesSub?.cancel();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim();
    
    // إلغاء البحث السابق
    _debounceTimer?.cancel();
    
    // تحديث الواجهة لإظهار/إخفاء زر X
    setState(() {});
    
    // إذا لم يجهز الكاش بعد، لا تنفذ البحث حتى يكتمل التحميل الأولي
    if (!_searchCacheReady) {
      return;
    }

    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }
    
    // البحث الفوري من أول حرف بدون تأخير
    _performSearch(query);
  }

  Future<void> _warmupSearchCache() async {
    try {
      // إجراء بحث خفيف لتسخين الـ Cache حتى يكون أول بحث سريعاً
      await CentralDataService.searchDoctorsAndSpecialties('ا');
    } catch (_) {}
  }

  Future<void> _prefetchSearchData() async {
    try {
      // استعلامات خفيفة متعددة لزيادة احتمالية ملء الكاش من مسارات مختلفة
      await Future.wait([
        CentralDataService.searchDoctorsAndSpecialties('ا'),
        CentralDataService.searchDoctorsAndSpecialties('د'),
        CentralDataService.searchDoctorsAndSpecialties('a'),
      ]);
    } catch (_) {}
  }

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) return;
    
    setState(() {
      _isSearching = true;
    });
    
    try {
      print('البحث عن: $query');
      final results = await CentralDataService.searchDoctorsAndSpecialties(query);
      print('عدد النتائج: ${results.length}');
      
      setState(() {
        _searchResults = results;
        _isSearching = false;
      });
      
      // إلغاء رسالة "لم يتم العثور على نتائج" مع خيار مسح الكاش
    } catch (e) {
      print('خطأ في البحث: $e');
      setState(() {
        _isSearching = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في البحث: $e'),
            backgroundColor: Colors.red,
            action: SnackBarAction(
              label: 'مسح Cache',
              textColor: Colors.white,
              onPressed: () {
                CentralDataService.clearAllCache();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('تم مسح Cache بنجاح'),
                    duration: Duration(seconds: 1),
                  ),
                );
              },
            ),
          ),
        );
      }
    }
  }

  Future<void> _loadPatientData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      patientEmail = prefs.getString('userEmail');
      patientName = prefs.getString('userName') ?? 'مريض عزيز';
    });
  }

  void _showTechnicalSupportDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            contentPadding: const EdgeInsets.all(20),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title
                Text(
                  "الدعم الفني",
                  style: TextStyle(
                    color: const Color(0xFF2FBDAF),
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 12),
                
                // Description
                Text(
                  "يرجى الاتصال على الأرقام التالية:",
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 12),
                
                // Phone Numbers (from Firestore)
                if (_supportPhones.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(
                      "لا توجد أرقام متاحة حالياً",
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    ),
                  )
                else
                  ...[
                    for (int i = 0; i < _supportPhones.length; i++) ...[
                      _buildPhoneNumber(_supportPhones[i]),
                      if (i < _supportPhones.length - 1) const SizedBox(height: 8),
                    ]
                  ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: Text(
                  "إغلاق",
                  style: TextStyle(
                    color: Colors.purple,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _listenSupportPhones() {
    _supportPhonesSub?.cancel();
    _supportPhonesSub = FirebaseFirestore.instance
        .collection('support')
        .doc('phones')
        .snapshots()
        .listen((doc) {
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>?;
        final numbers = (data?['numbers'] as List?)
            ?.map((e) => (e ?? '').toString().trim())
            .where((s) => s.isNotEmpty)
            .cast<String>()
            .toList() ?? [];
        if (mounted) {
          setState(() {
            _supportPhones = numbers;
          });
        }
      }
    }, onError: (e) {
      print('خطأ في الاستماع لأرقام الدعم: $e');
    });
  }

  Future<void> _loadSupportPhonesOnce() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('support')
          .doc('phones')
          .get()
          .timeout(const Duration(seconds: 3));
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>?;
        final numbers = (data?['numbers'] as List?)
            ?.map((e) => (e ?? '').toString().trim())
            .where((s) => s.isNotEmpty)
            .cast<String>()
            .toList() ?? [];
        if (mounted) {
          setState(() {
            _supportPhones = numbers;
          });
        }
      }
    } catch (e) {
      print('خطأ في تحميل أرقام الدعم: $e');
    }
  }

  Widget _buildPhoneNumber(String phoneNumber) {
    return GestureDetector(
      onTap: () => _makePhoneCall(phoneNumber),
      onLongPress: () => _copyPhoneNumber(phoneNumber),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Text(
          phoneNumber,
          style: TextStyle(
            color: const Color(0xFF2FBDAF),
            fontSize: 16,
            fontWeight: FontWeight.w500,
            decoration: TextDecoration.underline,
          ),
        ),
      ),
    );
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri phoneUri = Uri(scheme: 'tel', path: phoneNumber);
    try {
      if (await canLaunchUrl(phoneUri)) {
        await launchUrl(phoneUri);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('لا يمكن فتح تطبيق الهاتف'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطأ في الاتصال: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _copyPhoneNumber(String phoneNumber) {
    Clipboard.setData(ClipboardData(text: phoneNumber));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('تم نسخ الرقم: $phoneNumber'),
        backgroundColor: const Color(0xFF2FBDAF),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<bool> _openBookingByDoctorName(String doctorName) async {
    try {
      String _normalizeName(String s) {
        final map = {
          'أ': 'ا', 'إ': 'ا', 'آ': 'ا', 'ة': 'ه', 'ى': 'ي', 'ئ': 'ي', 'ؤ': 'و', 'ـ': '', 'ً': '', 'ٌ': '', 'ٍ': '', 'َ': '', 'ُ': '', 'ِ': '', 'ّ': ''
        };
        String out = s.trim();
        map.forEach((k, v) => out = out.replaceAll(k, v));
        out = out.replaceAll(RegExp(r"[^\u0600-\u06FFa-zA-Z0-9 ]"), '');
        out = out.replaceAll(RegExp(r"\s+"), ' ');
        return out.toLowerCase();
      }

      final target = _normalizeName(doctorName.startsWith('د') ? doctorName.substring(1) : doctorName);

      // Search nested collections for doctor by name
      Future<bool> searchInRoot(String rootCollection) async {
        final facilities = await FirebaseFirestore.instance
            .collection(rootCollection)
            .get();

        for (final facilityDoc in facilities.docs) {
          final specs = await FirebaseFirestore.instance
              .collection(rootCollection)
              .doc(facilityDoc.id)
              .collection('specializations')
              .get();

          for (final specDoc in specs.docs) {
            final doctors = await FirebaseFirestore.instance
                .collection(rootCollection)
                .doc(facilityDoc.id)
                .collection('specializations')
                .doc(specDoc.id)
                .collection('doctors')
                .get();

            for (final d in doctors.docs) {
              final data = d.data() as Map<String, dynamic>;
              final docName = (data['docName'] ?? '').toString();
              if (_normalizeName(docName) != target) continue;

              final workingSchedule = data['workingSchedule'] as Map<String, dynamic>? ?? {};

              if (workingSchedule.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('لا يوجد جدول عمل للطبيب'), backgroundColor: Colors.red),
                );
                return false;
              }

              if (!mounted) return false;
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => BookingScreen(
                    name: docName,
                    workingSchedule: workingSchedule,
                    facilityId: facilityDoc.id,
                    specializationId: specDoc.id,
                    doctorId: d.id,
                    showDoctorInfo: true,
                    doctorSpecialty: (data['specialization'] ?? '').toString(),
                    centerName: (facilityDoc.data() as Map<String, dynamic>?)?['name'] ?? '',
                  ),
                ),
              );
              return true;
            }
          }
        }
        return false;
      }

      if (await searchInRoot('medicalFacilities')) return true;
      if (await searchInRoot('facilities')) return true;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('لم يتم العثور على الطبيب: $doctorName'), backgroundColor: Colors.red),
      );
      return false;
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر فتح صفحة الحجز: $e'), backgroundColor: Colors.red),
      );
      return false;
    }
  }

  Future<void> _maybeShowAdDialog() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastShownAdId = prefs.getString('lastShownAdId');

      print('[AD] Checking for ad... lastShownAdId=$lastShownAdId');

      // First check for update ads (priority)
      QuerySnapshot updateSnapshot = await FirebaseFirestore.instance
          .collection('ads')
          .where('show', isEqualTo: true)
          .where('tybe', isEqualTo: 'update')
          .limit(1)
          .get();

      QuerySnapshot snapshot;
      if (updateSnapshot.docs.isNotEmpty) {
        // If update ad exists, use it (priority)
        print('[AD] Found update ad, showing it with priority');
        snapshot = updateSnapshot;
      } else {
        // Otherwise, get any ad with show == true
        print('[AD] No update ad found, checking for other ads');
        snapshot = await FirebaseFirestore.instance
            .collection('ads')
            .where('show', isEqualTo: true)
            .limit(1)
            .get();
      }

      if (snapshot.docs.isEmpty) {
        print('[AD] No ads found.');
        return;
      }

      final doc = snapshot.docs.first;
      final data = doc.data() as Map<String, dynamic>;
      // Use business id field if available, otherwise doc id
      final adId = (data['id']?.toString().isNotEmpty ?? false) ? data['id'].toString() : doc.id;
      print('[AD] Found ad id=$adId');
      
      final tybe = (data['tybe'] ?? '').toString();
      
      // Check if ad was already shown (for all ad types including update)
      if (adId == lastShownAdId) {
        print('[AD] Already shown, skipping. adId=$adId, lastShownAdId=$lastShownAdId');
        return;
      }

      final title = (data['title'] ?? '').toString();
      final message = (data['message'] ?? '').toString();
      final doctorName = (data['doctorNam'] ?? '').toString();
      final doctorPhotoUrl = (data['doctorPhotoUrl'] ?? '').toString();
      final centerLogoUrl = (data['centerLogoUrl'] ?? '').toString();
      final adFacilityId = (data['facilityId'] ?? '').toString();
      final adSpecializationId = (data['specializationId'] ?? '').toString();
      final adCentralDoctorId = (data['centralDoctorId'] ?? '').toString();
      final bottonLabel = (data['bottonLabel'] ?? '').toString();
      final bottonUrl = (data['bottonUrl'] ?? '').toString();

      if (!mounted) return;
      final dialogFuture = showDialog(
        context: context,
        barrierDismissible: tybe != 'update', // Update ads cannot be dismissed
        builder: (ctx) {
          bool isLoading = false;
          return Directionality(
            textDirection: TextDirection.rtl,
            child: StatefulBuilder(
              builder: (ctx2, setState) => AlertDialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                contentPadding: EdgeInsets.zero,
                content: Stack(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              // Only show close button for non-update ads
                              if (tybe != 'update')
                                IconButton(
                                  onPressed: () => Navigator.of(ctx).pop(),
                                  icon: const Icon(Icons.close, color: Colors.black54),
                                  splashRadius: 18,
                                )
                              else
                                const SizedBox(width: 48), // Placeholder for spacing
                              if (centerLogoUrl.isNotEmpty)
                                CircleAvatar(
                                  radius: 20,
                                  backgroundColor: Colors.white,
                                  backgroundImage: NetworkImage(centerLogoUrl),
                                ),
                            ],
                          ),

                          const SizedBox(height: 8),

                          if (title.isNotEmpty)
                            Text(
                              title,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.w700,
                                fontSize: 18,
                              ),
                            ),
                          if (tybe == 'doctor' && doctorName.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              (doctorName.startsWith('د') ? doctorName : 'د. $doctorName'),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Color(0xFFB71C1C),
                                fontWeight: FontWeight.w900,
                                fontSize: 22,
                              ),
                            ),
                          ],

                          const SizedBox(height: 12),

                          if (tybe == 'doctor' && doctorPhotoUrl.isNotEmpty)
                            Center(
                              child: Container(
                                width: 120,
                                height: 120,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(color: const Color(0xFFB71C1C), width: 6),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(4.0),
                                  child: CircleAvatar(
                                    backgroundImage: NetworkImage(doctorPhotoUrl),
                                    backgroundColor: Colors.grey[200],
                                  ),
                                ),
                              ),
                            ),

                          const SizedBox(height: 16),

                          if (message.isNotEmpty)
                            Text(
                              message,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.w700,
                                fontSize: 18,
                              ),
                            ),
                          const SizedBox(height: 16),
                          
                          // Update button for update ads
                          if (tybe == 'update' && bottonLabel.isNotEmpty && bottonUrl.isNotEmpty)
                            ElevatedButton(
                              onPressed: isLoading
                                  ? null
                                  : () async {
                                      if (!mounted) return;
                                      setState(() => isLoading = true);
                                      try {
                                        final Uri url = Uri.parse(bottonUrl);
                                        print('[UPDATE] Attempting to open URL: $bottonUrl');
                                        
                                        // Try different launch modes
                                        bool launched = false;
                                        
                                        // First try: external application (browser)
                                        if (await canLaunchUrl(url)) {
                                          try {
                                            await launchUrl(url, mode: LaunchMode.externalApplication);
                                            launched = true;
                                            print('[UPDATE] Successfully opened in external app');
                                          } catch (e) {
                                            print('[UPDATE] Failed to open in external app: $e');
                                          }
                                        }
                                        
                                        // Second try: platform default
                                        if (!launched) {
                                          try {
                                            await launchUrl(url, mode: LaunchMode.platformDefault);
                                            launched = true;
                                            print('[UPDATE] Successfully opened with platform default');
                                          } catch (e) {
                                            print('[UPDATE] Failed to open with platform default: $e');
                                          }
                                        }
                                        
                                        // Third try: in-app web view
                                        if (!launched) {
                                          try {
                                            await launchUrl(url, mode: LaunchMode.inAppWebView);
                                            launched = true;
                                            print('[UPDATE] Successfully opened in web view');
                                          } catch (e) {
                                            print('[UPDATE] Failed to open in web view: $e');
                                          }
                                        }
                                        
                                        if (launched) {
                                          // Mark update ad as shown after successful launch
                                          await prefs.setString('lastShownAdId', adId);
                                          Navigator.of(ctx).pop();
                                        } else {
                                          // Copy URL to clipboard as fallback
                                          await Clipboard.setData(ClipboardData(text: bottonUrl));
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text('لا يمكن فتح الرابط. تم نسخ الرابط: $bottonUrl'),
                                              backgroundColor: Colors.orange,
                                              duration: const Duration(seconds: 5),
                                              action: SnackBarAction(
                                                label: 'نسخ مرة أخرى',
                                                textColor: Colors.white,
                                                onPressed: () async {
                                                  await Clipboard.setData(ClipboardData(text: bottonUrl));
                                                },
                                              ),
                                            ),
                                          );
                                        }
                                      } catch (e) {
                                        print('[UPDATE] Error opening URL: $e');
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text('خطأ في فتح رابط التحديث: $e'),
                                            backgroundColor: Colors.red,
                                            duration: const Duration(seconds: 5),
                                          ),
                                        );
                                      } finally {
                                        if (context.mounted) setState(() => isLoading = false);
                                      }
                                    },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF2FBDAF),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
                              ),
                              child: isLoading
                                  ? const SizedBox(
                                      height: 22,
                                      width: 22,
                                      child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
                                    )
                                  : Text(bottonLabel),
                            ),
                          
                          // Doctor booking button for doctor ads
                          if (tybe == 'doctor' && doctorName.isNotEmpty)
                            ElevatedButton(
                              onPressed: isLoading
                                  ? null
                                  : () async {
                                      if (!mounted) return;
                                      setState(() => isLoading = true);
                                      try {
                                        final results = await CentralDataService.searchDoctorsAndSpecialties(doctorName);
                                        Map<String, dynamic>? match;
                                        String _norm(String s) {
                                          final map = {'أ':'ا','إ':'ا','آ':'ا','ة':'ه','ى':'ي','ئ':'ي','ؤ':'و','ـ':''};
                                          String out = s.trim();
                                          map.forEach((k,v){ out = out.replaceAll(k,v); });
                                          return out.replaceAll(RegExp(r"\s+"), ' ').toLowerCase();
                                        }
                                        final target = _norm(doctorName.startsWith('د') ? doctorName.substring(1) : doctorName);
                                        for (final r in results) {
                                          if (r['type'] == 'doctor' && _norm(r['name'] ?? '') == target) { match = r; break; }
                                        }
                                        match ??= results.cast<Map<String, dynamic>?>().firstWhere(
                                          (r) => (r?['type'] == 'doctor') && _norm(r?['name'] ?? '').contains(target),
                                          orElse: () => null,
                                        );

                                        if (match != null && match.isNotEmpty) {
                                          final schedule = match['workingSchedule'] as Map<String, dynamic>? ?? {};
                                          if (schedule.isNotEmpty) {
                                            final facilityId = (match['facilityId'] ?? '').toString();
                                            final specializationId = (match['specializationId'] ?? '').toString();
                                            final doctorId = (match['id'] ?? '').toString();
                                            final centerName = (match['centerName'] ?? '').toString();
                                            final specName = (match['specialization'] ?? '').toString();
                                            if (!context.mounted) return;
                                            Navigator.of(ctx).pop();
                                            Navigator.of(context).push(
                                              MaterialPageRoute(
                                                builder: (_) => BookingScreen(
                                                  name: (match?['name'] ?? doctorName).toString(),
                                                  workingSchedule: schedule,
                                                  facilityId: facilityId,
                                                  specializationId: specializationId,
                                                  doctorId: doctorId,
                                                  showDoctorInfo: true,
                                                  doctorSpecialty: specName,
                                                  centerName: centerName,
                                                ),
                                              ),
                                            );
                                            return;
                                          }
                                        }

                                        // fallback
                                        if (!context.mounted) return;
                                        Navigator.of(ctx).pop();
                                        Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (_) => DoctorBookingLoaderTemp(
                                              name: doctorName,
                                              facilityId: adFacilityId.isNotEmpty ? adFacilityId : null,
                                              specializationId: adSpecializationId.isNotEmpty ? adSpecializationId : null,
                                              centralDoctorId: adCentralDoctorId.isNotEmpty ? adCentralDoctorId : null,
                                            ),
                                          ),
                                        );
                                      } finally {
                                        if (context.mounted) setState(() => isLoading = false);
                                      }
                                    },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFB71C1C),
                                foregroundColor: Colors.black,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
                              ),
                              child: isLoading
                                  ? const SizedBox(
                                      height: 22,
                                      width: 22,
                                      child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.black)),
                                    )
                                  : const Text('احجز الآن'),
                            ),

                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );

      await dialogFuture;

      // Mark as shown (only for non-update ads, update ads are marked when button is pressed)
      if (tybe != 'update') {
        await prefs.setString('lastShownAdId', adId);
        print('[AD] Marked ad as shown: $adId');
      }
    } catch (e) {
      print('[AD] Error showing ad: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        appBar: AppBar(
          centerTitle: true,
          backgroundColor: Colors.white,
          elevation: 0,
          title: Text(
            "الرئيسية",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: const Color(0xFF2FBDAF),
              fontSize: 30,
            ),
          ),
          leading: IconButton(
            icon: const Icon(Icons.info_outline, color: Color(0xFF2FBDAF)),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const AboutScreen()),
              );
            },
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.logout, color: Color(0xFF2FBDAF)),
              onPressed: () async {
                // Clear saved login data
                final prefs = await SharedPreferences.getInstance();
                final patientId = prefs.getString('userId') ?? '';
                await PresenceService.setOffline(patientId: patientId);
                await prefs.clear();

                // Navigate to login screen
                if (context.mounted) {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (context) => const LoginScreen()),
                    (route) => false,
                  );
                }
              },
            ),
          ],
        ),
        body: SafeArea(
          child: Container(
            color: Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  // Search Bar
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 24),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: TextField(
                      controller: _searchController,
                      textDirection: TextDirection.rtl,
                      onSubmitted: _performSearch,
                      decoration: InputDecoration(
                        hintText: "ابحث عن اسم طبيب أو تخصص...",
                        hintStyle: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 16,
                        ),
                        prefixIcon: Icon(
                          Icons.search,
                          color: Colors.grey[500],
                        ),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: Icon(
                                  Icons.clear,
                                  color: Colors.grey[500],
                                ),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() {
                                    _searchResults = [];
                                    _isSearching = false;
                                  });
                                },
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 16,
                        ),
                      ),
                    ),
                  ),

                  // Search Results or Cards section
                  Expanded(
                    child: _searchController.text.trim().isNotEmpty
                        ? _buildSearchResults()
                        : _buildMainCards(),
                  ),
                  
                  // Technical Support Footer - في آخر الصفحة دائماً
                  GestureDetector(
                    onTap: _showTechnicalSupportDialog,
                    child: Container(
                      margin: const EdgeInsets.only(top: 16, bottom: 32),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.support_agent,
                                color: Colors.grey[600],
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Column(
                                children: [
                                  Text(
                                    "الدعم الفني",
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.grey[600],
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Container(
                                    width: 60,
                                    height: 1,
                                    color: Colors.grey[400],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMainCards() {
    return SingleChildScrollView(
      child: Column(
        children: [
          // Medical Facilities Card
          _buildCard(
            title: "المرافق الطبية",
            subtitle: "استكشف المرافق والحجز",
            icon: Icons.medical_services,
            color: Colors.green,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const HospitalScreen(),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          // My Bookings Card
          _buildCard(
            title: "حجوزاتي",
            subtitle: "عرض وإدارة حجوزاتك",
            icon: Icons.calendar_today,
            color: const Color(0xFF2FBDAF),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const PatientBookingsScreen(),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          
          
          
          // Home Clinic Card
          _buildCard(
            title: "العيادة المنزلية",
            subtitle: "خدمات طبية منزلية",
            icon: Icons.local_hospital,
            color: Colors.orange,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const HomeClinicScreen(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults() {
    if (_isSearching) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2FBDAF)),
        ),
      );
    }

    if (_searchResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'لم يتم العثور على نتائج',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'جرب البحث بكلمات مختلفة',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final result = _searchResults[index];
        return _buildSearchResultItem(result);
      },
    );
  }

  Widget _buildSearchResultItem(Map<String, dynamic> result) {
    final type = result['type'] as String;
    final name = result['name'] as String;
    
    String specialty = '';
    String center = '';
    
    if (type == 'doctor') {
      specialty = result['specialization'] ?? 'غير محدد';
      center = result['centerName'] ?? 'غير محدد';
    } else if (type == 'specialty') {
      specialty = name;
      center = 'متاح في جميع المراكز';
    } else if (type == 'facility') {
      specialty = 'مركز طبي';
      center = name;
    }

    return GestureDetector(
      onTap: () {
        if (type == 'doctor') {
          // طباعة بيانات الطبيب للتأكد
          print('=== بيانات الطبيب ===');
          print('الاسم: ${result['name']}');
          print('workingSchedule: ${result['workingSchedule']}');
          print('facilityId: ${result['facilityId']}');
          print('specializationId: ${result['specializationId']}');
          print('doctorId: ${result['id']}');
          print('==================');
          
          // التأكد من وجود workingSchedule
          Map<String, dynamic> schedule = result['workingSchedule'] ?? {};
          if (schedule.isEmpty) {
            print('تحذير: workingSchedule فارغ!');
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('خطأ: لا يوجد جدول عمل للطبيب'),
                backgroundColor: Colors.red,
              ),
            );
            return;
          }
          
          // التنقل لصفحة الحجز الأصلية مع بيانات الطبيب
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => BookingScreen(
                name: result['name'],
                workingSchedule: schedule,
                facilityId: result['facilityId'] ?? '',
                specializationId: result['specializationId'] ?? '',
                doctorId: result['id'],
                showDoctorInfo: true, // عرض معلومات الطبيب
                doctorSpecialty: result['specialization'] ?? '',
                centerName: result['centerName'] ?? '',
              ),
            ),
          );
        } else {
          // عرض رسالة للتخصصات والمراكز
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('تم اختيار: $name'),
              duration: const Duration(seconds: 2),
              backgroundColor: const Color(0xFF2FBDAF),
            ),
          );
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Profile Icon
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.person,
                  color: Color(0xFF2FBDAF),
                  size: 18,
                ),
              ),
              const SizedBox(width: 16),
              
              // Text Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Doctor Name
                    Text(
                      name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    
                    // Specialty
                    Text(
                      'التخصص : $specialty',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 2),
                    
                    // Center
                    Text(
                      'المركز : $center',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              
              // Arrow Icon
              Icon(
                Icons.arrow_forward_ios,
                color: const Color(0xFF2FBDAF),
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.2),
              spreadRadius: 2,
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  icon,
                  size: 32,
                  color: color,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                color: color,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class DoctorBookingLoaderTemp extends StatefulWidget {
  final String name;
  final String? facilityId;
  final String? specializationId;
  final String? centralDoctorId;
  const DoctorBookingLoaderTemp({super.key, required this.name, this.facilityId, this.specializationId, this.centralDoctorId});

  @override
  State<DoctorBookingLoaderTemp> createState() => _DoctorBookingLoaderTempState();
}

class _DoctorBookingLoaderTempState extends State<DoctorBookingLoaderTemp> {
  @override
  void initState() {
    super.initState();
    _resolveAndOpen();
  }

  String _normalizeName(String s) {
    final map = {'أ':'ا','إ':'ا','آ':'ا','ة':'ه','ى':'ي','ئ':'ي','ؤ':'و','ـ':'','ً':'','ٌ':'','ٍ':'','َ':'','ُ':'','ِ':'','ّ':''};
    String out = s.trim();
    map.forEach((k,v){ out = out.replaceAll(k,v); });
    out = out.replaceAll(RegExp(r"[^\u0600-\u06FFa-zA-Z0-9 ]"), '');
    out = out.replaceAll(RegExp(r"\s+"), ' ');
    return out.toLowerCase();
  }

  Future<void> _resolveAndOpen() async {
    final base = widget.name.trim();
    final candidates = <String>{
      base,
      base.startsWith('د') ? base : 'د. $base',
      base.startsWith('د') ? base : 'د.$base',
      base.replaceAll('د. ', 'د.').replaceAll('  ', ' '),
    };
    final target = _normalizeName(base.startsWith('د') ? base.substring(1) : base);

    try {
      // 0) Try same logic as search bar using CentralDataService
      try {
        final results = await CentralDataService.searchDoctorsAndSpecialties(base);
        Map<String, dynamic>? match;
        for (final r in results) {
          if ((r['type'] == 'doctor') && _normalizeName(r['name'] ?? '') == target) {
            match = r; break;
          }
        }
        match ??= results.cast<Map<String, dynamic>?>().firstWhere(
          (r) => (r?['type'] == 'doctor') && _normalizeName(r?['name'] ?? '').contains(target),
          orElse: () => null,
        );
        if (match != null && match.isNotEmpty) {
          final schedule = match['workingSchedule'] as Map<String, dynamic>? ?? {};
          if (schedule.isNotEmpty && mounted) {
            final facilityId = (match['facilityId'] ?? '').toString();
            final specializationId = (match['specializationId'] ?? '').toString();
            final doctorId = (match['id'] ?? '').toString();
            final centerName = (match['centerName'] ?? '').toString();
            final specName = (match['specialization'] ?? '').toString();
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (_) => BookingScreen(
                  name: (match?['name'] ?? base).toString(),
                  workingSchedule: schedule,
                  facilityId: facilityId,
                  specializationId: specializationId,
                  doctorId: doctorId,
                  showDoctorInfo: true,
                  doctorSpecialty: specName,
                  centerName: centerName,
                ),
              ),
            );
            return;
          }
        }
      } catch (_) {}

      QueryDocumentSnapshot? hit;
      // Prefer narrow search in provided path
      if ((widget.facilityId ?? '').isNotEmpty) {
        if ((widget.specializationId ?? '').isNotEmpty) {
          final docs = await FirebaseFirestore.instance
              .collection('medicalFacilities')
              .doc(widget.facilityId)
              .collection('specializations')
              .doc(widget.specializationId)
              .collection('doctors')
              .get();
          for (final d in docs.docs) {
            final data = d.data() as Map<String, dynamic>;
            final n = (data['docName'] ?? '').toString();
            final centralId = (data['centralDoctorId'] ?? '').toString();
            if (_normalizeName(n) == target || (widget.centralDoctorId ?? '') == centralId) { hit = d; break; }
          }
        } else {
          // Iterate all specializations under the facility
          final specs = await FirebaseFirestore.instance
              .collection('medicalFacilities')
              .doc(widget.facilityId)
              .collection('specializations')
              .get();
          for (final s in specs.docs) {
            final docs = await FirebaseFirestore.instance
                .collection('medicalFacilities')
                .doc(widget.facilityId)
                .collection('specializations')
                .doc(s.id)
                .collection('doctors')
                .get();
            for (final d in docs.docs) {
              final data = d.data() as Map<String, dynamic>;
              final n = (data['docName'] ?? '').toString();
              final centralId = (data['centralDoctorId'] ?? '').toString();
              if (_normalizeName(n) == target || (widget.centralDoctorId ?? '') == centralId) { hit = d; break; }
            }
            if (hit != null) break;
          }
        }
      }

      // If still not found and we have centralDoctorId, search by it
      if (hit == null && (widget.centralDoctorId ?? '').isNotEmpty) {
        final cgCentral = await FirebaseFirestore.instance
            .collectionGroup('doctors')
            .where('centralDoctorId', isEqualTo: widget.centralDoctorId)
            .limit(1)
            .get();
        if (cgCentral.docs.isNotEmpty) hit = cgCentral.docs.first;
      }
      // Try exact candidates
      for (final c in candidates) {
        final cgTry = await FirebaseFirestore.instance
            .collectionGroup('doctors')
            .where('docName', isEqualTo: c)
            .limit(1)
            .get();
        if (cgTry.docs.isNotEmpty) { hit = cgTry.docs.first; break; }
      }
      // Fallback: normalize compare (scan bigger window)
      if (hit == null) {
        final cg2 = await FirebaseFirestore.instance
            .collectionGroup('doctors')
            .limit(2000)
            .get();
        for (final d in cg2.docs) {
          final n = (d.data()['docName'] ?? '').toString();
          final norm = _normalizeName(n);
          if (norm == target || norm.contains(target) || target.contains(norm)) { hit = d; break; }
        }
      }

      if (hit != null) {
        final data = hit.data() as Map<String, dynamic>;
        final schedule = data['workingSchedule'] as Map<String, dynamic>? ?? {};
        if (schedule.isEmpty) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('لا يوجد جدول عمل للطبيب'), backgroundColor: Colors.red),
            );
          }
          Navigator.of(context).pop();
          return;
        }

        // Derive facility and specialization from path
        final doctorRef = hit.reference; // .../specializations/{specId}/doctors/{docId}
        final specRef = doctorRef.parent.parent!; // specializations/{specId}
        final facilityRef = specRef.parent.parent!; // root/{facilityId}
        final specSnap = await specRef.get();
        final facilitySnap = await facilityRef.get();
        final specName = (specSnap.data() as Map<String, dynamic>?)?['specName']?.toString() ?? '';
        final centerName = (facilitySnap.data() as Map<String, dynamic>?)?['name']?.toString() ?? '';

        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => BookingScreen(
              name: (data['docName'] ?? base).toString(),
              workingSchedule: schedule,
              facilityId: facilityRef.id,
              specializationId: specRef.id,
              doctorId: doctorRef.id,
              showDoctorInfo: true,
              doctorSpecialty: specName, // pass specialization name instead of id
              centerName: centerName,
            ),
          ),
        );
        return;
      }
    } catch (_) {}

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('لم يتم العثور على الطبيب: ${widget.name}'), backgroundColor: Colors.red),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2FBDAF))),
      ),
    );
  }
}
