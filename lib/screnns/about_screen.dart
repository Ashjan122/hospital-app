import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:hospital_app/services/app_update_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';
import 'dart:async';

class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  String _currentVersion = '';
  String _firebaseVersion = '';
  String? _updateUrl;
  bool _isLoading = true;
  List<String> _supportPhones = [];
  StreamSubscription? _supportPhonesSub;

  @override
  void initState() {
    super.initState();
    _loadData();
    _listenSupportPhones();
  }

  Future<void> _loadData() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      // قراءة بيانات التحديث مباشرة من Firebase لعرض رقم الإصدار هناك
      final doc = await FirebaseFirestore.instance
          .collection('appConfig')
          .doc('version')
          .get();

      final data = doc.data() ?? {};
      final firebaseVersion = (data['lastVersion'] as String?) ?? '';
      final updateUrl = data['updatrUrl'] as String?;

      setState(() {
        _currentVersion = packageInfo.version;
        _firebaseVersion = firebaseVersion;
        _updateUrl = updateUrl;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _listenSupportPhones() {
    // live updates from support/phones { numbers: [...] }
    _supportPhonesSub?.cancel();
    _supportPhonesSub = FirebaseFirestore.instance
        .collection('support')
        .doc('phones')
        .snapshots()
        .listen((doc) {
      final nums = (doc.data()?['numbers'] as List?)
              ?.map((e) => (e ?? '').toString().trim())
              .where((s) => s.isNotEmpty)
              .cast<String>()
              .toList() ?? [];
      if (mounted) setState(() { _supportPhones = nums; });
    }, onError: (_) {});
  }

  @override
  void dispose() {
    _supportPhonesSub?.cancel();
    super.dispose();
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri phoneUri = Uri(scheme: 'tel', path: phoneNumber);
    try {
      if (await canLaunchUrl(phoneUri)) {
        await launchUrl(phoneUri);
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('لا يمكن فتح تطبيق الهاتف')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ في الاتصال: $e')),
      );
    }
  }

  void _copyPhoneNumber(String phoneNumber) {
    Clipboard.setData(ClipboardData(text: phoneNumber));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('تم نسخ الرقم: $phoneNumber')),
    );
  }

  Widget _buildPhoneNumber(String phoneNumber) {
    return GestureDetector(
      onTap: () => _makePhoneCall(phoneNumber),
      onLongPress: () => _copyPhoneNumber(phoneNumber),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Text(
          phoneNumber,
          style: const TextStyle(
            color: Color(0xFF2FBDAF),
            fontSize: 16,
            fontWeight: FontWeight.w500,
            decoration: TextDecoration.underline,
          ),
        ),
      ),
    );
  }

  Future<void> _handleCheckAndUpdate() async {
    // يقارن الإصدار الحالي مع إصدار Firebase ويفتح الرابط إذا كان هناك تحديث
    try {
      if (_firebaseVersion.isEmpty || _updateUrl == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('بيانات التحديث غير متاحة حالياً')),
        );
        return;
      }

      // مقارنة الإصدارات بصيغة x.y.z
      int _cmp(String a, String b) {
        final ap = a.split('.').map((e) => int.tryParse(e) ?? 0).toList();
        final bp = b.split('.').map((e) => int.tryParse(e) ?? 0).toList();
        while (ap.length < bp.length) ap.add(0);
        while (bp.length < ap.length) bp.add(0);
        for (int i = 0; i < ap.length; i++) {
          if (ap[i] < bp[i]) return -1;
          if (ap[i] > bp[i]) return 1;
        }
        return 0;
      }

      final comparison = _cmp(_currentVersion, _firebaseVersion);
      if (comparison < 0) {
        // يوجد تحديث
        final ok = await AppUpdateService.openUpdateUrl(_updateUrl!);
        if (ok && mounted) {
          // تحديث رقم الإصدار المحلي بعد فتح رابط التحديث
          setState(() {
            _currentVersion = _firebaseVersion;
          });
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('تم فتح رابط التحديث. الإصدار الجديد: $_firebaseVersion'),
              backgroundColor: Colors.blue,
            ),
          );
        } else if (!ok && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('لا يمكن فتح رابط التحديث')),
          );
        }
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('التطبيق محدث'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر فحص التحديث: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasFirebaseVersion = _firebaseVersion.isNotEmpty;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          centerTitle: true,
          title: const Text(
            'حول التطبيق',
            style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2FBDAF), fontSize: 30),
          ),
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF2FBDAF),
          elevation: 0,
        ),
        body: SafeArea(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header: Logo placeholder + App name + brief
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.12),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            )
                          ],
                          border: Border.all(color: Colors.grey[200]!),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.asset(
                                  'assets/images/icon.png',
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: const [
                                  Text('جودة', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                                  SizedBox(height: 6),
                                  Text(
                                    'هو تطبيق لحجز المواعيد الطبية بسهولة من اي مكان حيث يمكنك اختيار المستشفى او المركز والطبيب المناسب لك بكل سهولة .',
                                    style: TextStyle(color: Colors.black87, height: 1.4),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Features (expandable)
                      ExpandableSection(
                        title: 'المميزات الرئيسية',
                        child: const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _Bullet(text: 'اختيار المستشفى او المركز الطبي'),
                            _Bullet(text: 'عرض شركات التأمين'),
                            _Bullet(text: 'تحديد التخصص الطبي'),
                            _Bullet(text: 'عرض الاطباء ومواعيدهم'),
                            _Bullet(text: 'الحجز المباشر'),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Version (expandable)
                      ExpandableSection(
                        title: 'معلومات الإصدار',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('رقم الإصدار: $_currentVersion', style: TextStyle(color: Colors.grey[700])),
                            if (hasFirebaseVersion && _firebaseVersion != _currentVersion) ...[
                              const SizedBox(height: 8),
                              Text(
                                'الإصدار الجديد المتاح: $_firebaseVersion',
                                style: TextStyle(
                                  color: Colors.green[700],
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: _handleCheckAndUpdate,
                                icon: const Icon(Icons.system_update, color: Colors.white),
                                label: Text(
                                  hasFirebaseVersion && _firebaseVersion != _currentVersion
                                      ? 'تحديث التطبيق'
                                      : 'فحص الإصدار والتحديث'
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF2FBDAF),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Developer (expandable)
                      const ExpandableSection(
                        title: 'عن المطور',
                        child: Text('تم تطويره من قبل نجوم الانتاج', style: TextStyle(color: Colors.black87)),
                      ),

                      const SizedBox(height: 16),

                      // Support (expandable)
                      ExpandableSection(
                        title: 'الدعم الفني ووسائل التواصل',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (_supportPhones.isEmpty)
                              Text('لا توجد أرقام متاحة حالياً', style: TextStyle(color: Colors.grey[600]))
                            else
                              ...List.generate(_supportPhones.length, (i) => _buildPhoneNumber(_supportPhones[i])),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Policies (each expandable)
                      ExpandableSection(
                        title: 'سياسة الخصوصية',
                        child: Text(
                          'نحترم خصوصيتك. يتم استخدام بياناتك فقط لأغراض تقديم الخدمة وتحسين التجربة. لا نشارك بياناتك مع أطراف ثالثة إلا وفق القوانين أو بموافقتك.',
                          style: TextStyle(color: Colors.grey[700], height: 1.5),
                        ),
                      ),

                      const SizedBox(height: 16),

                      ExpandableSection(
                        title: 'الشروط والأحكام',
                        child: Text(
                          'باستخدامك للتطبيق فإنك توافق على الشروط والأحكام الخاصة باستخدام الخدمة، وتشمل الالتزام بالمواعيد وعدم إساءة الاستخدام والمحافظة على سرية بيانات دخولك.',
                          style: TextStyle(color: Colors.grey[700], height: 1.5),
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  final String text;
  const _Bullet({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(fontSize: 16)),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 14))),
        ],
      ),
    );
  }
}

class _PolicyItem extends StatelessWidget {
  final String title;
  final String content;

  const _PolicyItem({
    required this.title,
    required this.content,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        Text(
          content,
          style: TextStyle(color: Colors.grey[700], height: 1.4),
        ),
      ],
    );
  }
}

class ExpandableSection extends StatefulWidget {
  final String title;
  final Widget child;
  const ExpandableSection({super.key, required this.title, required this.child});

  @override
  State<ExpandableSection> createState() => _ExpandableSectionState();
}

class _ExpandableSectionState extends State<ExpandableSection> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.12),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        children: [
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 8),
            title: Text(widget.title, style: const TextStyle(fontWeight: FontWeight.bold)),
            trailing: Transform.rotate(
              angle: _open ? 1.5708 : 0,
              child: const Icon(Icons.arrow_right, color: Colors.black54),
            ),
            onTap: () => setState(() => _open = !_open),
          ),
          if (_open)
            Padding(
              padding: const EdgeInsets.only(right: 8, left: 8, bottom: 12),
              child: Align(alignment: Alignment.centerRight, child: widget.child),
            ),
        ],
      ),
    );
  }
}

