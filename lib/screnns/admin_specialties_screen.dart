import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AdminSpecialtiesScreen extends StatefulWidget {
  final String centerId;
  final String? centerName;

  const AdminSpecialtiesScreen({
    super.key,
    required this.centerId,
    this.centerName,
  });

  @override
  State<AdminSpecialtiesScreen> createState() => _AdminSpecialtiesScreenState();
}

class _AdminSpecialtiesScreenState extends State<AdminSpecialtiesScreen> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _newSpecialtyController = TextEditingController();
  String _searchQuery = '';
  bool _isLoading = false;

  @override
  void dispose() {
    _searchController.dispose();
    _newSpecialtyController.dispose();
    super.dispose();
  }

  Future<void> addSpecialty() async {
    final specialtyName = _newSpecialtyController.text.trim();
    if (specialtyName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى إدخال اسم التخصص'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // التحقق من عدم وجود تخصص بنفس الاسم
      final existingSpecialties = await FirebaseFirestore.instance
          .collection('medicalFacilities')
          .doc(widget.centerId)
          .collection('specializations')
          .where('specName', isEqualTo: specialtyName)
          .get();

      if (existingSpecialties.docs.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('يوجد تخصص بنفس الاسم بالفعل'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      // إضافة التخصص الجديد
      await FirebaseFirestore.instance
          .collection('medicalFacilities')
          .doc(widget.centerId)
          .collection('specializations')
          .add({
        'specName': specialtyName,
        'createdAt': FieldValue.serverTimestamp(),
        'isActive': true,
      });

      _newSpecialtyController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم إضافة التخصص بنجاح'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('حدث خطأ في إضافة التخصص: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> toggleSpecialtyStatus(String specialtyId, bool currentStatus) async {
    setState(() {
      _isLoading = true;
    });

    try {
      await FirebaseFirestore.instance
          .collection('medicalFacilities')
          .doc(widget.centerId)
          .collection('specializations')
          .doc(specialtyId)
          .update({
        'isActive': !currentStatus,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(!currentStatus ? 'تم تفعيل التخصص' : 'تم تعطيل التخصص'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('حدث خطأ في تحديث حالة التخصص'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }



  void _showAddSpecialtyDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إضافة تخصص جديد'),
        content: TextField(
          controller: _newSpecialtyController,
          decoration: const InputDecoration(
            labelText: 'اسم التخصص',
            border: OutlineInputBorder(),
          ),
          textDirection: TextDirection.rtl,
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _newSpecialtyController.clear();
            },
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              addSpecialty();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color.fromARGB(255, 78, 17, 175),
              foregroundColor: Colors.white,
            ),
            child: const Text('إضافة'),
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
            widget.centerName != null ? 'إدارة التخصصات - ${widget.centerName}' : 'إدارة التخصصات',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          backgroundColor: const Color.fromARGB(255, 78, 17, 175),
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        body: Column(
          children: [
            // Search and Add section
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.grey[50],
              child: Column(
                children: [
                  // Search bar
                  TextField(
                    controller: _searchController,
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value;
                      });
                    },
                    decoration: InputDecoration(
                      hintText: 'البحث في التخصصات...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Add specialty button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : _showAddSpecialtyDialog,
                      icon: const Icon(Icons.add),
                      label: const Text('إضافة تخصص جديد'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color.fromARGB(255, 78, 17, 175),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // Specialties list
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('medicalFacilities')
                    .doc(widget.centerId)
                    .collection('specializations')
                    .snapshots(),
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
                            'حدث خطأ في تحميل التخصصات',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  final specialties = snapshot.data?.docs ?? [];
                  
                  // Filter specialties based on search query
                  final filteredSpecialties = specialties.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final specName = data['specName']?.toString().toLowerCase() ?? '';
                    return specName.contains(_searchQuery.toLowerCase());
                  }).toList();

                  if (filteredSpecialties.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _searchQuery.isEmpty ? Icons.medical_services : Icons.search_off,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _searchQuery.isEmpty 
                                ? 'لا توجد تخصصات حالياً'
                                : 'لم يتم العثور على تخصصات تطابق البحث',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: filteredSpecialties.length,
                    itemBuilder: (context, index) {
                      final doc = filteredSpecialties[index];
                      final data = doc.data() as Map<String, dynamic>;
                      final specName = data['specName'] ?? 'تخصص غير معروف';
                      final isActive = data['isActive'] ?? true;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(16),
                          leading: Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color: const Color.fromARGB(255, 78, 17, 175).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(25),
                            ),
                            child: Icon(
                              Icons.medical_services,
                              color: const Color.fromARGB(255, 78, 17, 175),
                            ),
                          ),
                          title: Text(
                            specName,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(
                                    isActive ? Icons.check_circle : Icons.cancel,
                                    size: 16,
                                    color: isActive ? Colors.green : Colors.red,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    isActive ? 'نشط' : 'معطل',
                                    style: TextStyle(
                                      color: isActive ? Colors.green : Colors.red,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                                                     StreamBuilder<QuerySnapshot>(
                                     stream: FirebaseFirestore.instance
                                         .collection('medicalFacilities')
                                         .doc(widget.centerId)
                                         .collection('specializations')
                                         .doc(doc.id)
                                         .collection('doctors')
                                         .snapshots(),
                                     builder: (context, doctorsSnapshot) {
                                       int doctorsCount = 0;
                                       if (doctorsSnapshot.hasData) {
                                         doctorsCount = doctorsSnapshot.data!.docs.length;
                                       }
                                       
                                       return Row(
                                         children: [
                                           Icon(Icons.people, size: 16, color: Colors.grey[600]),
                                           const SizedBox(width: 4),
                                           Text(
                                             '$doctorsCount طبيب',
                                             style: TextStyle(
                                               color: Colors.grey[600],
                                               fontSize: 12,
                                             ),
                                           ),
                                         ],
                                       );
                                     },
                                   ),
                                ],
                              ),

                            ],
                          ),
                          trailing: PopupMenuButton<String>(
                            onSelected: (value) {
                              switch (value) {
                                case 'toggle':
                                  toggleSpecialtyStatus(doc.id, isActive);
                                  break;
                              }
                            },
                            itemBuilder: (context) => [
                              PopupMenuItem(
                                value: 'toggle',
                                child: Row(
                                  children: [
                                    Icon(
                                      isActive ? Icons.block : Icons.check_circle,
                                      color: isActive ? Colors.red : Colors.green,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(isActive ? 'تعطيل' : 'تفعيل'),
                                  ],
                                ),
                              ),
                            ],
                          ),
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
    );
  }
}
