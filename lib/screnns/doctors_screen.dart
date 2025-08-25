import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:hospital_app/screnns/booking_screen.dart';
import 'package:hospital_app/widgets/optimized_loading_widget.dart';

class DoctorsScreen extends StatefulWidget {
  final String facilityId;
  final String specId;

  const DoctorsScreen({
    super.key,
    required this.facilityId,
    required this.specId,
  });

  @override
  State<DoctorsScreen> createState() => _DoctorsScreenState();
}

class _DoctorsScreenState extends State<DoctorsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  List<QueryDocumentSnapshot> _allDoctors = [];
  bool _isSearching = false;
  Stream<QuerySnapshot>? _doctorsStream;

  Future<List<QueryDocumentSnapshot>> fetchDoctorsOnce() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('medicalFacilities')
          .doc(widget.facilityId)
          .collection('specializations')
          .doc(widget.specId)
          .collection('doctors')
          .get()
          .timeout(const Duration(seconds: 8));
      _allDoctors = snapshot.docs;
      return snapshot.docs;
    } catch (e) {
      print('خطأ في تحميل الأطباء: $e');
      return [];
    }
  }

  @override
  void initState() {
    super.initState();
    _doctorsStream = FirebaseFirestore.instance
        .collection('medicalFacilities')
        .doc(widget.facilityId)
        .collection('specializations')
        .doc(widget.specId)
        .collection('doctors')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  List<QueryDocumentSnapshot> getFilteredDoctors() {
    if (_searchQuery.isEmpty) {
      return _allDoctors;
    }
    
    return _allDoctors.where((doctor) {
      final data = doctor.data() as Map<String, dynamic>;
      final doctorName = data['docName']?.toString().toLowerCase() ?? '';
      final searchLower = _searchQuery.toLowerCase();
      
      return doctorName.contains(searchLower);
    }).toList();
  }

  String _getWorkingDaysText(dynamic workingSchedule) {
    if (workingSchedule == null || workingSchedule.isEmpty) {
      return 'أيام العمل: غير محدد';
    }

    // تحويل إلى Map إذا لم يكن كذلك
    Map<String, dynamic> scheduleMap;
    if (workingSchedule is Map) {
      scheduleMap = Map<String, dynamic>.from(workingSchedule);
    } else {
      return 'أيام العمل: غير محدد';
    }

    List<String> workingDays = [];
    
    scheduleMap.forEach((day, value) {
      // التحقق من أن اليوم موجود في قائمة الأيام العربية
      if (day is String && (day == 'الأحد' || day == 'الاثنين' || day == 'الثلاثاء' || 
                           day == 'الأربعاء' || day == 'الخميس' || day == 'الجمعة' || day == 'السبت')) {
        // إذا كان اليوم موجود في الجدول، فهو يوم عمل
        workingDays.add(day);
      }
    });

    if (workingDays.isEmpty) {
      return 'أيام العمل: غير محدد';
    }

    // ترتيب الأيام حسب ترتيبها في الأسبوع
    final dayOrder = ['الأحد', 'الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت'];
    workingDays.sort((a, b) => dayOrder.indexOf(a).compareTo(dayOrder.indexOf(b)));

    // إذا كان عدد الأيام أكثر من 4، نقسمها على سطرين
    String result;
    if (workingDays.length > 4) {
      final firstLine = workingDays.take(4).join(' - ');
      final secondLine = workingDays.skip(4).join(' - ');
      result = 'أيام العمل:\n$firstLine\n$secondLine';
    } else {
      result = 'أيام العمل: ${workingDays.join(' - ')}';
    }
    
    return result;
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          actions: [
            _isSearching
                ? IconButton(
                    onPressed: () {
                      setState(() {
                        _isSearching = false;
                        _searchQuery = '';
                        _searchController.clear();
                      });
                    },
                    icon: Icon(Icons.close, color: Color(0xFF2FBDAF)),
                  )
                : IconButton(
                    onPressed: () {
                      setState(() {
                        _isSearching = true;
                      });
                    },
                    icon: Icon(Icons.search, color: Color(0xFF2FBDAF)),
                  ),
          ],
          title: _isSearching
              ? TextField(
                  controller: _searchController,
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: 'البحث عن طبيب...',
                    border: InputBorder.none,
                    hintStyle: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 16,
                    ),
                  ),
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 16,
                  ),
                )
              : Text(
                  "الأطباء",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2FBDAF),
                    fontSize: 30,
                  ),
                ),
        ),
        body: SafeArea(
          child: StreamBuilder<QuerySnapshot>(
            stream: _doctorsStream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const OptimizedLoadingWidget(
                  message: 'جاري تحميل الأطباء...',
                  color: Color(0xFF2FBDAF),
                );
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.medical_services_outlined,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'لا يوجد أطباء حالياً',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                );
              }

              _allDoctors = snapshot.data!.docs;
              final doctors = _searchQuery.isEmpty ? _allDoctors : getFilteredDoctors();
              
              if (_searchQuery.isNotEmpty && doctors.isEmpty) {
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
                        'لا يوجد أطباء تطابق البحث',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                itemCount: doctors.length,
                itemBuilder: (context, index) {
                  final doc = doctors[index];
                  final doctorData = doc.data() as Map<String, dynamic>;
                  final doctorName = doctorData['docName'] ?? 'طبيب غير معروف';
                  final dynamic rawPhoto = doctorData['photoUrl'];
                  final String photoUrl = (rawPhoto is String) ? rawPhoto.trim() : '';
                  final bool hasValidPhoto = photoUrl.startsWith('http');
                  const String fallbackUrl = 'https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcQupVHd_oeqnkds0k3EjT1SX4ctwwblwYP2Uw&s';
                  final String effectiveUrl = hasValidPhoto ? photoUrl : fallbackUrl;
                  

                  


                  return GestureDetector(
                    key: ValueKey(doc.id),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder:
                              (context) => BookingScreen(
                                facilityId: widget.facilityId,
                                specializationId: widget.specId,
                                doctorId: doc.id,
                                name: doctorName,
                                workingSchedule: Map<String, dynamic>.from(
                                  (doc.data() as Map<String, dynamic>)['workingSchedule'] ?? {},
                                ),
                              ),
                        ),
                      );
                    },
                    child: Card(
                      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      elevation: 6,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(50),
                              child: Image.network(
                                effectiveUrl,
                                width: 60,
                                height: 60,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stack) {
                                  return Container(
                                    width: 60,
                                    height: 60,
                                    color: Colors.grey[300],
                                    child: const Icon(Icons.person, color: Colors.grey),
                                  );
                                },
                              ),
                            ),
                            SizedBox(width: 16),

                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    doctorName,
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    _getWorkingDaysText(doctorData['workingSchedule'] ?? {}),
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 12,
                                      fontWeight: FontWeight.w400,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.arrow_forward_ios,
                              color: Colors.grey[600],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
