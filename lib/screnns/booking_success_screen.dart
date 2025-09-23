import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:share_plus/share_plus.dart';
import 'package:hospital_app/services/sms_service.dart';
import 'package:hospital_app/services/whatsapp_service.dart';
import 'dart:io';

class BookingSuccessScreen extends StatefulWidget {
  final String bookingId;
  final String patientName;
  final String patientPhone;
  final DateTime bookingDate;
  final String bookingTime;
  final String period;
  final String facilityName;
  final String specializationName;
  final String doctorName;
  final String? periodStartTime;

  const BookingSuccessScreen({
    super.key,
    required this.bookingId,
    required this.patientName,
    required this.patientPhone,
    required this.bookingDate,
    required this.bookingTime,
    required this.period,
    required this.facilityName,
    required this.specializationName,
    required this.doctorName,
    this.periodStartTime,
  });

  @override
  State<BookingSuccessScreen> createState() => _BookingSuccessScreenState();
}

class _BookingSuccessScreenState extends State<BookingSuccessScreen> {
  bool _sentOnce = false;

  @override
  void initState() {
    super.initState();
    // إرسال الرسائل بعد أول إطار لضمان توفّر السياق
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!_sentOnce) {
        _sentOnce = true;
        await _sendNotifications();
      }
    });
  }

  String _buildMessageBody() {
    final dayName = intl.DateFormat('EEEE', 'ar').format(widget.bookingDate);
    final formattedDate = intl.DateFormat('yyyy-MM-dd').format(widget.bookingDate);
    final periodText = widget.period == 'morning' ? 'صباحاً' : 'مساءً';
    final timeParts = widget.bookingTime.split(':');
    final hour = int.tryParse(timeParts[0]) ?? 0;
    final minute = timeParts.length > 1 ? timeParts[1] : '00';
    String displayTime;
    if (hour == 0) {
      displayTime = '12:$minute $periodText';
    } else if (hour < 12) {
      displayTime = '$hour:$minute $periodText';
    } else if (hour == 12) {
      displayTime = '12:$minute $periodText';
    } else {
      displayTime = '${hour - 12}:$minute $periodText';
    }
    return 'تطبيق جودة الطبي\n\nتم حجز موعد بنجاح\n\nاسم المركز: ${widget.facilityName}\nاسم المريض: ${widget.patientName}\nرقم الهاتف: ${widget.patientPhone}\nالطبيب: ${widget.doctorName} (${widget.specializationName})\nوقت الحجز: $dayName - $formattedDate - $displayTime\n\nشكراً لاختياركم تطبيق جودة الطبي';
  }

  Future<void> _sendNotifications() async {
    try {
      final message = _buildMessageBody();
      // SMS
      await SMSService.sendSimpleSMS(widget.patientPhone, message);
      // WhatsApp
      await WhatsAppService.sendSimpleMessage(widget.patientPhone, message);
    } catch (e) {
      // تجاهل الأخطاء حتى لا تؤثر على تجربة المستخدم
      // يمكن لاحقاً إضافة لوجيك لإعادة المحاولة
      // print('Notification error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    // تنسيق التاريخ والوقت
    final dayName = intl.DateFormat('EEEE', 'ar').format(widget.bookingDate);
    final formattedDate = intl.DateFormat('yyyy-MM-dd').format(widget.bookingDate);
    
    // تحويل الوقت إلى 12 ساعة
    final timeParts = widget.bookingTime.split(':');
    final hour = int.parse(timeParts[0]);
    final minute = timeParts[1];
    final periodText = widget.period == 'morning' ? 'صباحاً' : 'مساءً';
    
    String displayTime;
    if (hour == 0) {
      displayTime = '12:$minute $periodText';
    } else if (hour < 12) {
      displayTime = '$hour:$minute $periodText';
    } else if (hour == 12) {
      displayTime = '12:$minute $periodText';
    } else {
      displayTime = '${hour - 12}:$minute $periodText';
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            'تم الحجز بنجاح',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: const Color(0xFF2FBDAF),
              fontSize: 24,
            ),
          ),
          backgroundColor: Colors.white,
          elevation: 0,
          iconTheme: IconThemeData(color: const Color(0xFF2FBDAF)),
        ),
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.white,
                Colors.grey[50]!,
              ],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // أيقونة النجاح
                  Container(
                    width: 84,
                    height: 84,
                    decoration: BoxDecoration(
                      color: Colors.green[50],
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.green[300]!,
                        width: 2,
                      ),
                    ),
                    child: Icon(
                      Icons.check_circle,
                      size: 56,
                      color: Colors.green[600],
                    ),
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // عنوان النجاح
                  Text(
                    'تم الحجز بنجاح',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF2FBDAF),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // بطاقة تفاصيل الحجز
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.1),
                          spreadRadius: 2,
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // عنوان البطاقة
                        // عنوان القسم بدون أيقونة
                        Text(
                          'تفاصيل الحجز',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF2FBDAF),
                          ),
                        ),
                        
                        const SizedBox(height: 12),
                        
                        // المركز أولاً
                        _buildDetailRow(
                          icon: Icons.business,
                          label: 'اسم المركز',
                          value: widget.facilityName,
                        ),
                        
                        const SizedBox(height: 10),
                        
                        // اسم المريض
                        _buildDetailRow(
                          icon: Icons.person,
                          label: 'اسم المريض',
                          value: widget.patientName,
                        ),
                        
                        const SizedBox(height: 10),
                        
                        // رقم الهاتف
                        _buildDetailRow(
                          icon: Icons.phone,
                          label: 'رقم الهاتف',
                          value: widget.patientPhone,
                        ),
                        
                        const SizedBox(height: 10),
                        
                        // الطبيب (التخصص بين قوسين)
                        _buildDetailRow(
                          icon: Icons.person_outline,
                          label: 'الطبيب',
                          value: '${widget.doctorName} (${widget.specializationName})',
                        ),
                        
                        const SizedBox(height: 12),
                        
                        // خط فاصل
                        Container(
                          height: 1,
                          color: Colors.grey[200],
                        ),
                        
                        const SizedBox(height: 12),
                        
                        // عنوان وقت الحجز بدون أيقونة
                        Text(
                          'وقت الحجز',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF2FBDAF),
                          ),
                        ),
                        const SizedBox(height: 8),
                        // تفاصيل الموعد في سطر واحد
                        Text(
                          '$dayName - $formattedDate - $displayTime',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange[700],
                          ),
                        ),
                        
                        const SizedBox(height: 12),
                        
                        // تم إلغاء عرض معرف الحجز حسب الطلب
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // زرّان: PDF وموافق
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _showPdfOptions(context),
                          icon: Icon(Icons.picture_as_pdf, color: Colors.white, size: 20),
                          label: Text(
                            'PDF',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2FBDAF),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 2,
                            minimumSize: const Size.fromHeight(48),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                          },
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: Colors.grey[300]!),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            minimumSize: const Size.fromHeight(48),
                          ),
                          child: Text(
                            'موافق',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[700],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: valueColor ?? Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _downloadPdf(BuildContext context) async {
    try {
      // البحث عن ملف PDF المحفوظ
      final tempDir = await getTemporaryDirectory();
      final pdfFile = File('${tempDir.path}/booking_${widget.bookingId}.pdf');
      
      if (await pdfFile.exists()) {
        // فتح ملف PDF باستخدام open_file
        await OpenFile.open(pdfFile.path);
        
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تم فتح ملف PDF'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('ملف PDF غير موجود'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      print('خطأ في فتح PDF: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في فتح ملف PDF: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _sharePdf(BuildContext context) async {
    try {
      // البحث عن ملف PDF المحفوظ
      final tempDir = await getTemporaryDirectory();
      final pdfFile = File('${tempDir.path}/booking_${widget.bookingId}.pdf');
      
      if (await pdfFile.exists()) {
        // مشاركة ملف PDF
        await Share.shareXFiles(
          [XFile(pdfFile.path)],
          text: 'حجز طبي - ${widget.patientName}',
        );
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('ملف PDF غير موجود'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      print('خطأ في مشاركة PDF: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في مشاركة ملف PDF: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showPdfOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'خيارات PDF',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    leading: Icon(Icons.download, color: const Color(0xFF2FBDAF)),
                    title: const Text(' فتح'),
                    onTap: () async {
                      Navigator.pop(ctx);
                      await _downloadPdf(context);
                    },
                  ),
                  ListTile(
                    leading: Icon(Icons.share, color: const Color(0xFF2FBDAF)),
                    title: const Text('مشاركة'),
                    onTap: () async {
                      Navigator.pop(ctx);
                      await _sharePdf(context);
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
