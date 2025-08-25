import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/date_symbol_data_local.dart';

class PdfTest {
  static Future<File> createSimplePdf() async {
    try {
      print('بدء إنشاء PDF بسيط...');
      
      // تهيئة البيانات المحلية للغة العربية
      await initializeDateFormatting('ar');
      
      final pdf = pw.Document();

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return pw.Container(
              padding: const pw.EdgeInsets.all(40),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'اختبار PDF',
                    style: pw.TextStyle(
                      fontSize: 24,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.blue,
                    ),
                  ),
                  pw.SizedBox(height: 20),
                  pw.Text(
                    'هذا اختبار بسيط لإنشاء PDF',
                    style: pw.TextStyle(fontSize: 16),
                  ),
                  pw.SizedBox(height: 20),
                  pw.Text(
                    'التاريخ: ${DateTime.now().toString()}',
                    style: pw.TextStyle(fontSize: 12),
                  ),
                ],
              ),
            );
          },
        ),
      );

      print('حفظ PDF بسيط...');
      
      final fileName = 'test_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final file = File('./$fileName'); // حفظ في مجلد التطبيق الحالي
      
      final bytes = await pdf.save();
      await file.writeAsBytes(bytes);
      
      print('تم إنشاء PDF بسيط بنجاح: ${file.path}');
      print('حجم الملف: ${bytes.length} bytes');
      
      return file;
    } catch (e, stackTrace) {
      print('خطأ في إنشاء PDF بسيط: $e');
      print('Stack trace: $stackTrace');
      throw Exception('فشل في إنشاء PDF بسيط: $e');
    }
  }
}
