import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:hospital_app/screnns/admin_doctor_details_screen.dart';
import 'package:hospital_app/screnns/add_doctor_screen.dart';
import 'package:hospital_app/widgets/optimized_loading_widget.dart';

class AdminDoctorsScreen extends StatefulWidget {
  final String? centerId;
  final String? centerName;

  const AdminDoctorsScreen({
    super.key,
    this.centerId,
    this.centerName,
  });

  @override
  State<AdminDoctorsScreen> createState() => _AdminDoctorsScreenState();
}

class _AdminDoctorsScreenState extends State<AdminDoctorsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  Future<List<Map<String, dynamic>>> fetchDoctors() async {
    if (widget.centerId == null) return [];
    
    try {
      // جلب جميع الأطباء من جميع التخصصات
      final snapshot = await FirebaseFirestore.instance
          .collection('medicalFacilities')
          .doc(widget.centerId)
          .collection('specializations')
          .get()
          .timeout(const Duration(seconds: 8));

      List<Map<String, dynamic>> allDoctors = [];
      
      // البحث في كل تخصص
      for (var specDoc in snapshot.docs) {
        final specializationData = specDoc.data();
        final specializationName = specializationData['specName'] ?? specDoc.id;
        
        final doctorsSnapshot = await FirebaseFirestore.instance
            .collection('medicalFacilities')
            .doc(widget.centerId)
            .collection('specializations')
            .doc(specDoc.id)
            .collection('doctors')
            .get()
            .timeout(const Duration(seconds: 8));
        
        for (var doctorDoc in doctorsSnapshot.docs) {
          final doctorData = doctorDoc.data();
          // إضافة اسم التخصص لكل طبيب
          doctorData['specialization'] = specializationName;
          doctorData['doctorId'] = doctorDoc.id;
          doctorData['specializationId'] = specDoc.id;
          allDoctors.add(doctorData);
        }
      }
      
      return allDoctors;
    } catch (e) {
      print('خطأ في تحميل الأطباء: $e');
      return [];
    }
  }

  List<Map<String, dynamic>> filterDoctors(List<Map<String, dynamic>> doctors) {
    if (_searchQuery.isEmpty) return doctors;
    
    return doctors.where((doctorData) {
      final doctorName = doctorData['docName']?.toString().toLowerCase() ?? '';
      final specialization = doctorData['specialization']?.toString().toLowerCase() ?? '';
      
      return doctorName.contains(_searchQuery.toLowerCase()) ||
             specialization.contains(_searchQuery.toLowerCase());
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            "إدارة الأطباء",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.white,
              fontSize: 24,
            ),
          ),
          backgroundColor: const Color.fromARGB(255, 78, 17, 175),
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        body: Container(
          color: Colors.grey[50],
          child: Column(
            children: [
              // Search and Add section
              Container(
                padding: const EdgeInsets.all(16),
                color: Colors.white,
                child: Column(
                  children: [
                    // Search bar
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: TextField(
                        controller: _searchController,
                        onChanged: (value) {
                          setState(() {
                            _searchQuery = value;
                          });
                        },
                        decoration: InputDecoration(
                          hintText: 'البحث عن طبيب...',
                          prefixIcon: Icon(Icons.search, color: Colors.grey[600]),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Add doctor button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          _showAddDoctorDialog(context);
                        },
                        icon: Icon(Icons.add),
                        label: Text('إضافة طبيب جديد'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color.fromARGB(255, 78, 17, 175),
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
                             // Doctors list
               Expanded(
                 child: FutureBuilder<List<Map<String, dynamic>>>(
                   future: fetchDoctors(),
                   builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const OptimizedLoadingWidget(
                        message: 'جاري تحميل الأطباء...',
                        color: Color.fromARGB(255, 78, 17, 175),
                      );
                    }

                    if (snapshot.hasError) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.error_outline,
                              size: 64,
                              color: Colors.red[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'حدث خطأ في تحميل البيانات',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 8),
                            ElevatedButton(
                              onPressed: () {
                                setState(() {
                                  // Refresh the data
                                });
                              },
                              child: Text('إعادة المحاولة'),
                            ),
                          ],
                        ),
                      );
                    }

                    if (!snapshot.hasData || snapshot.data!.isEmpty) {
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
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'اضغط على "إضافة طبيب جديد" لإضافة أول طبيب',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[500],
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      );
                    }

                    final allDoctors = snapshot.data!;
                    final filteredDoctors = filterDoctors(allDoctors);

                    if (filteredDoctors.isEmpty) {
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
                              'لا توجد نتائج للبحث',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.grey[600],
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
                       padding: EdgeInsets.all(16),
                       itemCount: filteredDoctors.length,
                       itemBuilder: (context, index) {
                         final doctorData = filteredDoctors[index];
                         
                         // استخراج بيانات الطبيب من قاعدة البيانات
                         final doctorName = doctorData['docName'] ?? 'طبيب غير معروف';
                         final specialization = doctorData['specialization'] ?? 'غير محدد';
                         final photoUrl = doctorData['photoUrl'] ?? 
                             'https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcQupVHd_oeqnkds0k3EjT1SX4ctwwblwYP2Uw&s';
                         final doctorId = doctorData['doctorId'] ?? '';

                         return Card(
                           margin: EdgeInsets.only(bottom: 12),
                           elevation: 2,
                           shape: RoundedRectangleBorder(
                             borderRadius: BorderRadius.circular(12),
                           ),
                           child: ListTile(
                             contentPadding: EdgeInsets.all(16),
                             leading: CircleAvatar(
                               radius: 30,
                               backgroundImage: NetworkImage(photoUrl),
                               onBackgroundImageError: (exception, stackTrace) {
                                 // Handle image error
                               },
                             ),
                             title: Column(
                               crossAxisAlignment: CrossAxisAlignment.start,
                               children: [
                                 Text(
                                   doctorName,
                                   style: TextStyle(
                                     fontSize: 18,
                                     fontWeight: FontWeight.bold,
                                     color: Colors.black87,
                                   ),
                                 ),
                                 const SizedBox(height: 4),
                                 Container(
                                   padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                   decoration: BoxDecoration(
                                     color: const Color.fromARGB(255, 78, 17, 175).withOpacity(0.1),
                                     borderRadius: BorderRadius.circular(12),
                                   ),
                                   child: Text(
                                     specialization,
                                     style: TextStyle(
                                       fontSize: 12,
                                       color: const Color.fromARGB(255, 78, 17, 175),
                                       fontWeight: FontWeight.w600,
                                     ),
                                   ),
                                 ),
                               ],
                             ),
                             trailing: Icon(
                               Icons.arrow_forward_ios,
                               color: Colors.grey[400],
                               size: 20,
                             ),
                             onTap: () {
                               Navigator.push(
                                 context,
                                 MaterialPageRoute(
                                   builder: (context) => AdminDoctorDetailsScreen(
                                     doctorId: doctorId,
                                     centerId: widget.centerId!,
                                     centerName: widget.centerName,
                                   ),
                                 ),
                               );
                             },
                           ),
                         );
                       },
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

  void _showAddDoctorDialog(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddDoctorScreen(
          centerId: widget.centerId!,
          centerName: widget.centerName,
        ),
      ),
    ).then((result) {
      // تحديث القائمة إذا تم إضافة طبيب جديد
      if (result == true) {
        setState(() {
          // إعادة تحميل البيانات
        });
      }
    });
  }
}
