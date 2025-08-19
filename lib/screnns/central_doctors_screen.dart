import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CentralDoctorsScreen extends StatefulWidget {
  const CentralDoctorsScreen({super.key});

  @override
  State<CentralDoctorsScreen> createState() => _CentralDoctorsScreenState();
}

class _CentralDoctorsScreenState extends State<CentralDoctorsScreen> {
  bool _isLoading = false;
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'إدارة الأطباء المركزية',
            style: TextStyle(
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
            // Search bar
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.grey[50],
              child: TextField(
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
                decoration: InputDecoration(
                  hintText: 'البحث في الأطباء...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
            ),
            // Doctors list
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('allDoctors')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error, color: Colors.red, size: 64),
                          const SizedBox(height: 16),
                          Text('خطأ في الاتصال: ${snapshot.error}'),
                        ],
                      ),
                    );
                  }

                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final doctors = snapshot.data?.docs ?? [];
                  
                  // Filter doctors based on search query
                  final filteredDoctors = doctors.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final name = data['name']?.toString().toLowerCase() ?? '';
                    final specialization = data['specialization']?.toString().toLowerCase() ?? '';
                    final phone = data['phoneNumber']?.toString().toLowerCase() ?? '';
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
                                ? 'لا يوجد أطباء'
                                : 'لم يتم العثور على أطباء يطابقون البحث',
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
                    itemCount: filteredDoctors.length,
                    itemBuilder: (context, index) {
                      final doc = filteredDoctors[index];
                      final data = doc.data() as Map<String, dynamic>;
                      final name = data['name'] ?? 'طبيب غير معروف';
                      final specialization = data['specialization'] ?? '';
                      final phone = data['phoneNumber'] ?? '';
                      final photoUrl = data['photoUrl'] ?? '';

                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            radius: 25,
                            backgroundImage: photoUrl.isNotEmpty
                                ? NetworkImage(photoUrl)
                                : null,
                            backgroundColor: photoUrl.isEmpty
                                ? const Color.fromARGB(255, 78, 17, 175).withOpacity(0.1)
                                : null,
                            child: photoUrl.isEmpty
                                ? const Icon(
                                    Icons.person,
                                    color: Color.fromARGB(255, 78, 17, 175),
                                  )
                                : null,
                          ),
                          title: Text(
                            name,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (specialization.isNotEmpty)
                                Text('التخصص: $specialization'),
                              if (phone.isNotEmpty)
                                Text('الهاتف: $phone'),
                            ],
                          ),
                          trailing: IconButton(
                            onPressed: () => _showEditDoctorDialog(doc.id, name, phone, specialization),
                            icon: const Icon(Icons.edit, color: Colors.blue),
                            tooltip: 'تعديل',
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
        floatingActionButton: FloatingActionButton(
          onPressed: () => _showAddDoctorDialog(),
          backgroundColor: const Color.fromARGB(255, 78, 17, 175),
          foregroundColor: Colors.white,
          child: const Icon(Icons.add),
        ),
      ),
    );
  }

  Future<String> _getNextNumericId(String collectionPath) async {
    final snapshot = await FirebaseFirestore.instance.collection(collectionPath).get();
    int maxId = 0;
    for (final doc in snapshot.docs) {
      int? idNum = int.tryParse(doc.id);
      if (idNum == null) {
        final data = doc.data() as Map<String, dynamic>;
        final dynamic fieldId = data['id'];
        if (fieldId is int) {
          idNum = fieldId;
        } else if (fieldId is String) {
          idNum = int.tryParse(fieldId);
        }
      }
      if (idNum != null && idNum > maxId) maxId = idNum;
    }
    return (maxId + 1).toString();
  }

  Widget _buildSpecialtyDropdown(String? selectedValue, Function(String?) onChanged) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('medicalSpecialties')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Text('خطأ في تحميل التخصصات');
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const CircularProgressIndicator();
        }

        final specialties = snapshot.data?.docs ?? [];
        
        // Check if the current value exists in the specialties list
        final specialtyIds = specialties.map((doc) => doc.id).toList();
        String? validValue = selectedValue;
        if (selectedValue != null && !specialtyIds.contains(selectedValue)) {
          validValue = null;
        }
        
        return DropdownButtonFormField<String>(
          value: validValue,
          decoration: const InputDecoration(
            labelText: 'التخصص',
            border: OutlineInputBorder(),
          ),
          items: [
            const DropdownMenuItem<String>(
              value: null,
              child: Text('اختر التخصص'),
            ),
            ...specialties.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final name = data['name'] ?? 'تخصص غير معروف';
              return DropdownMenuItem<String>(
                value: doc.id,
                child: Text(name),
              );
            }).toList(),
          ],
          onChanged: onChanged,
          validator: (value) {
            if (value == null) {
              return 'يرجى اختيار التخصص';
            }
            return null;
          },
        );
      },
    );
  }

  void _showAddDoctorDialog() {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    String? selectedSpecialization;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('إضافة طبيب جديد'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'اسم الطبيب',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneController,
                decoration: const InputDecoration(
                  labelText: 'رقم الهاتف',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 12),
              _buildSpecialtyDropdown(
                selectedSpecialization,
                (value) {
                  setState(() {
                    selectedSpecialization = value;
                  });
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.trim().isNotEmpty && selectedSpecialization != null) {
                  Navigator.pop(context);
                  await _addDoctor(
                    nameController.text.trim(),
                    phoneController.text.trim(),
                    selectedSpecialization!,
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color.fromARGB(255, 78, 17, 175),
                foregroundColor: Colors.white,
              ),
              child: const Text('إضافة'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditDoctorDialog(String id, String currentName, String currentPhone, String currentSpecialization) {
    final nameController = TextEditingController(text: currentName);
    final phoneController = TextEditingController(text: currentPhone);
    String? selectedSpecialization = currentSpecialization;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('تعديل الطبيب'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'اسم الطبيب',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneController,
                decoration: const InputDecoration(
                  labelText: 'رقم الهاتف',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 12),
              _buildSpecialtyDropdown(
                selectedSpecialization,
                (value) {
                  setState(() {
                    selectedSpecialization = value;
                  });
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.trim().isNotEmpty && selectedSpecialization != null) {
                  Navigator.pop(context);
                  await _updateDoctor(
                    id,
                    nameController.text.trim(),
                    phoneController.text.trim(),
                    selectedSpecialization!,
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color.fromARGB(255, 78, 17, 175),
                foregroundColor: Colors.white,
              ),
              child: const Text('تحديث'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addDoctor(String name, String phone, String specialization) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final id = await _getNextNumericId('allDoctors');
      
      await FirebaseFirestore.instance
          .collection('allDoctors')
          .doc(id)
          .set({
        'id': int.tryParse(id) ?? id,
        'name': name,
        'phoneNumber': phone,
        'specialization': specialization,
        'photoUrl': 'https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcQupVHd_oeqnkds0k3EjT1SX4ctwwblwYP2Uw&s',
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم إضافة الطبيب "$name" بنجاح'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في إضافة الطبيب: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _updateDoctor(String id, String name, String phone, String specialization) async {
    setState(() {
      _isLoading = true;
    });

    try {
      await FirebaseFirestore.instance
          .collection('allDoctors')
          .doc(id)
          .update({
        'name': name,
        'phoneNumber': phone,
        'specialization': specialization,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم تحديث الطبيب "$name" بنجاح'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في تحديث الطبيب: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
}
