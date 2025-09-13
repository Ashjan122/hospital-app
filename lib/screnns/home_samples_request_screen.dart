import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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

  @override
  void initState() {
    super.initState();
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
      await docRef.set({
        'id': docRef.id,
        'patientName': _nameController.text.trim(),
        'patientPhone': _phoneController.text.trim(),
        'address': _addressController.text.trim(),
        'controlId': null,
        'createdAt': FieldValue.serverTimestamp(),
        'createdDate': dateStr,
        'createdTime': timeStr,
        'status': 'pending',
      });

      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم إرسال طلب العينات المنزلية بنجاح'),
          backgroundColor: Color(0xFF2FBDAF),
        ),
      );
      Navigator.pop(context);
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
            'العينات المنزلية',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: const Color(0xFF2FBDAF),
              fontSize: 20,
            ),
          ),
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: 'اسم المريض ',
                      hintText: 'أدخل الاسم الثلاثي',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.person, color: Color(0xFF2FBDAF)),
                      focusedBorder: const OutlineInputBorder(
                        borderSide: BorderSide(color: Color(0xFF2FBDAF), width: 2),
                      ),
                      labelStyle: const TextStyle(color: Color(0xFF2FBDAF)),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'يرجى إدخال الاسم';
                      }
                      final parts = value.trim().split(' ').where((p) => p.isNotEmpty).toList();
                      if (parts.length < 3) {
                        return 'يرجى إدخال الاسم الثلاثي';
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
                      labelText: 'رقم الهاتف ',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.phone, color: Color(0xFF2FBDAF)),
                      focusedBorder: const OutlineInputBorder(
                        borderSide: BorderSide(color: Color(0xFF2FBDAF), width: 2),
                      ),
                      labelStyle: const TextStyle(color: Color(0xFF2FBDAF)),
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
                      labelText: 'العنوان',
                      hintText: 'مثال: الخرطوم - شارع الستين - قرب ...',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.location_on, color: Color(0xFF2FBDAF)),
                      focusedBorder: const OutlineInputBorder(
                        borderSide: BorderSide(color: Color(0xFF2FBDAF), width: 2),
                      ),
                      labelStyle: const TextStyle(color: Color(0xFF2FBDAF)),
                    ),
                    maxLines: 3,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'يرجى إدخال العنوان';
                      }
                      if (value.trim().length < 8) {
                        return 'الرجاء إدخال عنوان واضح ومفصل';
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
                        borderRadius: BorderRadius.circular(12),
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
          ),
        ),
      ),
    );
  }
}


