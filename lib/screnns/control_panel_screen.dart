import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hospital_app/services/app_update_service.dart';
import 'package:hospital_app/widgets/app_update_dialog.dart';
import 'package:hospital_app/services/central_data_service.dart';
import 'package:hospital_app/screnns/central_specialties_screen.dart';
import 'package:hospital_app/screnns/central_doctors_screen.dart';
import 'package:hospital_app/screnns/central_insurance_screen.dart';
import 'package:hospital_app/screnns/dashboard_screen.dart';

class ControlPanelScreen extends StatefulWidget {
  const ControlPanelScreen({super.key});

  @override
  State<ControlPanelScreen> createState() => _ControlPanelScreenState();
}

class _ControlPanelScreenState extends State<ControlPanelScreen> {
  final _formKey = GlobalKey<FormState>();
  final _centerNameController = TextEditingController();
  final _centerAddressController = TextEditingController();
  final _centerPhoneController = TextEditingController();
  final _searchController = TextEditingController();
  final _centerNameFocus = FocusNode();
  final _centerAddressFocus = FocusNode();
  final _centerPhoneFocus = FocusNode();
  bool _isLoading = false;
  bool _isAddingCenter = false;
  bool _showAddForm = false;
  String? _editingCenterId;
  String _searchQuery = '';
  bool _showSearchField = false;

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
    final userType = prefs.getString('userType');
    
