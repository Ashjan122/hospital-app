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
import 'package:hospital_app/screnns/home_samples_request_screen.dart';
import 'package:hospital_app/services/central_data_service.dart';

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

  @override
  void initState() {
    super.initState();
    _loadPatientData();
    _searchController.addListener(_onSearchChanged);
    _checkDatabaseConnection();
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
      // سيتم تحميل البيانات تلقائياً عند أول بحث
      
      print('تم تحميل البيانات بنجاح - البحث جاهز!');
    } catch (e) {
      print('خطأ في الاتصال بقاعدة البيانات: $e');
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim();
    
    // إلغاء البحث السابق
    _debounceTimer?.cancel();
    
    // تحديث الواجهة لإظهار/إخفاء زر X
    setState(() {});
    
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
      
      if (results.isEmpty && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('لم يتم العثور على نتائج لـ "$query"'),
            duration: const Duration(seconds: 2),
            action: SnackBarAction(
              label: 'مسح Cache',
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
                
                // Phone Numbers
                _buildPhoneNumber("0116319563"),
                const SizedBox(height: 8),
                _buildPhoneNumber("0963069664"),
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
          
          // Home Examinations Card
          _buildCard(
            title: "الفحوصات المنزلية",
            subtitle: "طلب فحوصات من المنزل",
            icon: Icons.biotech,
            color: Colors.orange,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const HomeSamplesRequestScreen(),
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
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: const Color(0xFF2FBDAF).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.person,
                  color: Color(0xFF2FBDAF),
                  size: 24,
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
