import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:hospital_app/screnns/booking_screen.dart';

class DoctorsScreen extends StatelessWidget {
  final String facilityId;
  final String specId;

  const DoctorsScreen({
    super.key,
    required this.facilityId,
    required this.specId,
  });

  Future<List<QueryDocumentSnapshot>> fetchDoctors() async {
    final snapshot =
        await FirebaseFirestore.instance
            .collection('medicalFacilities')
            .doc(facilityId)
            .collection('specializations')
            .doc(specId)
            .collection('doctors')
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
            "الأطباء",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Color.fromARGB(255, 78, 17, 175),
              fontSize: 30,
            ),
          ),
        ),
        body: FutureBuilder<List<QueryDocumentSnapshot>>(
          future: fetchDoctors(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting)
              return Center(child: CircularProgressIndicator());

            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return Center(
                child: Text(
                  'لا يوجد أطباء حالياً',
                  style: TextStyle(fontSize: 18),
                ),
              );
            }

            final doctors = snapshot.data!;

            return ListView.builder(
              itemCount: doctors.length,
              itemBuilder: (context, index) {
                final doc = doctors[index];
                final doctorData = doc.data() as Map<String, dynamic>;
                final doctorName = doctorData['docName'] ?? 'طبيب غير معروف';
                final photoUrl =
                    doctorData['photoUrl'] ??
                    'https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcQupVHd_oeqnkds0k3EjT1SX4ctwwblwYP2Uw&s';

                return GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder:
                            (context) => BookingScreen(
                              facilityId: facilityId,
                              specializationId: specId,
                              doctorId: doc.id,
                              name: doctorName,
                              workingSchedule: Map<String, dynamic>.from(
                                doc['workingSchedule'],
                              ),
                            ),
                      ),
                    );
                  },
                  child: Card(
                    margin: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    elevation: 6,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(50),
                            child: Image.network(
                              photoUrl,
                              width: 60,
                              height: 60,
                              fit: BoxFit.cover,
                            ),
                          ),
                          SizedBox(width: 16),

                          Expanded(
                            child: Text(
                              doctorName,
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Icon(
                            Icons.arrow_forward_ios,
                            color: Colors.grey[600],
                          ),
                        ],
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
