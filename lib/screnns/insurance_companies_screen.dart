import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class InsuranceCompaniesScreen extends StatefulWidget {
  final String facilityId;
  final String facilityName;

  const InsuranceCompaniesScreen({
    super.key,
    required this.facilityId,
    required this.facilityName,
  });

  @override
  State<InsuranceCompaniesScreen> createState() => _InsuranceCompaniesScreenState();
}

class _InsuranceCompaniesScreenState extends State<InsuranceCompaniesScreen> {
  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          centerTitle: true,
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            onPressed: () {
              Navigator.pop(context);
            },
            icon: Icon(Icons.arrow_back, color: Color.fromARGB(255, 78, 17, 175)),
          ),
          title: Text(
            "شركات التأمين",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: const Color.fromARGB(255, 78, 17, 175),
              fontSize: 24,
            ),
          ),
        ),
        body: SafeArea(
          child: Container(
            color: Colors.white,
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('medicalFacilities')
                  .doc(widget.facilityId)
                  .collection('insuranceCompanies')
                  .orderBy('name')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'حدث خطأ في تحميل البيانات',
                      style: TextStyle(fontSize: 16, color: Colors.red),
                    ),
                  );
                }

                final companies = snapshot.data?.docs ?? [];

                if (companies.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.security,
                          size: 80,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'لا توجد شركات تأمين متعاقدة حالياً',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'سيتم إضافة شركات التأمين قريباً',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[500],
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: companies.length,
                  itemBuilder: (context, index) {
                    final company = companies[index].data() as Map<String, dynamic>;
                    final name = company['name'] ?? '';
                    final description = company['description'] ?? '';
                    final phone = company['phone'] ?? '';
                    final isActive = company['isActive'] ?? true;

                    return Container(
                      margin: EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.1),
                            spreadRadius: 1,
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                        border: Border.all(
                          color: isActive 
                              ? const Color.fromARGB(255, 78, 17, 175).withOpacity(0.3)
                              : Colors.grey.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: isActive 
                                        ? const Color.fromARGB(255, 78, 17, 175).withOpacity(0.1)
                                        : Colors.grey.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    Icons.security,
                                    size: 14,
                                    color: isActive ? const Color.fromARGB(255, 78, 17, 175) : Colors.grey,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        name,
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: isActive ? Colors.black87 : Colors.grey,
                                        ),
                                      ),
                                      if (description.isNotEmpty) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          description,
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                if (!isActive)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      'غير متاح',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            if (phone.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Icon(
                                    Icons.phone,
                                    size: 16,
                                    color: Colors.grey[600],
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    phone,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
