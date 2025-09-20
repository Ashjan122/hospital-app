import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hospital_app/screnns/home_clinic_details_screen.dart';

class HomeClinicScreen extends StatefulWidget {
  const HomeClinicScreen({super.key});

  @override
  State<HomeClinicScreen> createState() => _HomeClinicScreenState();
}

class _HomeClinicScreenState extends State<HomeClinicScreen> {
  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          centerTitle: true,
          backgroundColor: Colors.white,
          elevation: 0,
          title: const Text(
            "العيادة المنزلية",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFF2FBDAF),
              fontSize: 24,
            ),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Color(0xFF2FBDAF)),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: Container(
          color: Colors.white,
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('homeClinic')
                .where('isActive', isEqualTo: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2FBDAF)),
                  ),
                );
              }

              if (snapshot.hasError) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        size: 64,
                        color: Colors.red,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'خطأ في تحميل البيانات: ${snapshot.error}',
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.red,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                );
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.local_hospital_outlined,
                        size: 64,
                        color: Colors.grey,
                      ),
                      SizedBox(height: 16),
                      Text(
                        'لا توجد عيادات منزلية متاحة حالياً',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: snapshot.data!.docs.length,
                itemBuilder: (context, index) {
                  final doc = snapshot.data!.docs[index];
                  final data = doc.data() as Map<String, dynamic>;
                  
                  final centerName = (data['centerName'] ?? '').toString();
                  final centerImage = (data['imageUrl'] ?? '').toString();
                  final centerId = (data['centerId'] ?? '').toString();

                   return _buildClinicCard(
                     context: context,
                     centerName: centerName,
                     centerImage: centerImage,
                     centerId: centerId.isNotEmpty ? centerId : doc.id,
                   );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildClinicCard({
    required BuildContext context,
    required String centerName,
    required String centerImage,
    required String centerId,
  }) {
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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => HomeClinicDetailsScreen(
                  centerId: centerId,
                  centerName: centerName,
                  centerImage: centerImage,
                ),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Center Image
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.grey[200],
                  ),
                  child: centerImage.isNotEmpty
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            centerImage,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return const Icon(
                                Icons.local_hospital,
                                size: 40,
                                color: Color(0xFF2FBDAF),
                              );
                            },
                          ),
                        )
                      : const Icon(
                          Icons.local_hospital,
                          size: 40,
                          color: Color(0xFF2FBDAF),
                        ),
                ),
                const SizedBox(width: 16),
                
                 // Center Info
                 Expanded(
                   child: Text(
                     centerName,
                     style: const TextStyle(
                       fontSize: 18,
                       fontWeight: FontWeight.bold,
                       color: Colors.black87,
                     ),
                   ),
                 ),
                
                // Arrow Icon
                const Icon(
                  Icons.arrow_forward_ios,
                  color: Color(0xFF2FBDAF),
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
