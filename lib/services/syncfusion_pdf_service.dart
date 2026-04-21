import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:path_provider/path_provider.dart';
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

  // دالة لإنشاء علامة مائية شفافة من صورة اللوقو
  static Future<void> _addWatermark(PdfGraphics graphics, double pageWidth, double pageHeight) async {
    try {
      // تحميل صورة اللوقو
      final ByteData logoData = await rootBundle.load('assets/images/logo.png');
      final PdfBitmap logo = PdfBitmap(logoData.buffer.asUint8List());
      
      // رسم العلامة المائية عادية (بدون زاوية) في الجزء العلوي من الصفحة
      // حجم كبير لتغطي معظم الشاشة
      double watermarkWidth = pageWidth * 0.8; // 80% من عرض الصفحة
      double watermarkHeight = pageHeight * 0.6; // 60% من ارتفاع الصفحة
      
      // حساب الموضع ليكون في الجزء العلوي (مرفوع لأعلى)
      double x = (pageWidth - watermarkWidth) / 2;
      double y = pageHeight * 0.1; // رفع العلامة المائية لأعلى (10% من أعلى الصفحة)
      
      // رسم اللوقو كعلامة مائية شفافة جداً (شفافية 0.05)
      graphics.save();
      graphics.setTransparency(0.05); // شفافية 0.05 (5% فقط)
      graphics.drawImage(
        logo,
        Rect.fromLTWH(x, y, watermarkWidth, watermarkHeight),
      );
      graphics.restore();
      
    } catch (e) {
      print('خطأ في إنشاء العلامة المائية: $e');
    }
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
    String? periodStartTime,
  }) async {
    try {
      // إنشاء مستند PDF جديد
      PdfDocument document = PdfDocument();
      
      // إضافة صفحة جديدة
      PdfPage page = document.pages.add();
      
      // الحصول على الرسومات
      PdfGraphics graphics = page.graphics;
      
       // إضافة العلامة المائية أولاً
       await _addWatermark(graphics, page.getClientSize().width, page.getClientSize().height);
      
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
      
      // تنسيق التاريخ والوقت
      String formattedDate = '${bookingDate.day}/${bookingDate.month}/${bookingDate.year}';
      String periodText = period == 'morning' ? 'صباحاً' : 'مساءً';
      String dateWithTime = '$formattedDate ($bookingTime $periodText)';
      
      // دمج اسم الطبيب مع التخصص
      String doctorWithSpecialization = '$doctorName ($specializationName)';
      
      // إعدادات الصفحة
      double pageWidth = page.getClientSize().width;
      double margin = 50;
      double yPosition = margin;
      
      // إضافة شعار واحد فقط في اليمين
      try {
        final ByteData logoData = await rootBundle.load('assets/images/logo.png');
        final PdfBitmap logo = PdfBitmap(logoData.buffer.asUint8List());
        
        // رسم الشعار في الجانب الأيمن فقط
        graphics.drawImage(
          logo,
          Rect.fromLTWH(pageWidth - margin - 60, yPosition, 60, 60),
        );
        
        // العنوان الرئيسي في الوسط
        PdfStringFormat titleFormat = PdfStringFormat(
        alignment: PdfTextAlignment.center,
          textDirection: PdfTextDirection.rightToLeft,
      );
      
      graphics.drawString(
          'تفاصيل الحجز الطبي',
        titleFont,
          brush: PdfSolidBrush(PdfColor(0, 0, 0)),
          bounds: Rect.fromLTWH(margin, yPosition, pageWidth - 2 * margin - 80, 60),
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
        'الطبيب: $doctorWithSpecialization',
        'اسم المريض: $patientName',
        'رقم الهاتف: $patientPhone',
        'تاريخ ووقت الحجز: $dateWithTime',
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
         '• في حالة التأخير سيتم الغاء الحجز تلقائيا',
         '• إحضار التقارير الطبية السابقة إن وجدت',
         '• في حالة عدم الرغبة في الحضور يرجى إلغاء الحجز',
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

  // دالة جديدة ترجع بيانات PDF كـ Uint8List
  static Future<Uint8List> generateBookingPdfData({
    required String facilityName,
    required String specializationName,
    required String doctorName,
    required String patientName,
    required String patientPhone,
    required DateTime bookingDate,
    required String bookingTime,
    required String period,
    required String bookingId,
    String? periodStartTime,
  }) async {
    try {
      // إنشاء مستند PDF جديد
      PdfDocument document = PdfDocument();
      
      // إضافة صفحة جديدة
      PdfPage page = document.pages.add();
      
      // الحصول على الرسومات
      PdfGraphics graphics = page.graphics;
      
       // إضافة العلامة المائية أولاً
       await _addWatermark(graphics, page.getClientSize().width, page.getClientSize().height);
      
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
      
      // تنسيق التاريخ والوقت
      String formattedDate = '${bookingDate.day}/${bookingDate.month}/${bookingDate.year}';
      String periodText = period == 'morning' ? 'صباحاً' : 'مساءً';
      String dateWithTime = '$formattedDate ($bookingTime $periodText)';
      
      // دمج اسم الطبيب مع التخصص
      String doctorWithSpecialization = '$doctorName ($specializationName)';
      
      // إعدادات الصفحة
      double pageWidth = page.getClientSize().width;
      double margin = 50;
      double yPosition = margin;
      
      // إضافة شعار واحد فقط في اليمين
      try {
        final ByteData logoData = await rootBundle.load('assets/images/logo.png');
        final PdfBitmap logo = PdfBitmap(logoData.buffer.asUint8List());
        
        // رسم الشعار في الجانب الأيمن فقط
        graphics.drawImage(
          logo,
          Rect.fromLTWH(pageWidth - margin - 60, yPosition, 60, 60),
        );
        
        // العنوان الرئيسي في الوسط
        PdfStringFormat titleFormat = PdfStringFormat(
          alignment: PdfTextAlignment.center,
          textDirection: PdfTextDirection.rightToLeft,
        );
      
        graphics.drawString(
          'تفاصيل الحجز الطبي',
          titleFont,
          brush: PdfSolidBrush(PdfColor(0, 0, 0)),
          bounds: Rect.fromLTWH(margin, yPosition, pageWidth - 2 * margin - 80, 60),
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
        'الطبيب: $doctorWithSpecialization',
        'اسم المريض: $patientName',
        'رقم الهاتف: $patientPhone',
        'تاريخ ووقت الحجز: $dateWithTime',
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
         '• في حالة التأخير سيتم الغاء الحجز تلقائيا',
         '• إحضار التقارير الطبية السابقة إن وجدت',
         '• في حالة عدم الرغبة في الحضور يرجى إلغاء الحجز',
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
      
      // حفظ البيانات وإرجاعها
      final List<int> pdfData = await document.save();
      document.dispose();
      
      return Uint8List.fromList(pdfData);
      
    } catch (e) {
      print('خطأ في توليد PDF: $e');
      throw Exception('فشل في إنشاء PDF: $e');
    }
  }
}