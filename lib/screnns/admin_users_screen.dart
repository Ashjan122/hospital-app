import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:hospital_app/widgets/optimized_loading_widget.dart';

class AdminUsersScreen extends StatefulWidget {
  final String centerId;
  final String? centerName;

  const AdminUsersScreen({
    super.key,
    required this.centerId,
    this.centerName,
  });

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // Controllers for add user form
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  Future<List<Map<String, dynamic>>> fetchUsers() async {
    try {
      final usersSnapshot = await FirebaseFirestore.instance
          .collection('medicalFacilities')
          .doc(widget.centerId)
          .collection('users')
          .get()
          .timeout(const Duration(seconds: 8));

      List<Map<String, dynamic>> users = [];
      for (var doc in usersSnapshot.docs) {
        final userData = doc.data();
        userData['userId'] = doc.id;
        users.add(userData);
      }
      return users;
    } catch (e) {
      print('خطأ في تحميل المستخدمين: $e');
      return [];
    }
  }

  List<Map<String, dynamic>> filterUsers(List<Map<String, dynamic>> users) {
    if (_searchQuery.isEmpty) return users;
    
    return users.where((user) {
      final name = user['name']?.toString().toLowerCase() ?? '';
      final phone = user['phone']?.toString().toLowerCase() ?? '';
      
      return name.contains(_searchQuery.toLowerCase()) ||
             phone.contains(_searchQuery.toLowerCase());
    }).toList();
  }

  Future<void> addUser() async {
    // Validate form
    if (_nameController.text.isEmpty) {
      _showErrorDialog('يرجى إدخال اسم المستخدم');
      return;
    }
    
    if (_phoneController.text.isEmpty) {
      _showErrorDialog('يرجى إدخال رقم الهاتف');
      return;
    }
    
    if (_passwordController.text.isEmpty) {
      _showErrorDialog('يرجى إدخال كلمة المرور');
      return;
    }
    
    if (_passwordController.text != _confirmPasswordController.text) {
      _showErrorDialog('كلمة المرور غير متطابقة');
      return;
    }
    
    if (_passwordController.text.length < 6) {
      _showErrorDialog('كلمة المرور يجب أن تكون 6 أحرف على الأقل');
      return;
    }

    try {
      // Check if user already exists
      final existingUsers = await FirebaseFirestore.instance
          .collection('medicalFacilities')
          .doc(widget.centerId)
          .collection('users')
          .where('phone', isEqualTo: _phoneController.text)
          .get()
          .timeout(const Duration(seconds: 8));

      if (existingUsers.docs.isNotEmpty) {
        _showErrorDialog('رقم الهاتف مسجل مسبقاً');
        return;
      }

      // Add user to database
      await FirebaseFirestore.instance
          .collection('medicalFacilities')
          .doc(widget.centerId)
          .collection('users')
          .add({
        'name': _nameController.text,
        'phone': _phoneController.text,
        'password': _passwordController.text,
        'createdAt': FieldValue.serverTimestamp(),
        'isActive': true,
      });

      // Clear form
      _nameController.clear();
      _phoneController.clear();
      _passwordController.clear();
      _confirmPasswordController.clear();

      // Close dialog and refresh
      Navigator.of(context).pop();
      setState(() {});
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم إضافة المستخدم بنجاح'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      _showErrorDialog('حدث خطأ أثناء إضافة المستخدم');
    }
  }