    if (!isLoggedIn || userType != 'control') {
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
      }
    }
  }

  @override
  void dispose() {
    _centerNameController.dispose();
    _centerAddressController.dispose();
    _centerPhoneController.dispose();
    _searchController.dispose();
    _centerNameFocus.dispose();
    _centerAddressFocus.dispose();
    _centerPhoneFocus.dispose();
    super.dispose();
  }

  Future<void> _testUpdate() async {
    try {
      final updateInfo = await AppUpdateService.checkForUpdate();
      
      if (updateInfo != null) {
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AppUpdateDialog(updateInfo: updateInfo),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('لا يوجد تحديث متاح حالياً'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في اختبار التحديث: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    
    if (mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
    }
  }

  Future<void> _addCenter() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isAddingCenter = true;
      });

      try {
        final centerData = {
          'name': _centerNameController.text.trim(),
          'address': _centerAddressController.text.trim(),
          'phone': _centerPhoneController.text.trim(),
          'available': true,
          'createdAt': FieldValue.serverTimestamp(),
        };
        
        await FirebaseFirestore.instance
            .collection('medicalFacilities')
            .add(centerData);

        _centerNameController.clear();
        _centerAddressController.clear();
        _centerPhoneController.clear();
        setState(() {
          _showAddForm = false;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تم إضافة المركز بنجاح'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('خطأ في إضافة المركز: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        setState(() {
          _isAddingCenter = false;
        });
      }
    }
  }

  Future<void> _toggleCenterAvailability(String centerId, bool currentStatus) async {
    try {
      await FirebaseFirestore.instance
          .collection('medicalFacilities')
          .doc(centerId)
          .update({
        'available': !currentStatus,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(currentStatus ? 'تم إلغاء تفعيل المركز' : 'تم تفعيل المركز'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في تحديث حالة المركز: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _editCenter(String centerId, Map<String, dynamic> centerData) async {
    setState(() {
      _editingCenterId = centerId;
      _centerNameController.text = centerData['name'] ?? '';
      _centerAddressController.text = centerData['address'] ?? '';
      _centerPhoneController.text = centerData['phone'] ?? '';
      _showAddForm = true;
    });
  }

  Future<void> _updateCenter() async {
    if (_formKey.currentState!.validate() && _editingCenterId != null) {
      setState(() {
        _isAddingCenter = true;
      });

      try {
        await FirebaseFirestore.instance
            .collection('medicalFacilities')
            .doc(_editingCenterId)
            .update({
          'name': _centerNameController.text.trim(),
          'address': _centerAddressController.text.trim(),
          'phone': _centerPhoneController.text.trim(),
        });

        _centerNameController.clear();
        _centerAddressController.clear();
        _centerPhoneController.clear();
        setState(() {
          _editingCenterId = null;
          _showAddForm = false;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تم تحديث المركز بنجاح'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('خطأ في تحديث المركز: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        setState(() {
          _isAddingCenter = false;
        });
      }
    }
  }

  void _cancelEdit() {
    setState(() {
      _editingCenterId = null;
      _showAddForm = false;
      _centerNameController.clear();
      _centerAddressController.clear();
      _centerPhoneController.clear();
    });
  }

  Future<void> _deleteCenter(String centerId, String centerName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: Text('هل أنت متأكد من حذف المركز "$centerName"؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('حذف'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await FirebaseFirestore.instance
            .collection('medicalFacilities')
            .doc(centerId)
            .delete();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تم حذف المركز بنجاح'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('خطأ في حذف المركز: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  void _showSpecialtiesList() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const CentralSpecialtiesScreen(),
      ),
    );
  }

  void _showDoctorsList() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const CentralDoctorsScreen(),
      ),
    );
  }

  void _showInsuranceList() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const CentralInsuranceScreen(),
      ),
    );
  }

  List<QueryDocumentSnapshot> _filterCenters(List<QueryDocumentSnapshot> centers) {
    if (_searchQuery.isEmpty) return centers;
    
    return centers.where((center) {
      final data = center.data() as Map<String, dynamic>;
      final name = data['name']?.toString().toLowerCase() ?? '';
      final searchLower = _searchQuery.toLowerCase();
      
      return name.contains(searchLower);
    }).toList();
  }

  void _navigateToCenterDashboard(String centerId, String centerName) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('centerId', centerId);
    await prefs.setString('centerName', centerName);
    await prefs.setString('userType', 'admin');
    await prefs.setBool('isLoggedIn', true);
    
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => DashboardScreen(
            centerId: centerId,
            centerName: centerName,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        appBar: AppBar(
          title: const Text(
            'لوحة تحكم الكنترول',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Color.fromARGB(255, 78, 17, 175),
            ),
          ),
          backgroundColor: Colors.white,
          elevation: 0,
          actions: [
            IconButton(
              onPressed: () => setState(() => _showAddForm = !_showAddForm),
              icon: Icon(
                _showAddForm ? Icons.close : Icons.add,
                color: const Color.fromARGB(255, 78, 17, 175),
              ),
              tooltip: _showAddForm ? 'إغلاق النموذج' : 'إضافة مركز جديد',
            ),
            IconButton(
              onPressed: _testUpdate,
              icon: const Icon(Icons.system_update, color: Color.fromARGB(255, 78, 17, 175)),
              tooltip: 'اختبار التحديث',
            ),
            IconButton(
              onPressed: _logout,
              icon: const Icon(Icons.logout, color: Color.fromARGB(255, 78, 17, 175)),
            ),
          ],
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // رسالة ترحيب
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color.fromARGB(255, 78, 17, 175).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color.fromARGB(255, 78, 17, 175).withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.admin_panel_settings,
                        color: const Color.fromARGB(255, 78, 17, 175),
                        size: 32,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'مرحباً بك في لوحة تحكم الكنترول',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color.fromARGB(255, 78, 17, 175),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'يمكنك إدارة المراكز الطبية من هنا',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                
                // Central Data Management Section
                Card(
                  elevation: 4,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.storage,
                              color: const Color.fromARGB(255, 78, 17, 175),
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'إدارة البيانات المركزية',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () => _showSpecialtiesList(),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: const Color.fromARGB(255, 78, 17, 175),
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  side: const BorderSide(
                                    color: Color.fromARGB(255, 78, 17, 175),
                                    width: 2,
                                  ),
                                  elevation: 2,
                                ),
                                child: const Text(
                                  'التخصصات',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () => _showDoctorsList(),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: const Color.fromARGB(255, 78, 17, 175),
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  side: const BorderSide(
                                    color: Color.fromARGB(255, 78, 17, 175),
                                    width: 2,
                                  ),
                                  elevation: 2,
                                ),
                                child: const Text(
                                  'الأطباء',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () => _showInsuranceList(),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: const Color.fromARGB(255, 78, 17, 175),
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  side: const BorderSide(
                                    color: Color.fromARGB(255, 78, 17, 175),
                                    width: 2,
                                  ),
                                  elevation: 2,
                                ),
                                child: const Text(
                                  'التأمين',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                
                // Add Center Section
                if (_showAddForm)
                  Card(
                    elevation: 4,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                _editingCenterId != null ? Icons.edit : Icons.add_business,
                                color: const Color.fromARGB(255, 78, 17, 175),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _editingCenterId != null ? 'تعديل المركز' : 'إضافة مركز جديد',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Form(
                            key: _formKey,
                            child: Column(
                              children: [
                                TextFormField(
                                  controller: _centerNameController,
                                  focusNode: _centerNameFocus,
                                  decoration: const InputDecoration(
                                    labelText: 'اسم المركز',
                                    border: OutlineInputBorder(),
                                  ),
                                  textInputAction: TextInputAction.next,
                                  onFieldSubmitted: (_) {
                                    _centerNameFocus.unfocus();
                                    _centerAddressFocus.requestFocus();
                                  },
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'يرجى إدخال اسم المركز';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: _centerAddressController,
                                  focusNode: _centerAddressFocus,
                                  decoration: const InputDecoration(
                                    labelText: 'عنوان المركز',
                                    border: OutlineInputBorder(),
                                  ),
                                  textInputAction: TextInputAction.next,
                                  onFieldSubmitted: (_) {
                                    _centerAddressFocus.unfocus();
                                    _centerPhoneFocus.requestFocus();
                                  },
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'يرجى إدخال عنوان المركز';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: _centerPhoneController,
                                  focusNode: _centerPhoneFocus,
                                  decoration: const InputDecoration(
                                    labelText: 'رقم الهاتف',
                                    border: OutlineInputBorder(),
                                  ),
                                  keyboardType: TextInputType.phone,
                                  textInputAction: TextInputAction.done,
                                  onFieldSubmitted: (_) {
                                    _centerPhoneFocus.unfocus();
                                  },
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'يرجى إدخال رقم الهاتف';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    Expanded(
                                      child: ElevatedButton(
                                        onPressed: _isAddingCenter ? null : (_editingCenterId != null ? _updateCenter : _addCenter),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color.fromARGB(255, 78, 17, 175),
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(vertical: 12),
                                        ),
                                        child: _isAddingCenter
                                            ? const SizedBox(
                                                width: 20,
                                                height: 20,
                                                child: CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                                ),
                                              )
                                            : Text(_editingCenterId != null ? 'تحديث المركز' : 'إضافة المركز'),
                                      ),
                                    ),
                                    if (_editingCenterId != null) ...[
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: OutlinedButton(
                                          onPressed: _cancelEdit,
                                          style: OutlinedButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(vertical: 12),
                                          ),
                                          child: const Text('إلغاء'),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 24),
                
                // Centers List Section
                if (!_showSearchField)
                  Row(
                    children: [
                      const Text(
                        'المراكز الطبية',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () {
                          setState(() {
                            _showSearchField = true;
                          });
                        },
                        icon: const Icon(Icons.search),
                        tooltip: 'البحث في المراكز',
                      ),
                    ],
                  )
                else
                  TextField(
                    controller: _searchController,
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value;
                      });
                    },
                    decoration: InputDecoration(
                      hintText: 'البحث باسم المركز...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: IconButton(
                        onPressed: () {
                          setState(() {
                            _showSearchField = false;
                            _searchQuery = '';
                            _searchController.clear();
                          });
                        },
                        icon: const Icon(Icons.close),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    autofocus: true,
                  ),
                const SizedBox(height: 12),
                Container(
                  height: 400,
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('medicalFacilities')
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

                      final allCenters = snapshot.data?.docs ?? [];
                      final centers = _filterCenters(allCenters);

                      if (centers.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.business, color: Colors.grey, size: 64),
                              const SizedBox(height: 16),
                              Text(
                                _searchQuery.isEmpty
                                    ? 'لا توجد مراكز طبية'
                                    : 'لا توجد نتائج للبحث',
                                style: const TextStyle(fontSize: 18, color: Colors.grey),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _searchQuery.isEmpty
                                    ? 'قم بإضافة مركز جديد باستخدام النموذج أعلاه'
                                    : 'جرب البحث بكلمات مختلفة',
                                style: const TextStyle(fontSize: 14, color: Colors.grey),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: () => setState(() => _showAddForm = true),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color.fromARGB(255, 78, 17, 175),
                                  foregroundColor: Colors.white,
                                ),
                                child: const Text('إضافة مركز جديد'),
                              ),
                            ],
                          ),
                        );
                      }

                      return ListView.builder(
                        itemCount: centers.length,
                        itemBuilder: (context, index) {
                          final center = centers[index];
                          final centerData = center.data() as Map<String, dynamic>;
                          final centerId = center.id;
                          final centerName = centerData['name'] ?? '';
                          final centerAddress = centerData['address'] ?? '';
                          final centerPhone = centerData['phone'] ?? '';
                          final isAvailable = centerData['available'] ?? false;

                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              onTap: () => _navigateToCenterDashboard(centerId, centerName),
                              leading: const Icon(Icons.business, color: Color.fromARGB(255, 78, 17, 175)),
                              title: Text(
                                centerName,
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('العنوان: $centerAddress'),
                                  Text('الهاتف: $centerPhone'),
                                  Row(
                                    children: [
                                      Icon(
                                        isAvailable ? Icons.check_circle : Icons.cancel,
                                        color: isAvailable ? Colors.green : Colors.red,
                                        size: 16,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        isAvailable ? 'مفعل' : 'غير مفعل',
                                        style: TextStyle(
                                          color: isAvailable ? Colors.green : Colors.red,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.arrow_forward_ios,
                                    color: Colors.grey[400],
                                    size: 16,
                                  ),
                                  const SizedBox(width: 8),
                                  PopupMenuButton<String>(
                                    icon: const Icon(Icons.more_vert),
                                    onSelected: (value) {
                                      switch (value) {
                                        case 'edit':
                                          _editCenter(centerId, centerData);
                                          break;
                                        case 'toggle':
                                          _toggleCenterAvailability(centerId, isAvailable);
                                          break;
                                        case 'delete':
                                          _deleteCenter(centerId, centerName);
                                          break;
                                      }
                                    },
                                    itemBuilder: (context) => [
                                      PopupMenuItem<String>(
                                        value: 'edit',
                                        child: Row(
                                          children: [
                                            const Icon(Icons.edit, color: Colors.blue, size: 20),
                                            const SizedBox(width: 8),
                                            const Text('تعديل المركز'),
                                          ],
                                        ),
                                      ),
                                      PopupMenuItem<String>(
                                        value: 'toggle',
                                        child: Row(
                                          children: [
                                            Icon(
                                              isAvailable ? Icons.block : Icons.check_circle,
                                              color: isAvailable ? Colors.orange : Colors.green,
                                              size: 20,
                                            ),
                                            const SizedBox(width: 8),
                                            Text(isAvailable ? 'إلغاء التفعيل' : 'تفعيل'),
                                          ],
                                        ),
                                      ),
                                      PopupMenuItem<String>(
                                        value: 'delete',
                                        child: Row(
                                          children: [
                                            const Icon(Icons.delete, color: Colors.red, size: 20),
                                            const SizedBox(width: 8),
                                            const Text('حذف المركز'),
                                          ],
                                        ),
                                      ),
                                    ],
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
        ),
      ),
    );
  }
}
