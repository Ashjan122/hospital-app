import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:hospital_app/services/sms_service.dart';
import 'package:hospital_app/services/whatsapp_service.dart';
import 'package:hospital_app/services/push_gateway_service.dart';

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

class _HomeClinicDetailsScreenState extends State<HomeClinicDetailsScreen> 
    with SingleTickerProviderStateMixin {
  String? _loadingServiceType;
  late TabController _tabController;
  final Set<String> _notifiedReceived = <String>{};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

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
          bottom: TabBar(
            controller: _tabController,
            labelColor: const Color(0xFF2FBDAF),
            unselectedLabelColor: Colors.grey,
            indicatorColor: const Color(0xFF2FBDAF),
            tabs: const [
              Tab(text: 'طلب عيادة للمنزل'),
              Tab(text: 'طلباتي'),
            ],
          ),
        ),
         body: TabBarView(
           controller: _tabController,
           children: [
             // القسم الأول: طلب عيادة للمنزل
             Container(
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
             // القسم الثاني: طلباتي
             _buildMyRequestsTab(),
           ],
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
    bool isThisServiceLoading = _loadingServiceType == title;
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
          onTap: isThisServiceLoading ? null : onTap,
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
                if (isThisServiceLoading)
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

  Widget _buildMyRequestsTab() {
    return Container(
      color: Colors.white,
      child: FutureBuilder<List<String>>(
        future: _getUserPhoneFormats(),
        builder: (context, phoneSnapshot) {
          if (phoneSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!phoneSnapshot.hasData || phoneSnapshot.data!.isEmpty) {
            return const Center(
              child: Text('لا يمكن جلب بيانات المستخدم'),
            );
          }

          final phoneFormats = phoneSnapshot.data!;
          print('DEBUG: البحث عن الطلبات بتنسيقات الهاتف: $phoneFormats');
          print('DEBUG: معرف المركز: ${widget.centerId}');

          // البحث بكل تنسيقات رقم الهاتف
          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('homeSampleRequests')
                .where('patientPhone', whereIn: phoneFormats)
                .snapshots(),
            builder: (context, snapshot) {
              print('DEBUG: StreamBuilder - connectionState: ${snapshot.connectionState}');
              print('DEBUG: StreamBuilder - hasData: ${snapshot.hasData}');
              if (snapshot.hasData) {
                print('DEBUG: عدد الطلبات: ${snapshot.data!.docs.length}');
              }
              if (snapshot.hasError) {
                print('DEBUG: خطأ في StreamBuilder: ${snapshot.error}');
              }
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Center(
                  child: Text('خطأ في تحميل البيانات: ${snapshot.error}'),
                );
              }

              if (!snapshot.hasData) {
                return const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.inbox,
                        size: 64,
                        color: Colors.grey,
                      ),
                      SizedBox(height: 16),
                      Text(
                        'لا توجد طلبات بعد',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                );
              }

              // فلترة البيانات حسب المركز وترتيبها حسب التاريخ (الأحدث أولاً)
              final allDocs = snapshot.data!.docs;
              final filteredDocs = allDocs.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final centerId = data['centerId'] as String?;
                return centerId == widget.centerId;
              }).toList();
              
              // إرسال إشعار واحد فقط لآخر طلب حالته received
              {
                QueryDocumentSnapshot? latestReceived;
                Timestamp? latestTs;
                for (final d in filteredDocs) {
                  final m = d.data() as Map<String, dynamic>;
                  if ((m['status'] ?? '').toString() == 'received') {
                    final ts = m['createdAt'] is Timestamp ? m['createdAt'] as Timestamp : null;
                    if (latestReceived == null) {
                      latestReceived = d;
                      latestTs = ts;
                    } else {
                      // قارن حسب createdAt إن وُجد، وإلا اترك الأقدم
                      if (ts != null && (latestTs == null || ts.compareTo(latestTs) > 0)) {
                        latestReceived = d;
                        latestTs = ts;
                      }
                    }
                  }
                }
                if (latestReceived != null) {
                  final latestId = latestReceived.id;
                  if (!_notifiedReceived.contains(latestId)) {
                    _notifiedReceived.add(latestId);
                    _handleReceivedNotification(latestReceived.data() as Map<String, dynamic>);
                  }
                }
              }
              
              print('DEBUG: إجمالي الطلبات: ${allDocs.length}');
              print('DEBUG: الطلبات المفلترة لهذا المركز: ${filteredDocs.length}');
              
              // إذا لم توجد طلبات بعد الفلترة
              if (filteredDocs.isEmpty) {
                return const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.inbox,
                        size: 64,
                        color: Colors.grey,
                      ),
                      SizedBox(height: 16),
                      Text(
                        'لا توجد طلبات بعد',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                );
              }
              
              filteredDocs.sort((a, b) {
                final aData = a.data() as Map<String, dynamic>;
                final bData = b.data() as Map<String, dynamic>;
                final aDate = aData['createdAt'] as Timestamp?;
                final bDate = bData['createdAt'] as Timestamp?;
                
                if (aDate == null && bDate == null) return 0;
                if (aDate == null) return 1;
                if (bDate == null) return -1;
                
                return bDate.compareTo(aDate); // الأحدث أولاً
              });

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: filteredDocs.length,
                itemBuilder: (context, index) {
                  final doc = filteredDocs[index];
                  final data = doc.data() as Map<String, dynamic>;
                  
                  return _buildRequestCard(data);
                },
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _handleReceivedNotification(Map<String, dynamic> data) async {
    try {
      final String token = (data['patientToken'] ?? '').toString();
      final String phone = (data['patientPhone'] ?? '').toString();
      final String patientName = (data['patientName'] ?? '').toString();
      final String serviceType = (data['serviceType'] ?? '').toString();
      final String message = _composeReceivedMessage(
        patientName: patientName,
        serviceType: serviceType,
      );

      // Push notification via external gateway (no server key in client)
      if (token.isNotEmpty) {
        await PushGatewayService.sendPush(
          token: token,
          title: 'تطبيق جودة الطبي',
          body: 'تم استلام طلبك وسيتم التواصل معك',
        );
      }

      // SMS
      if (phone.isNotEmpty) {
        await SMSService.sendSimpleSMS(phone, message);
      }

      // WhatsApp
      if (phone.isNotEmpty) {
        await WhatsAppService.sendSimpleMessage(phone, message);
      }
    } catch (e) {
      // تجاهل الخطأ حتى لا يؤثر على الواجهة
    }
  }

  String _composeReceivedMessage({
    required String patientName,
    required String serviceType,
  }) {
    final String typeText = serviceType.isNotEmpty ? serviceType : 'خدمة';
    return 'تطبيق جودة الطبي\n\nمرحبا $patientName تم استلام طلبك ($typeText) وسيتم التواصل معك';
  }

  // تم استخدام PushGatewayService بدلاً من استدعاء FCM مباشرة من التطبيق

  Future<List<String>> _getUserPhoneFormats() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userEmail = prefs.getString('userEmail'); // userEmail يحتوي على رقم الهاتف
      
      print('DEBUG: userEmail من SharedPreferences: $userEmail');
      
      if (userEmail != null) {
        List<String> phoneFormats = [];
        
        // إضافة التنسيق الأصلي
        phoneFormats.add(userEmail);
        
        // إضافة تنسيق بدون المفتاح الدولي
        String formattedPhone = userEmail;
        if (formattedPhone.startsWith('249')) {
          formattedPhone = '0' + formattedPhone.substring(3);
        }
        
        // التأكد من أن الرقم يبدأ بـ 0
        if (!formattedPhone.startsWith('0')) {
          formattedPhone = '0' + formattedPhone;
        }
        
        // التأكد من أن الرقم 10 أرقام
        if (formattedPhone.length > 10) {
          formattedPhone = formattedPhone.substring(0, 10);
        }
        
        if (formattedPhone != userEmail) {
          phoneFormats.add(formattedPhone);
        }
        
        print('DEBUG: تنسيقات رقم الهاتف: $phoneFormats');
        return phoneFormats;
      }
      print('DEBUG: userEmail فارغ');
      return [];
    } catch (e) {
      print('خطأ في جلب رقم الهاتف: $e');
      return [];
    }
  }

  Widget _buildRequestCard(Map<String, dynamic> data) {
    final patientName = data['patientName'] ?? 'غير محدد';
    final status = data['status'] ?? 'pending';
    final createdDate = data['createdDate'] ?? '';
    final createdTime = data['createdTime'] ?? '';
    final notes = data['notes'] ?? '';

    // تحديد لون الحالة
    Color statusColor;
    String statusText;
    IconData statusIcon;

    switch (status) {
      case 'pending':
        statusColor = Colors.orange;
        statusText = 'قيد الانتظار';
        statusIcon = Icons.access_time;
        break;
      case 'received':
      case 'completed':
        statusColor = Colors.green;
        statusText = 'تم الاستلام';
        statusIcon = Icons.check_circle;
        break;
      default:
        statusColor = Colors.grey;
        statusText = 'غير محدد';
        statusIcon = Icons.help;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // اسم المريض والحالة
            Row(
              children: [
                Expanded(
                  child: Text(
                    patientName,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: statusColor.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        statusIcon,
                        size: 16,
                        color: statusColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        statusText,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            // التاريخ والوقت
            Row(
              children: [
                Icon(
                  Icons.calendar_today,
                  size: 16,
                  color: Colors.grey[600],
                ),
                const SizedBox(width: 8),
                Text(
                  createdDate,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(width: 16),
                Icon(
                  Icons.access_time,
                  size: 16,
                  color: Colors.grey[600],
                ),
                const SizedBox(width: 8),
                Text(
                  createdTime,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
            
            // الملاحظات إذا كانت موجودة (بدون الجزء الأخير)
            if (notes.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                _cleanNotes(notes),
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[700],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _cleanNotes(String notes) {
    // إزالة الجزء الأخير "طلب X من العيادة المنزلية - مركز Y"
    if (notes.contains('من العيادة المنزلية')) {
      final parts = notes.split('من العيادة المنزلية');
      if (parts.isNotEmpty) {
        return parts[0].trim();
      }
    }
    return notes;
  }

  Future<void> _sendRequest(String serviceType) async {
    if (_loadingServiceType != null) return;

    setState(() {
      _loadingServiceType = serviceType;
    });

    try {
       // Get user data from SharedPreferences
       final prefs = await SharedPreferences.getInstance();
       final userName = prefs.getString('userName') ?? 'غير محدد';
       final userEmail = prefs.getString('userEmail'); // userEmail يحتوي على رقم الهاتف
       
       // جلب FCM Token مباشرة
       String? userToken;
       try {
         userToken = await FirebaseMessaging.instance.getToken();
         print('DEBUG: FCM Token جُلب مباشرة: $userToken');
         
         // حفظ التوكن في SharedPreferences إذا تم جلبه بنجاح
         if (userToken != null) {
           await prefs.setString('fcmToken', userToken);
           print('DEBUG: FCM Token تم حفظه في SharedPreferences');
         }
       } catch (e) {
         print('DEBUG: خطأ في جلب FCM Token: $e');
         // محاولة جلب التوكن من SharedPreferences كبديل
         userToken = prefs.getString('fcmToken');
         print('DEBUG: FCM Token من SharedPreferences: $userToken');
       }

       // تنسيق رقم الهاتف ليكون بدون المفتاح الدولي (يبدأ بـ 0)
       String formattedPhone = 'غير محدد';
       if (userEmail != null) {
         formattedPhone = userEmail;
         
         // إزالة المفتاح الدولي إذا كان موجوداً
         if (formattedPhone.startsWith('249')) {
           formattedPhone = '0' + formattedPhone.substring(3);
         }
         
         // التأكد من أن الرقم يبدأ بـ 0
         if (!formattedPhone.startsWith('0')) {
           formattedPhone = '0' + formattedPhone;
         }
         
         // التأكد من أن الرقم 10 أرقام
         if (formattedPhone.length > 10) {
           formattedPhone = formattedPhone.substring(0, 10);
         }
       }

       print('DEBUG: رقم الهاتف الأصلي: $userEmail');
       print('DEBUG: رقم الهاتف المنسق: $formattedPhone');
       print('DEBUG: FCM Token: $userToken');

       // Create request data (matching homeSampleRequests structure)
       final now = DateTime.now();
       final requestData = {
         'address': 'العنوان غير محدد', // Will be filled by admin
         'controlId': null, // Set to null as requested
         'createdAt': FieldValue.serverTimestamp(),
         'createdDate': '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}',
         'createdTime': '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}',
         'patientName': userName,
         'patientPhone': formattedPhone, // رقم الهاتف بدون المفتاح الدولي
         'patientToken': userToken, // FCM Token للمريض
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
         // التبديل إلى تبويب "طلباتي" بعد إرسال الطلب
         _tabController.animateTo(1);
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
          _loadingServiceType = null;
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
