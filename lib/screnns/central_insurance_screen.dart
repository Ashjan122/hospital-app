import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CentralInsuranceScreen extends StatefulWidget {
  const CentralInsuranceScreen({super.key});

  @override
  State<CentralInsuranceScreen> createState() => _CentralInsuranceScreenState();
}

class _CentralInsuranceScreenState extends State<CentralInsuranceScreen> {
  bool _isLoading = false;
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'إدارة شركات التأمين المركزية',
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
                  hintText: 'البحث في شركات التأمين...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
            ),
            // Insurance companies list
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('insuranceCompanies')
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

                  final companies = snapshot.data?.docs ?? [];
                  
                  // Filter companies based on search query
                  final filteredCompanies = companies.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final name = data['name']?.toString().toLowerCase() ?? '';
                    final description = data['description']?.toString().toLowerCase() ?? '';
                    final phone = data['phone']?.toString().toLowerCase() ?? '';
                    return name.contains(_searchQuery.toLowerCase()) ||
                           description.contains(_searchQuery.toLowerCase()) ||
                           phone.contains(_searchQuery.toLowerCase());
                  }).toList();

                  if (filteredCompanies.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _searchQuery.isEmpty ? Icons.business : Icons.search_off,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _searchQuery.isEmpty 
                                ? 'لا توجد شركات تأمين'
                                : 'لم يتم العثور على شركات تأمين تطابق البحث',
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
                    itemCount: filteredCompanies.length,
                    itemBuilder: (context, index) {
                      final doc = filteredCompanies[index];
                      final data = doc.data() as Map<String, dynamic>;
                      final name = data['name'] ?? 'شركة غير معروفة';
                      final description = data['description'] ?? '';
                      final phone = data['phone'] ?? '';

                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color: const Color.fromARGB(255, 78, 17, 175).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(25),
                            ),
                            child: const Icon(
                              Icons.business,
                              color: Color.fromARGB(255, 78, 17, 175),
                            ),
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
                              if (description.isNotEmpty)
                                Text(description),
                              if (phone.isNotEmpty)
                                Text('الهاتف: $phone'),
                            ],
                          ),
                                                     trailing: IconButton(
                             onPressed: () => _showEditInsuranceDialog(doc.id, name, description, phone),
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
          onPressed: () => _showAddInsuranceDialog(),
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

  void _showAddInsuranceDialog() {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    final phoneController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إضافة شركة تأمين جديدة'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'اسم الشركة',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descriptionController,
              decoration: const InputDecoration(
                labelText: 'وصف الشركة (اختياري)',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: phoneController,
              decoration: const InputDecoration(
                labelText: 'رقم الهاتف (اختياري)',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.phone,
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
              if (nameController.text.trim().isNotEmpty) {
                Navigator.pop(context);
                await _addInsuranceCompany(
                  nameController.text.trim(),
                  descriptionController.text.trim(),
                  phoneController.text.trim(),
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
    );
  }

  void _showEditInsuranceDialog(String id, String currentName, String currentDescription, String currentPhone) {
    final nameController = TextEditingController(text: currentName);
    final descriptionController = TextEditingController(text: currentDescription);
    final phoneController = TextEditingController(text: currentPhone);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تعديل شركة التأمين'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'اسم الشركة',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descriptionController,
              decoration: const InputDecoration(
                labelText: 'وصف الشركة (اختياري)',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: phoneController,
              decoration: const InputDecoration(
                labelText: 'رقم الهاتف (اختياري)',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.phone,
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
              if (nameController.text.trim().isNotEmpty) {
                Navigator.pop(context);
                await _updateInsuranceCompany(
                  id,
                  nameController.text.trim(),
                  descriptionController.text.trim(),
                  phoneController.text.trim(),
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
    );
  }



  Future<void> _addInsuranceCompany(String name, String description, String phone) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final id = await _getNextNumericId('insuranceCompanies');
      
      await FirebaseFirestore.instance
          .collection('insuranceCompanies')
          .doc(id)
          .set({
        'id': int.tryParse(id) ?? id,
        'name': name,
        'description': description,
        'phone': phone,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم إضافة شركة التأمين "$name" بنجاح'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في إضافة شركة التأمين: $e'),
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

  Future<void> _updateInsuranceCompany(String id, String name, String description, String phone) async {
    setState(() {
      _isLoading = true;
    });

    try {
      await FirebaseFirestore.instance
          .collection('insuranceCompanies')
          .doc(id)
          .update({
        'name': name,
        'description': description,
        'phone': phone,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم تحديث شركة التأمين "$name" بنجاح'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في تحديث شركة التأمين: $e'),
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
