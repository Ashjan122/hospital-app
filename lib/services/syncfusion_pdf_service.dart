import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:qr_flutter/qr_flutter.dart';
import 'dart:convert';

class SyncfusionPdfService {
  // دالة لإنشاء QR code كصورة
  static Future<Uint8List> _generateQrCodeImage(String data) async {
    final qrPainter = QrPainter(
      data: data,
      version: QrVersions.auto,
      gapless: false,
      color: const Color(0xFF000000),
      emptyColor: const Color(0xFFFFFFFF),
    );
    
    final imageData = await qrPainter.toImageData(200.0);
    return imageData!.buffer.asUint8List();
  }
  static Future<void> generateBookingPdf({
    required String facilityName,
    required String specializationName,
    required String doctorName,
    required String patientName,
    required String patientPhone,
    required DateTime bookingDate,
    required String bookingTime,
    required String period,
    required String bookingId,
  }) async {
    try {
      // إنشاء مستند PDF جديد
      PdfDocument document = PdfDocument();
      
      // إضافة صفحة جديدة
      PdfPage page = document.pages.add();
      
      // الحصول على الرسومات
      PdfGraphics graphics = page.graphics;
      
      // تحميل الخط العربي
      PdfFont arabicFont = PdfStandardFont(PdfFontFamily.helvetica, 12);
      PdfFont titleFont = PdfStandardFont(PdfFontFamily.helvetica, 24, style: PdfFontStyle.bold);
      PdfFont boldFont = PdfStandardFont(PdfFontFamily.helvetica, 16, style: PdfFontStyle.bold);
      
      // محاولة تحميل خط Noto أولاً
      try {
        final ByteData fontData = await rootBundle.load('assets/fonts/NotoNaskhArabic-Regular.ttf');
        arabicFont = PdfTrueTypeFont(fontData.buffer.asUint8List(), 12);
        titleFont = PdfTrueTypeFont(fontData.buffer.asUint8List(), 24);
        boldFont = PdfTrueTypeFont(fontData.buffer.asUint8List(), 16);
        print('تم تحميل خط Noto بنجاح');
      } catch (e) {
        print('فشل في تحميل خط Noto، محاولة تحميل خط Cairo');
        try {
          final ByteData fontData = await rootBundle.load('assets/fonts/Cairo-Regular.ttf');
          arabicFont = PdfTrueTypeFont(fontData.buffer.asUint8List(), 12);
          titleFont = PdfTrueTypeFont(fontData.buffer.asUint8List(), 24);
          boldFont = PdfTrueTypeFont(fontData.buffer.asUint8List(), 16);
          print('تم تحميل خط Cairo بنجاح');
        } catch (e) {
          print('فشل في تحميل خط Cairo، محاولة تحميل خط Amiri');
          try {
            final ByteData fontData = await rootBundle.load('assets/fonts/Amiri-Regular.ttf');
            arabicFont = PdfTrueTypeFont(fontData.buffer.asUint8List(), 12);
            titleFont = PdfTrueTypeFont(fontData.buffer.asUint8List(), 24);
            boldFont = PdfTrueTypeFont(fontData.buffer.asUint8List(), 16);
            print('تم تحميل خط Amiri بنجاح');
          } catch (e) {
            print('فشل في تحميل الخطوط العربية، استخدام الخط الافتراضي');
            // استخدام خط يدعم العربية بشكل أفضل
            arabicFont = PdfStandardFont(PdfFontFamily.timesRoman, 12);
            titleFont = PdfStandardFont(PdfFontFamily.timesRoman, 24, style: PdfFontStyle.bold);
            boldFont = PdfStandardFont(PdfFontFamily.timesRoman, 16, style: PdfFontStyle.bold);
          }
        }
      }
      
      // تنسيق التاريخ
      String formattedDate = '${bookingDate.day}/${bookingDate.month}/${bookingDate.year}';
      String periodText = period == 'morning' ? 'صباحاً' : 'مساءً';
      
      // إعدادات الصفحة
      double pageWidth = page.getClientSize().width;
      double pageHeight = page.getClientSize().height;
      double margin = 50;
      double yPosition = margin;
      
      // إضافة شعار جودة والعنوان في نفس الصف
      try {
        final ByteData logoData = await rootBundle.load('assets/images/logo.png');
        final PdfBitmap logo = PdfBitmap(logoData.buffer.asUint8List());
        
       
        graphics.drawImage(
          logo,
          Rect.fromLTWH(pageWidth - margin - 60, yPosition, 60, 60),
        );
        
        // رسم الشعار في الجانب الأيسر
        graphics.drawImage(
          logo,
          Rect.fromLTWH(margin, yPosition, 60, 60),
        );
        
        // العنوان الرئيسي في النص بين الشعارين
        PdfStringFormat titleFormat = PdfStringFormat(
        alignment: PdfTextAlignment.center,
          textDirection: PdfTextDirection.rightToLeft,
      );
      
      graphics.drawString(
          'تفاصيل الحجز الطبي',
        titleFont,
          brush: PdfSolidBrush(PdfColor(0, 0, 0)),
          bounds: Rect.fromLTWH(margin + 80, yPosition, pageWidth - 2 * margin - 160, 60),
          format: titleFormat,
        );
        
        yPosition += 40; // تقليل المسافة بعد الصف
      } catch (e) {
        print('فشل في تحميل الشعار: $e');
        yPosition += 20; // مسافة أقل إذا فشل تحميل الشعار
      }
      
      yPosition += 60;
      
      // تفاصيل الحجز
      PdfStringFormat detailsFormat = PdfStringFormat(
        alignment: PdfTextAlignment.right,
        textDirection: PdfTextDirection.rightToLeft,
      );
      
      List<String> details = [
        'اسم المركز: $facilityName',
        'التخصص: $specializationName',
        'الطبيب: $doctorName',
        'اسم المريض: $patientName',
        'رقم الهاتف: $patientPhone',
        'تاريخ الحجز: $formattedDate',
        'وقت الحجز: $bookingTime $periodText',
      ];
      
      for (String detail in details) {
        graphics.drawString(
          detail,
          arabicFont,
          brush: PdfSolidBrush(PdfColor(0, 0, 0)),
          bounds: Rect.fromLTWH(margin, yPosition, pageWidth - 2 * margin, 30),
          format: detailsFormat,
        );
        yPosition += 35;
      }
      
      yPosition += 20;
      
      // ملاحظات مهمة
      graphics.drawString(
        'ملاحظات مهمة:',
        boldFont,
        brush: PdfSolidBrush(PdfColor(255, 0, 0)),
        bounds: Rect.fromLTWH(margin, yPosition, pageWidth - 2 * margin, 30),
        format: detailsFormat,
      );
      
      yPosition += 35;
      
      List<String> notes = [
        '• يرجى الحضور قبل الموعد بـ 15 دقيقة',
        '• إحضار الهوية الشخصية',
        '• إحضار التقارير الطبية السابقة إن وجدت',
        '• في حالة عدم الحضور سيتم إلغاء الحجز تلقائياً',
      ];
      
      for (String note in notes) {
        graphics.drawString(
          note,
          arabicFont,
          brush: PdfSolidBrush(PdfColor(0, 0, 0)),
          bounds: Rect.fromLTWH(margin, yPosition, pageWidth - 2 * margin, 25),
          format: detailsFormat,
        );
        yPosition += 30;
      }
      
              yPosition += 20; // تقليل المسافة قبل QR code
        
        // إضافة QR code فوق الفاصل في الجانب الأيسر
        try {
          // إنشاء بيانات QR code تحتوي على ID الحجز واسم المريض فقط
          Map<String, String> qrData = {
            'bookingId': bookingId,
            'patientName': patientName,
          };
          
          String qrCodeData = jsonEncode(qrData);
          Uint8List qrImageData = await _generateQrCodeImage(qrCodeData);
          PdfBitmap qrBitmap = PdfBitmap(qrImageData);
          
          // رسم QR code في الجانب الأيسر فوق الفاصل
          double qrSize = 80;
          graphics.drawImage(
            qrBitmap,
            Rect.fromLTWH(margin, yPosition, qrSize, qrSize),
          );
          
          // إضافة نص توضيحي تحت QR code
          graphics.drawString(
            'QR Code للحجز',
            arabicFont,
            brush: PdfSolidBrush(PdfColor(0, 0, 0)),
            bounds: Rect.fromLTWH(margin, yPosition + qrSize + 5, qrSize, 20),
            format: PdfStringFormat(
              alignment: PdfTextAlignment.center,
              textDirection: PdfTextDirection.rightToLeft,
            ),
          );
          
          yPosition += qrSize + 30; // زيادة المسافة بعد QR code
        } catch (e) {
          print('فشل في إنشاء QR code: $e');
          yPosition += 20;
        }
        
        yPosition += 20; // مسافة إضافية قبل الفاصل
        
        // فاصل بخط أسود في نهاية الصفحة
        graphics.drawLine(
          PdfPen(PdfColor(0, 0, 0), width: 2),
          Offset(margin, yPosition),
          Offset(pageWidth - margin, yPosition),
        );
        
        yPosition += 20;
        
                // نجوم الإنتاج والرقم في نفس الصف
        // النص في أقصى اليمين
        graphics.drawString(
          'نجوم الإنتاج .. أنظمة وتطبيقات ذكية لمستقبل أعمالك',
          arabicFont,
          brush: PdfSolidBrush(PdfColor(0, 0, 0)),
          bounds: Rect.fromLTWH(pageWidth - margin - 300, yPosition, 300, 25),
          format: PdfStringFormat(
            alignment: PdfTextAlignment.right,
            textDirection: PdfTextDirection.rightToLeft,
          ),
        );
        
        // رقم الهاتف مع رمز واتساب في أقصى الشمال
        graphics.drawString(
          '📞 +249991961111',
          arabicFont,
          brush: PdfSolidBrush(PdfColor(0, 0, 0)),
          bounds: Rect.fromLTWH(margin, yPosition, 200, 25),
          format: PdfStringFormat(
            alignment: PdfTextAlignment.left,
            textDirection: PdfTextDirection.rightToLeft,
          ),
        );
        
        yPosition += 20;
        
        // حفظ الملف
      final Directory appDocDir = await getApplicationDocumentsDirectory();
      final String filePath = '${appDocDir.path}/booking_confirmation.pdf';
      final File file = File(filePath);
      await file.writeAsBytes(await document.save());
      document.dispose();
      
      // لا نقوم بالمشاركة التلقائية هنا، سيتم التعامل معها في الواجهة
      
    } catch (e) {
      print('خطأ في توليد PDF: $e');
      throw Exception('فشل في إنشاء PDF: $e');
    }
  }
}