class _ExpandablePolicy extends StatefulWidget {
  final List<_PolicyItem> sections;
  const _ExpandablePolicy({required this.sections});

  @override
  State<_ExpandablePolicy> createState() => _ExpandablePolicyState();
}

class _ExpandablePolicyState extends State<_ExpandablePolicy> {
  final List<bool> _expanded = [];

  @override
  void initState() {
    super.initState();
    _expanded.addAll(List<bool>.filled(widget.sections.length, false));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.12),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        children: List.generate(widget.sections.length, (index) {
          final section = widget.sections[index];
          final isOpen = _expanded[index];
          return Column(
            children: [
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                title: Text(section.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                trailing: Transform.rotate(
                  angle: isOpen ? 1.5708 : 0, // 90 deg when open
                  child: const Icon(Icons.arrow_right, color: Colors.black54),
                ),
                onTap: () {
                  setState(() {
                    _expanded[index] = !isOpen;
                  });
                },
              ),
              if (isOpen)
                Padding(
                  padding: const EdgeInsets.only(right: 8, left: 8, bottom: 12),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      section.content,
                      style: TextStyle(color: Colors.grey[700], height: 1.5),
                    ),
                  ),
                ),
              if (index != widget.sections.length - 1)
                Divider(height: 1, color: Colors.grey[200]),
            ],
          );
        }),
      ),
    );
  }
}

