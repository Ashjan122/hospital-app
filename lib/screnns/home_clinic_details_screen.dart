import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HomeClinicDetailsScreen extends StatefulWidget {
  final String centerId;
  final String centerName;
  final String centerImage;

  const HomeClinicDetailsScreen({
    super.key,
    required this.centerId,
    required this.centerName,
    required this.centerImage,
  });

  @override
  State<HomeClinicDetailsScreen> createState() => _HomeClinicDetailsScreenState();
}

class _HomeClinicDetailsScreenState extends State<HomeClinicDetailsScreen> {
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          centerTitle: true,
          backgroundColor: Colors.white,
          elevation: 0,
          title: Text(
            widget.centerName,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFF2FBDAF),
              fontSize: 20,
            ),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Color(0xFF2FBDAF)),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
         body: Container(
           color: Colors.white,
           child: Padding(
             padding: const EdgeInsets.all(16),
             child: Column(
               children: [
                 _buildServiceCard(
                   icon: Icons.medical_services,
                   title: 'طبيب عمومي',
                   description: 'زيارة طبيب عام في المنزل',
                   color: Colors.blue,
                   onTap: () => _sendRequest('طبيب عمومي'),
                 ),
                 const SizedBox(height: 16),
                 _buildServiceCard(
                   icon: Icons.person_pin_circle,
                   title: 'أخصائي',
                   description: 'زيارة طبيب أخصائي في المنزل',
                   color: Colors.green,
                   onTap: () => _sendRequest('أخصائي'),
                 ),
                 const SizedBox(height: 16),
                 _buildServiceCard(
                   icon: Icons.science,
                   title: 'فحوصات',
                   description: 'إجراء فحوصات طبية في المنزل',
                   color: Colors.orange,
                   onTap: () => _sendRequest('فحوصات'),
                 ),
               ],
             ),
           ),
         ),
      ),
    );
  }

  Widget _buildServiceCard({
    required IconData icon,
    required String title,
    required String description,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 2,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: _isLoading ? null : onTap,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    color: color,
                    size: 30,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        description,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                if (_isLoading)
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2FBDAF)),
                    ),
                  )
                else
                  Icon(
                    Icons.arrow_forward_ios,
                    color: color,
                    size: 16,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _sendRequest(String serviceType) async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
       // Get user data from SharedPreferences
       final prefs = await SharedPreferences.getInstance();
       final userName = prefs.getString('userName') ?? 'غير محدد';
       final userPhone = prefs.getString('userPhone') ?? 'غير محدد';

       // Create request data (matching homeSampleRequests structure)
       final now = DateTime.now();
       final requestData = {
         'address': 'العنوان غير محدد', // Will be filled by admin
         'controlId': null, // Set to null as requested
         'createdAt': FieldValue.serverTimestamp(),
         'createdDate': '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}',
         'createdTime': '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}',
         'patientName': userName,
         'patientPhone': userPhone,
         'status': 'pending',
         'serviceType': serviceType, // Add service type field
         'centerId': widget.centerId,
         'centerName': widget.centerName,
         'notes': 'طلب $serviceType من العيادة المنزلية - ${widget.centerName}',
       };

       // Add to homeSampleRequests collection (same as home samples)
       await FirebaseFirestore.instance
           .collection('homeSampleRequests')
           .add(requestData);

       if (mounted) {
         _showSuccessDialog(serviceType);
       }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في إرسال الطلب: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showSuccessDialog(String serviceType) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            contentPadding: const EdgeInsets.all(24),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Success Icon
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2FBDAF).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_circle,
                    size: 50,
                    color: Color(0xFF2FBDAF),
                  ),
                ),
                const SizedBox(height: 20),
                
                // Success Title
                const Text(
                  'تم الطلب بنجاح',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                
                // Success Message
                Text(
                  'تم إرسال طلب $serviceType بنجاح وسيتم التواصل معك قريباً',
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
            actions: [
              Center(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop(); // Close dialog
                    Navigator.of(context).pop(); // Go back to previous screen
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2FBDAF),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'موافق',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
