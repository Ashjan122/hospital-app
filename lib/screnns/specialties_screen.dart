import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:hospital_app/screnns/doctors_screen.dart';

class SpecialtiesScreen extends StatelessWidget {
  final String facilityId;
  const SpecialtiesScreen({super.key, required this.facilityId});

  Future<List<QueryDocumentSnapshot>> fetchSpecialties() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('medicalFacilities')
        .doc(facilityId)
        .collection('specializations')
        .where('isActive', isEqualTo: true)
        .get();

    return snapshot.docs;
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          actions: [
            IconButton(
              onPressed: () {},
              icon: Icon(Icons.search, color: Color.fromARGB(255, 78, 17, 175)),
            ),
          ],
          title: Text(
            "التخصصات الطبية",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: const Color.fromARGB(255, 78, 17, 175),
              fontSize: 30,
            ),
          ),
        ),

        body: FutureBuilder<List<QueryDocumentSnapshot>>(
          future: fetchSpecialties(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(child: CircularProgressIndicator());
            }

            final specialties = snapshot.data ?? [];
            if (specialties.isEmpty) {
              return Center(child: Text("لا توجد تخصصات حاليا"));
            }

            return ListView.builder(
              itemCount: specialties.length,
              itemBuilder: (context, index) {
                final doc = specialties[index];
                final data = doc.data() as Map<String, dynamic>;
                final specName = data['specName'] ?? 'تخصص غير معروف';
                final specId = doc.id;

                return InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => DoctorsScreen(
                          facilityId: facilityId,
                          specId: specId,
                          
                        ),
                      ),
                    );
                  },
                  child: Container(
                    width: 300,
                    height: 100,
                    child: Card(
                      elevation: 6,
                      margin: EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: ListTile(
                        leading: Icon(
                          Icons.medical_services,
                          color: Color.fromARGB(255, 78, 17, 175),
                        ),
                        title: Text(
                          specName,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        trailing: Icon(Icons.arrow_forward_ios, size: 16),
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}