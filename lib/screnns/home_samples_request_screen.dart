import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HomeSamplesRequestScreen extends StatefulWidget {
  const HomeSamplesRequestScreen({super.key});

  @override
  State<HomeSamplesRequestScreen> createState() => _HomeSamplesRequestScreenState();
}

class _HomeSamplesRequestScreenState extends State<HomeSamplesRequestScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  bool _submitting = false;
  int _selectedTab = 0; // 0: طلب فحوصات منزلية, 1: طلباتي
  String? _currentUserPhone;

  @override
  void initState() {
    super.initState();
    _loadCurrentUserPhone();
  }

  Future<void> _loadCurrentUserPhone() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _currentUserPhone = prefs.getString('userPhone');
    });
    print('رقم الهاتف المحمل: $_currentUserPhone');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _submitRequest() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    try {
      final now = DateTime.now();
      final dateStr = '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final timeStr = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

      final collection = FirebaseFirestore.instance.collection('homeSampleRequests');
      final docRef = collection.doc();
      final requestData = {
        'id': docRef.id,
        'patientName': _nameController.text.trim(),
        'patientPhone': _phoneController.text.trim(),
        'address': _addressController.text.trim(),
        'controlId': null,
        'createdAt': FieldValue.serverTimestamp(),
        'createdDate': dateStr,
        'createdTime': timeStr,
        'status': 'pending',
      };
      
      print('حفظ الطلب في قاعدة البيانات:');
      print('patientName: ${requestData['patientName']}');
      print('patientPhone: ${requestData['patientPhone']}');
      print('address: ${requestData['address']}');
      print('status: ${requestData['status']}');
      
      await docRef.set(requestData);

      // حفظ رقم الهاتف في SharedPreferences لعرض الطلبات
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('userPhone', _phoneController.text.trim());
      print('تم حفظ رقم الهاتف في SharedPreferences: ${_phoneController.text.trim()}');

      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم إرسال طلب العينات المنزلية بنجاح'),
          backgroundColor: Color(0xFF2FBDAF),
        ),
      );
      
      // تحديث رقم الهاتف المحمل
      _currentUserPhone = _phoneController.text.trim();
      
      // مسح النموذج
      _nameController.clear();
      _phoneController.clear();
      _addressController.clear();
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('فشل إرسال الطلب: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            'الفحوصات المنزلية',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: const Color(0xFF2FBDAF),
              fontSize: 20,
            ),
          ),
        ),
        body: SafeArea(
          child: Column(
            children: [
              // Tab Navigation
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedTab = 0),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(
                                color: _selectedTab == 0 ? const Color(0xFF2FBDAF) : Colors.grey[300]!,
                                width: 2,
                              ),
                            ),
                          ),
                          child: Text(
                            'طلب فحوصات منزلية',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: _selectedTab == 0 ? const Color(0xFF2FBDAF) : Colors.grey[600],
                              fontWeight: FontWeight.w500,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedTab = 1),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(
                                color: _selectedTab == 1 ? const Color(0xFF2FBDAF) : Colors.grey[300]!,
                                width: 2,
                              ),
                            ),
                          ),
                          child: Text(
                            'طلباتي',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: _selectedTab == 1 ? const Color(0xFF2FBDAF) : Colors.grey[600],
                              fontWeight: FontWeight.w500,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              // Content
              Expanded(
                child: _selectedTab == 0 ? _buildRequestForm() : _buildMyRequests(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRequestForm() {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(
                hintText: 'اسم المريض',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                prefixIcon: const Icon(Icons.person, color: Color(0xFF2FBDAF)),
                filled: true,
                fillColor: Colors.grey[100],
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'يرجى إدخال الاسم';
                }
                return null;
              },
              textDirection: TextDirection.rtl,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                hintText: 'رقم الهاتف',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                prefixIcon: const Icon(Icons.phone, color: Color(0xFF2FBDAF)),
                filled: true,
                fillColor: Colors.grey[100],
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'يرجى إدخال رقم الهاتف';
                }
                final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
                if (digits.length < 7) {
                  return 'رقم الهاتف غير صحيح';
                }
                return null;
              },
              textDirection: TextDirection.rtl,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _addressController,
              decoration: InputDecoration(
                hintText: 'العنوان',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                prefixIcon: const Icon(Icons.location_on, color: Color(0xFF2FBDAF)),
                filled: true,
                fillColor: Colors.grey[100],
              ),
              maxLines: null, // قابل للتمديد تلقائياً
              minLines: 1, // سطر واحد كحد أدنى
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'يرجى إدخال العنوان';
                }
                return null;
              },
              textDirection: TextDirection.rtl,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _submitting ? null : _submitRequest,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2FBDAF),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                _submitting ? 'جارٍ الإرسال...' : 'طلب',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMyRequests() {
    print('بناء صفحة طلباتي - رقم الهاتف: $_currentUserPhone');
    
    if (_currentUserPhone == null) {
      return const Center(
        child: Text('لا توجد طلبات بعد'),
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('homeSampleRequests')
          .where('patientPhone', isEqualTo: _currentUserPhone)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        print('StreamBuilder - ConnectionState: ${snapshot.connectionState}');
        print('StreamBuilder - HasError: ${snapshot.hasError}');
        print('StreamBuilder - HasData: ${snapshot.hasData}');
        if (snapshot.hasData) {
          print('StreamBuilder - Docs count: ${snapshot.data!.docs.length}');
        }
        
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('خطأ: ${snapshot.error}'));
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('لا توجد طلبات'),
                const SizedBox(height: 8),
                Text('رقم الهاتف: $_currentUserPhone', style: TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    _loadCurrentUserPhone();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2FBDAF),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('تحديث'),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(20),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final doc = snapshot.data!.docs[index];
            final data = doc.data() as Map<String, dynamic>;
            
            return Card(
              margin: const EdgeInsets.only(bottom: 16),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _getStatusColor(data['status']),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _getStatusText(data['status']),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      data['patientName'] ?? '',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      data['patientPhone'] ?? '',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      data['address'] ?? '',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${data['createdTime'] ?? ''} - ${data['createdDate'] ?? ''}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'completed':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'pending':
        return 'قيد الانتظار';
      case 'completed':
        return 'تم الاستلام';
      default:
        return 'غير محدد';
    }
  }
}


