
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:hospital_app/screnns/specialties_screen.dart';
import 'package:hospital_app/screnns/login_screen.dart';

class HospitalScreen extends StatelessWidget {
  const HospitalScreen({super.key});

  Future<List<QueryDocumentSnapshot>> fetchFacilities() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('medicalFacilities')
        .orderBy('available', descending: true)
        .get();

    return snapshot.docs;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        leading: IconButton(
          onPressed: () {},
          icon: Icon(Icons.search, color: Color.fromARGB(255, 78, 17, 175)),
        ),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              "المرافق الطبية",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: const Color.fromARGB(255, 78, 17, 175),
                fontSize: 30,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Color.fromARGB(255, 78, 17, 175)),
            onPressed: () {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (context) => const LoginScreen()),
                (route) => false,
              );
            },
          ),
        ],
      ),
      body: FutureBuilder<List<QueryDocumentSnapshot>>(
        future: fetchFacilities(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(child: Text("لا توجد بيانات"));
          }

          final facilities = snapshot.data!;

          return Padding(
            padding: const EdgeInsets.all(12.0),
            child: ListView.builder(
              itemCount: facilities.length,
              itemBuilder: (context, index) {
                final doc = facilities[index];
                final name = doc['name'] ?? '';
                final isAvailable = doc['available'] ?? false;

                return InkWell(
                  onTap: () {
                    if (isAvailable) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => SpecialtiesScreen(
                            facilityId: doc.id, ),
                        ),
                      );
                    }
                  },
                  child: Container(
                    margin: EdgeInsets.symmetric(vertical: 10),
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.3),
                          blurRadius: 10,
                          offset: Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.medication,
                          size: 40,
                          color: isAvailable
                              ? Color.fromARGB(255, 78, 17, 175)
                              : Colors.grey,
                        ),
                        SizedBox(height: 10),
                        Text(
                          name,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: isAvailable ? Colors.black : Colors.grey,
                          ),


),
                        if (!isAvailable)
                          Text(
                            'قريبا',
                            style: TextStyle(
                              color: Colors.grey,
                              fontSize: 20,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}