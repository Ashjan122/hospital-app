import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AdminDoctorDetailsScreen extends StatefulWidget {
  final String doctorId;
  final String centerId;
  final String? centerName;

  const AdminDoctorDetailsScreen({
    super.key,
    required this.doctorId,
    required this.centerId,
    this.centerName,
  });

  @override
  State<AdminDoctorDetailsScreen> createState() => _AdminDoctorDetailsScreenState();
}

class _AdminDoctorDetailsScreenState extends State<AdminDoctorDetailsScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  bool _isEditing = false;
  bool _isLoading = false;

  Future<Map<String, dynamic>?> fetchDoctorDetails() async {
    try {
      // البحث عن الطبيب في جميع التخصصات
      final specializationsSnapshot = await FirebaseFirestore.instance
          .collection('medicalFacilities')
          .doc(widget.centerId)
          .collection('specializations')
          .get();

      for (var specDoc in specializationsSnapshot.docs) {
        final doctorDoc = await FirebaseFirestore.instance
            .collection('medicalFacilities')
            .doc(widget.centerId)
            .collection('specializations')
            .doc(specDoc.id)
            .collection('doctors')
            .doc(widget.doctorId)
            .get();

        if (doctorDoc.exists) {
          final doctorData = doctorDoc.data()!;
          // إضافة اسم التخصص للبيانات
          final specializationData = specDoc.data();
          doctorData['specialization'] = specializationData['specName'] ?? specDoc.id;
          doctorData['specializationId'] = specDoc.id;
          return doctorData;
        }
      }
      
      return null;
    } catch (e) {
      print('Error fetching doctor details: $e');
      return null;
    }
  }

  Future<void> updateDoctorData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // البحث عن الطبيب في جميع التخصصات
      final specializationsSnapshot = await FirebaseFirestore.instance
          .collection('medicalFacilities')
          .doc(widget.centerId)
          .collection('specializations')
          .get();

      for (var specDoc in specializationsSnapshot.docs) {
        final doctorDoc = await FirebaseFirestore.instance
            .collection('medicalFacilities')
            .doc(widget.centerId)
            .collection('specializations')
            .doc(specDoc.id)
            .collection('doctors')
            .doc(widget.doctorId)
            .get();

        if (doctorDoc.exists) {
          // تحديث البيانات
          await FirebaseFirestore.instance
              .collection('medicalFacilities')
              .doc(widget.centerId)
              .collection('specializations')
              .doc(specDoc.id)
              .collection('doctors')
              .doc(widget.doctorId)
              .update({
            'docName': _nameController.text.trim(),
            'phoneNumber': _phoneController.text.trim(),
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('تم تحديث بيانات الطبيب بنجاح'),
              backgroundColor: Colors.green,
            ),
          );

          setState(() {
            _isEditing = false;
          });
          break;
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('حدث خطأ في تحديث البيانات'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> toggleDoctorStatus(bool isActive) async {
    setState(() {
      _isLoading = true;
    });

    try {
      // البحث عن الطبيب في جميع التخصصات
      final specializationsSnapshot = await FirebaseFirestore.instance
          .collection('medicalFacilities')
          .doc(widget.centerId)
          .collection('specializations')
          .get();

      for (var specDoc in specializationsSnapshot.docs) {
        final doctorDoc = await FirebaseFirestore.instance
            .collection('medicalFacilities')
            .doc(widget.centerId)
            .collection('specializations')
            .doc(specDoc.id)
            .collection('doctors')
            .doc(widget.doctorId)
            .get();

        if (doctorDoc.exists) {
          // تحديث حالة الطبيب
          await FirebaseFirestore.instance
              .collection('medicalFacilities')
              .doc(widget.centerId)
              .collection('specializations')
              .doc(specDoc.id)
              .collection('doctors')
              .doc(widget.doctorId)
              .update({
            'isActive': isActive,
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(isActive ? 'تم تفعيل الطبيب' : 'تم تعطيل الطبيب'),
              backgroundColor: Colors.green,
            ),
          );
          break;
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('حدث خطأ في تحديث حالة الطبيب'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showImagePickerDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('تغيير صورة الطبيب'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.camera_alt, color: const Color.fromARGB(255, 78, 17, 175)),
                title: Text('التقاط صورة من الكاميرا'),
                onTap: () {
                  Navigator.of(context).pop();
                  _pickImageFromCamera();
                },
              ),
              ListTile(
                leading: Icon(Icons.photo_library, color: const Color.fromARGB(255, 78, 17, 175)),
                title: Text('اختيار من المعرض'),
                onTap: () {
                  Navigator.of(context).pop();
                  _pickImageFromGallery();
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('إلغاء'),
            ),
          ],
        );
      },
    );
  }

  void _pickImageFromCamera() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('ميزة التقاط الصورة من الكاميرا قريباً'),
        backgroundColor: const Color.fromARGB(255, 78, 17, 175),
      ),
    );
  }

  void _pickImageFromGallery() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('ميزة اختيار الصورة من المعرض قريباً'),
        backgroundColor: const Color.fromARGB(255, 78, 17, 175),
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
            "تفاصيل الطبيب",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.white,
              fontSize: 24,
            ),
          ),
          backgroundColor: const Color.fromARGB(255, 78, 17, 175),
          foregroundColor: Colors.white,
          elevation: 0,
          actions: [
            IconButton(
              icon: Icon(_isEditing ? Icons.save : Icons.edit),
              onPressed: _isLoading ? null : () {
                if (_isEditing) {
                  updateDoctorData();
                } else {
                  setState(() {
                    _isEditing = true;
                  });
                }
              },
            ),
          ],
        ),
        body: FutureBuilder<Map<String, dynamic>?>(
          future: fetchDoctorDetails(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      color: const Color.fromARGB(255, 78, 17, 175),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'جاري تحميل بيانات الطبيب...',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
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
                  ],
                ),
              );
            }

            if (!snapshot.hasData || snapshot.data == null) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 64,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'لم يتم العثور على بيانات الطبيب',
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              );
            }

            final doctorData = snapshot.data!;
            
            // استخراج بيانات الطبيب من قاعدة البيانات
            final doctorName = doctorData['docName'] ?? 'طبيب غير معروف';
            final specialization = doctorData['specialization'] ?? 'غير محدد';
            final photoUrl = doctorData['photoUrl'] ?? 
                'https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcQupVHd_oeqnkds0k3EjT1SX4ctwwblwYP2Uw&s';
            final phoneNumber = doctorData['phoneNumber'] ?? 'غير متوفر';
            final isActive = doctorData['isActive'] ?? true;

            // تعيين القيم في controllers إذا لم تكن محددة
            if (!_isEditing) {
              _nameController.text = doctorName;
              _phoneController.text = phoneNumber;
            }

            return SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Doctor profile card
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.1),
                          spreadRadius: 1,
                          blurRadius: 10,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // Profile image
                        Stack(
                          children: [
                            CircleAvatar(
                              radius: 60,
                              backgroundImage: NetworkImage(photoUrl),
                              onBackgroundImageError: (exception, stackTrace) {
                                // Handle image error
                              },
                            ),
                            if (_isEditing)
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: const Color.fromARGB(255, 78, 17, 175),
                                    shape: BoxShape.circle,
                                  ),
                                  child: IconButton(
                                    icon: Icon(Icons.camera_alt, color: Colors.white, size: 20),
                                    onPressed: () {
                                      _showImagePickerDialog(context);
                                    },
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        
                        // Doctor name
                        if (_isEditing)
                          TextField(
                            controller: _nameController,
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                            textAlign: TextAlign.center,
                            decoration: InputDecoration(
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            ),
                          )
                        else
                          Text(
                            doctorName,
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        const SizedBox(height: 8),
                        
                        // Specialization
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color.fromARGB(255, 78, 17, 175).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            specialization,
                            style: TextStyle(
                              fontSize: 16,
                              color: const Color.fromARGB(255, 78, 17, 175),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Contact information
                  _buildInfoSection(
                    'معلومات التواصل',
                    [
                      if (_isEditing)
                        _buildEditableInfoRow(Icons.phone, 'رقم الهاتف', _phoneController)
                      else
                        _buildInfoRow(Icons.phone, 'رقم الهاتف', phoneNumber),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Status indicator
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isActive ? Colors.green[50] : Colors.red[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isActive ? Colors.green[200]! : Colors.red[200]!,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isActive ? Icons.check_circle : Icons.cancel,
                          color: isActive ? Colors.green : Colors.red,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          isActive ? 'الطبيب نشط' : 'الطبيب معطل',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: isActive ? Colors.green[700] : Colors.red[700],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Action buttons
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _isLoading ? null : () {
                            toggleDoctorStatus(!isActive);
                          },
                          icon: Icon(isActive ? Icons.block : Icons.check_circle),
                          label: Text(isActive ? 'تعطيل الطبيب' : 'تفعيل الطبيب'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isActive ? Colors.red : Colors.green,
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
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildInfoSection(String title, List<Widget> children) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
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
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color.fromARGB(255, 78, 17, 175).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: const Color.fromARGB(255, 78, 17, 175),
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.black87,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditableInfoRow(IconData icon, String label, TextEditingController controller) {
    return Padding(
      padding: EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color.fromARGB(255, 78, 17, 175).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: const Color.fromARGB(255, 78, 17, 175),
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                TextField(
                  controller: controller,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.black87,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
