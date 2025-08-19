import 'package:flutter/material.dart';
import 'package:introduction_screen/introduction_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hospital_app/screnns/login_screen.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  void _onIntroEnd(context) async {
    // حفظ أن المستخدم قد شاهد الـ onboarding
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hasSeenOnboarding', true);
    
    // الانتقال لشاشة تسجيل الدخول
    if (context.mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    }
  }

  void _onSkip(context) async {
    // حفظ أن المستخدم قد شاهد الـ onboarding
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hasSeenOnboarding', true);
    
    // الانتقال لشاشة تسجيل الدخول
    if (context.mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: IntroductionScreen(
      pages: [
        PageViewModel(
          title: "مرحبا بك",
          body:
              "اكتشف مجموعة واسعة من المرافق الطبية واختر ما يناسب احتياجاتك الصحية",
          image: Center(
            child: Image.asset(
              'assets/images/hospital.jpg',
              height: 500,
              fit: BoxFit.cover,
            ),
          ),
          decoration: PageDecoration(
            titleTextStyle: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.bold,
              color: const Color.fromARGB(255, 44, 13, 156),
            ),
            bodyTextStyle: TextStyle(fontSize: 20),
          ),
        ),
        PageViewModel(
          title: "اختر طبيبك",
          body:
              "تعرف على الاطباء المتاحين في مختلف التخصصات وحدد من تود زيارته بكل سهولة",
          image: Center(
            child: Image.asset(
              'assets/images/doctors.jpg',
              height: 500,
              fit: BoxFit.cover,
            ),
          ),
          decoration: PageDecoration(
            titleTextStyle: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.bold,
              color: const Color.fromARGB(255, 44, 13, 156),
            ),
            bodyTextStyle: TextStyle(fontSize: 20),
          ),
        ),
        PageViewModel(
          title: "احجز بكل سهولة",
          body: "حدد الوقت الذي يناسبك واحجز موعدك بكل سهولة",
          image: Center(
            child: Image.asset(
              'assets/images/booking.jpg',
              height: 500,
              fit: BoxFit.cover,
            ),
          ),
          decoration: PageDecoration(
            titleTextStyle: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.bold,
              color: const Color.fromARGB(255, 44, 13, 156),
            ),
            bodyTextStyle: TextStyle(fontSize: 20),
          ),
        ),
      ],
      onDone: () => _onIntroEnd(context),
      onSkip: () => _onSkip(context),
      showSkipButton: true,
      skip: const Text("تخطي"),
      next: const Icon(Icons.arrow_forward),
      overrideDone: TextButton(
        onPressed: () => _onIntroEnd(context),
        style: TextButton.styleFrom(
          backgroundColor: Color.fromARGB(255, 44, 13, 156),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          padding: EdgeInsets.all(5),
        ),
        child: Text(
          'ابدأ',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      showDoneButton: true,
      ),
    );
  }
}
