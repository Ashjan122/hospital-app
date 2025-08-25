import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hospital_app/screnns/hospital_screen.dart';
import 'package:hospital_app/screnns/patient_bookings_screen.dart';
import 'package:hospital_app/screnns/login_screen.dart';
import 'package:hospital_app/screnns/about_screen.dart';

class PatientHomeScreen extends StatefulWidget {
  const PatientHomeScreen({super.key});

  @override
  State<PatientHomeScreen> createState() => _PatientHomeScreenState();
}

class _PatientHomeScreenState extends State<PatientHomeScreen> {
  String? patientEmail;
  String? patientName;

  @override
  void initState() {
    super.initState();
    _loadPatientData();
  }

  Future<void> _loadPatientData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      patientEmail = prefs.getString('userEmail');
      patientName = prefs.getString('userName') ?? 'مريض عزيز';
    });
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
            "الرئيسية",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: const Color(0xFF2FBDAF),
              fontSize: 30,
            ),
          ),
          leading: IconButton(
            icon: const Icon(Icons.info_outline, color: Color(0xFF2FBDAF)),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const AboutScreen()),
              );
            },
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.logout, color: Color(0xFF2FBDAF)),
              onPressed: () async {
                // Clear saved login data
                final prefs = await SharedPreferences.getInstance();
                await prefs.clear();

                // Navigate to login screen
                if (context.mounted) {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (context) => const LoginScreen()),
                    (route) => false,
                  );
                }
              },
            ),
          ],
        ),
        body: SafeArea(
          child: Container(
            color: Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  // Welcome message
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.1),
                          spreadRadius: 2,
                          blurRadius: 15,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Text(
                          "مرحباً بك",
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF2FBDAF),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          patientName ?? 'مريض عزيز',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Cards section
                  Expanded(
                    child: Column(
                      children: [
                        // My Bookings Card
                        _buildCard(
                          title: "حجوزاتي",
                          subtitle: "عرض وإدارة حجوزاتك",
                          icon: Icons.calendar_today,
                          color: const Color(0xFF2FBDAF),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const PatientBookingsScreen(),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 16),
                        
                        // Medical Facilities Card
                        _buildCard(
                          title: "المرافق الطبية",
                          subtitle: "استكشف المرافق والحجز",
                          icon: Icons.medication,
                          color: Colors.green,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const HospitalScreen(),
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
