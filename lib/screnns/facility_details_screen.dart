import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hospital_app/screnns/specialties_screen.dart';
import 'package:hospital_app/screnns/insurance_companies_screen.dart';

class FacilityDetailsScreen extends StatefulWidget {
  final String facilityId;
  final String facilityName;

  const FacilityDetailsScreen({
    super.key,
    required this.facilityId,
    required this.facilityName,
  });

  @override
  State<FacilityDetailsScreen> createState() => _FacilityDetailsScreenState();
}

class _FacilityDetailsScreenState extends State<FacilityDetailsScreen> {
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
            widget.facilityName,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: const Color.fromARGB(255, 78, 17, 175),
              fontSize: 24,
            ),
          ),
        ),
        body: Container(
          color: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
                              children: [
                  // Cards section
                Expanded(
                  child: Column(
                    children: [
                      // Medical Specialties Card (احجز الان)
                      _buildCard(
                        title: "احجز الان",
                        subtitle: "استكشف التخصصات المتاحة",
                        icon: Icons.medical_services,
                        color: const Color.fromARGB(255, 78, 17, 175),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => SpecialtiesScreen(
                                facilityId: widget.facilityId,
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      
                      // Insurance Companies Card
                      _buildCard(
                        title: "شركات التأمين",
                        subtitle: "عرض شركات التأمين المتعاقدة",
                        icon: Icons.security,
                        color: const Color.fromARGB(255, 78, 17, 175),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => InsuranceCompaniesScreen(
                                facilityId: widget.facilityId,
                                facilityName: widget.facilityName,
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.2),
              spreadRadius: 2,
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  icon,
                  size: 32,
                  color: color,
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                color: color,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