  Future<void> deleteUser(String userId, String userName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: Text('هل أنت متأكد من حذف المستخدم "$userName"؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('حذف', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await FirebaseFirestore.instance
            .collection('medicalFacilities')
            .doc(widget.centerId)
            .collection('users')
            .doc(userId)
            .delete();

        setState(() {});
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم حذف المستخدم بنجاح'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        _showErrorDialog('حدث خطأ أثناء حذف المستخدم');
      }
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('خطأ'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('حسناً'),
          ),
        ],
      ),
    );
  }

  void _showAddUserDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إضافة مستخدم جديد'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'اسم المستخدم',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _phoneController,
                decoration: const InputDecoration(
                  labelText: 'رقم الهاتف',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                decoration: const InputDecoration(
                  labelText: 'كلمة المرور',
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _confirmPasswordController,
                decoration: const InputDecoration(
                  labelText: 'تأكيد كلمة المرور',
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: addUser,
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
            widget.centerName != null ? 'المستخدمين - ${widget.centerName}' : 'المستخدمين',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          backgroundColor: const Color.fromARGB(255, 78, 17, 175),
          foregroundColor: Colors.white,
          elevation: 0,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () {
                setState(() {});
              },
            ),
          ],
        ),
        body: Column(
          children: [
            // Search and add user section
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
                      hintText: 'البحث في المستخدمين...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Add user button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _showAddUserDialog,
                      icon: const Icon(Icons.person_add),
                      label: const Text('إضافة مستخدم جديد'),
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
            
            // Users list
            Expanded(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: fetchUsers(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const OptimizedLoadingWidget(
                      message: 'جاري تحميل المستخدمين...',
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
                            'حدث خطأ في تحميل المستخدمين',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  final users = snapshot.data ?? [];
                  final filteredUsers = filterUsers(users);

                  if (filteredUsers.isEmpty) {
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
                                ? 'لا يوجد مستخدمين حالياً'
                                : 'لم يتم العثور على مستخدمين تطابق البحث',
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
                    itemCount: filteredUsers.length,
                    itemBuilder: (context, index) {
                      final user = filteredUsers[index];
                      final userName = user['name'] ?? 'غير محدد';
                      final userPhone = user['phone'] ?? 'غير محدد';
                                             // final isActive = user['isActive'] ?? true;
                       // final createdAt = user['createdAt'] as Timestamp?;

                                             return Container(
                         margin: const EdgeInsets.only(bottom: 12),
                         decoration: BoxDecoration(
                           color: Colors.white,
                           borderRadius: BorderRadius.circular(12),
                           border: Border.all(
                             color: Colors.grey[200]!,
                             width: 1,
                           ),
                           boxShadow: [
                             BoxShadow(
                               color: Colors.grey.withOpacity(0.08),
                               spreadRadius: 1,
                               blurRadius: 6,
                               offset: const Offset(0, 2),
                             ),
                           ],
                         ),
                                                  child: Padding(
                           padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                           child: Row(
                             children: [
                               // User info with labels
                               Expanded(
                                 child: Column(
                                   crossAxisAlignment: CrossAxisAlignment.start,
                                   children: [
                                     Row(
                                       children: [
                                         Text(
                                           'اسم المستخدم: ',
                                           style: TextStyle(
                                             fontSize: 15,
                                             fontWeight: FontWeight.w600,
                                             color: Colors.grey[700],
                                           ),
                                         ),
                                         Text(
                                           userName,
                                           style: const TextStyle(
                                             fontSize: 15,
                                             fontWeight: FontWeight.bold,
                                             color: Colors.black87,
                                           ),
                                         ),
                                       ],
                                     ),
                                     const SizedBox(height: 8),
                                     Row(
                                       children: [
                                         Text(
                                           'رقم الهاتف: ',
                                           style: TextStyle(
                                             fontSize: 15,
                                             fontWeight: FontWeight.w600,
                                             color: Colors.grey[700],
                                           ),
                                         ),
                                         Text(
                                           userPhone,
                                           style: TextStyle(
                                             fontSize: 15,
                                             color: Colors.grey[600],
                                           ),
                                         ),
                                       ],
                                     ),
                                   ],
                                 ),
                               ),
                               
                               // Delete button
                               Container(
                                 decoration: BoxDecoration(
                                   color: Colors.red.withOpacity(0.1),
                                   borderRadius: BorderRadius.circular(8),
                                 ),
                                 child: IconButton(
                                   onPressed: () => deleteUser(user['userId'], userName),
                                   icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                                   tooltip: 'حذف المستخدم',
                                   padding: const EdgeInsets.all(8),
                                   constraints: const BoxConstraints(
                                     minWidth: 36,
                                     minHeight: 36,
                                   ),
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

  // String _formatDate(Timestamp timestamp) {
  //   final date = timestamp.toDate();
  //   return '${date.day}/${date.month}/${date.year}';
  // }
}
