import 'package:flutter/material.dart';
import 'package:hospital_app/screnns/specialties_screen.dart';

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
            icon: Icon(Icons.arrow_back, color: Color(0xFF2FBDAF)),
          ),
          title: Text(
            widget.facilityName,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: const Color(0xFF2FBDAF),
              fontSize: 24,
            ),
          ),
        ),
        body: SafeArea(
          child: Container(
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
                          icon: Icons.event,
                          color: const Color(0xFF2FBDAF),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder:
                                    (context) => SpecialtiesScreen(
                                      facilityId: widget.facilityId,
                                    ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 16),
                        // Insurance Companies Card (disabled - coming soon)
                        _buildCard(
                          title: "شركات التأمين",
                          subtitle: "قريباً",
                          icon: Icons.security,
                          color: const Color(0xFF2FBDAF),
                          onTap: () {},
                          disabled: true,
                        ),

                        // Laboratory Results Card - تظهر فقط في مركز الرومي الطبي (وليس طب الأسنان)
                        if (widget.facilityName.contains('الرومي الطبي') &&
                            !widget.facilityName.contains('طب الأسنان')) ...[
                          const SizedBox(height: 16),
                        ],
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
    bool disabled = false,
  }) {
    return GestureDetector(
      onTap: disabled ? null : onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(disabled ? 0.6 : 1),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(disabled ? 0.1 : 0.2),
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
                  color: color.withOpacity(disabled ? 0.06 : 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  icon,
                  size: 32,
                  color: disabled ? color.withOpacity(0.5) : color,
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
                        color: disabled ? Colors.black54 : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 14,
                        color: disabled ? Colors.grey[500] : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                color: disabled ? color.withOpacity(0.5) : color,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
