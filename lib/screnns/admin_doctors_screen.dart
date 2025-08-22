import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'admin_doctor_details_screen.dart';
import 'add_doctor_screen.dart';

class AdminDoctorsScreen extends StatefulWidget {
  final String? centerId;
  final String? centerName;

  const AdminDoctorsScreen({
    super.key,
    required this.centerId,
    required this.centerName,
  });

  @override
  State<AdminDoctorsScreen> createState() => _AdminDoctorsScreenState();
}

class _AdminDoctorsScreenState extends State<AdminDoctorsScreen> {
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<List<Map<String, dynamic>>> fetchDoctors() async {
    if (widget.centerId == null) return [];

    try {
      // جلب جميع التخصصات
      final specializationsSnapshot = await FirebaseFirestore.instance
          .collection('medicalFacilities')
          .doc(widget.centerId)
          .collection('specializations')
          .get();

      List<Map<String, dynamic>> allDoctors = [];
      
      // البحث في كل تخصص
      for (var specDoc in specializationsSnapshot.docs) {
        final specializationData = specDoc.data();
        final specializationName = specializationData['specName'] ?? specDoc.id;
        
        final doctorsSnapshot = await FirebaseFirestore.instance
            .collection('medicalFacilities')
            .doc(widget.centerId)
            .collection('specializations')
            .doc(specDoc.id)
            .collection('doctors')
            .get();
        
        for (var doctorDoc in doctorsSnapshot.docs) {
          final doctorData = doctorDoc.data();
          final doctorId = doctorDoc.id;
          
          // جلب معلومات الطبيب من قاعدة البيانات المركزية
          String doctorName = 'طبيب غير معروف';
          String doctorPhone = '';
          String photoUrl = 'https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcQupVHd_oeqnkds0k3EjT1SX4ctwwblwYP2Uw&s';
          
          try {
            final centralDoctorDoc = await FirebaseFirestore.instance
                .collection('allDoctors')
                .doc(doctorId)
                .get();
            
            if (centralDoctorDoc.exists) {
              final centralDoctorData = centralDoctorDoc.data()!;
              doctorName = centralDoctorData['name'] ?? 'طبيب غير معروف';
              doctorPhone = centralDoctorData['phoneNumber'] ?? '';
              photoUrl = centralDoctorData['photoUrl'] ?? photoUrl;
            }
          } catch (e) {
            // إذا فشل في جلب البيانات من المركزية، استخدم المعرف
            doctorName = doctorId;
          }
          
          // إضافة معلومات إضافية لكل طبيب
          doctorData['name'] = doctorName;
          doctorData['phoneNumber'] = doctorPhone;
          doctorData['photoUrl'] = photoUrl;
          doctorData['specialization'] = specializationName;
          doctorData['doctorId'] = doctorId;
          doctorData['specializationId'] = specDoc.id;
          allDoctors.add(doctorData);
        }
      }
      
      return allDoctors;
    } catch (e) {
      // Error fetching doctors
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            'إدارة الأطباء - ${widget.centerName ?? 'المركز الطبي'}',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          backgroundColor: const Color.fromARGB(255, 78, 17, 175),
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        body: SafeArea(
          child: Container(
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
                        return const Center(
                          child: CircularProgressIndicator(
                            color: Color.fromARGB(255, 78, 17, 175),
                          ),
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

                      final doctors = snapshot.data ?? [];
                      
                      // Filter doctors based on search query
                      final filteredDoctors = doctors.where((doctor) {
                        final name = doctor['name']?.toString().toLowerCase() ?? '';
                        final specialization = doctor['specialization']?.toString().toLowerCase() ?? '';
                        final phone = doctor['phoneNumber']?.toString().toLowerCase() ?? '';
                        return name.contains(_searchQuery.toLowerCase()) ||
                               specialization.contains(_searchQuery.toLowerCase()) ||
                               phone.contains(_searchQuery.toLowerCase());
                      }).toList();

                      if (filteredDoctors.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                _searchQuery.isEmpty ? Icons.people : Icons.search_off,
                                size: 64,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _searchQuery.isEmpty 
                                    ? 'لا يوجد أطباء في هذا المركز'
                                    : 'لم يتم العثور على أطباء يطابقون البحث',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.grey[600],
                                ),
                              ),
                              if (_searchQuery.isEmpty) ...[
                                const SizedBox(height: 16),
                                ElevatedButton.icon(
                                  onPressed: () {
                                    _showAddDoctorDialog(context);
                                  },
                                  icon: Icon(Icons.add),
                                  label: Text('إضافة طبيب جديد'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color.fromARGB(255, 78, 17, 175),
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        );
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: filteredDoctors.length,
                        itemBuilder: (context, index) {
                          final doctorData = filteredDoctors[index];
                          final doctorName = doctorData['name'] ?? 'طبيب غير معروف';
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
                                backgroundImage: photoUrl.startsWith('http') 
                                    ? NetworkImage(photoUrl)
                                    : null,
                                backgroundColor: photoUrl.startsWith('http') 
                                    ? null 
                                    : Colors.grey[300],
                                child: photoUrl.startsWith('http') 
                                    ? null 
                                    : Icon(
                                        Icons.person,
                                        size: 30,
                                        color: Colors.grey[600],
                                      ),
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
                                      color: const Color.fromARGB(255, 78, 17, 175).withAlpha(26),
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
      if (result == true && mounted) {
        setState(() {
          // إعادة تحميل البيانات
        });
      }
    });
  }
}
