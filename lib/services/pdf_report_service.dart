import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';

class PDFReportService {
  static Future<void> generateAndDownloadReport({
    required String title,
    required List<String> headers,
    required List<List<String>> data,
    String? dateRangeText,
    String dateFormatString = 'dd/MM/yyyy',
    bool landscape = false,
    Map<String, String>? legend,
    Map<int, pw.TableColumnWidth>? columnWidths,
  }) async {
    final font = await PdfGoogleFonts.robotoRegular();
    final boldFont = await PdfGoogleFonts.robotoBold();

    final pdf = pw.Document(
      theme: pw.ThemeData.withFont(
        base: font,
        bold: boldFont,
      ),
    );
    
    final dateFormat = DateFormat('$dateFormatString HH:mm');
    final String currentDateTime = dateFormat.format(DateTime.now());

    // Carica il logo
    pw.ImageProvider? logoImage;
    try {
      final ByteData imageData = await rootBundle.load('assets/logo.jpg');
      final Uint8List imageBytes = imageData.buffer.asUint8List();
      logoImage = pw.MemoryImage(imageBytes);
    } catch (e) {
      // Ignora se il logo non è disponibile
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: landscape ? PdfPageFormat.a4.landscape : PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            pw.Header(
              level: 0,
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('Report: $title', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
                        pw.SizedBox(height: 4),
                        if (dateRangeText != null && dateRangeText.isNotEmpty)
                          pw.Text('Periodo: $dateRangeText', style: const pw.TextStyle(fontSize: 14)),
                        pw.SizedBox(height: 2),
                        pw.Text('Generato il $currentDateTime', style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700)),
                      ]
                    )
                  ),
                  if (logoImage != null)
                    pw.Container(
                      width: 80,
                      height: 80,
                      alignment: pw.Alignment.topRight,
                      child: pw.Image(logoImage, fit: pw.BoxFit.contain),
                    ),
                ]
              )
            ),
            pw.SizedBox(height: 20),
            pw.TableHelper.fromTextArray(
              headers: headers,
              data: data,
              columnWidths: columnWidths,
              border: pw.TableBorder.all(color: PdfColors.grey300),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.blue800),
              rowDecoration: const pw.BoxDecoration(
                border: pw.Border(
                  bottom: pw.BorderSide(color: PdfColors.grey200, width: .5),
                ),
              ),
              cellAlignment: pw.Alignment.centerLeft,
              cellPadding: const pw.EdgeInsets.all(6),
              cellStyle: const pw.TextStyle(fontSize: 10),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 10),
            ),
            if (legend != null && legend.isNotEmpty) ...[
              pw.SizedBox(height: 30),
              pw.Text('Legenda Acronimi/Abbreviazioni:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
              pw.SizedBox(height: 8),
              pw.Wrap(
                spacing: 16,
                runSpacing: 8,
                children: legend.entries.map((e) => pw.Text('${e.key} = ${e.value}', style: const pw.TextStyle(fontSize: 10))).toList(),
              )
            ]
          ];
        },
      ),
    );

    final String safeTitle = title.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
    final String filename = 'Report_$safeTitle.pdf';

    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename: filename,
    );
  }
}
