import 'dart:io';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';

void main() async {
  final pdf = pw.Document();

  pdf.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      build: (pw.Context context) {
        return pw.Center(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Text('Diagramma di Calcolo del Patrimonio Netto', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 20),
              pw.Container(
                padding: const pw.EdgeInsets.all(20),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.black),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)),
                ),
                child: pw.Column(
                  children: [
                    pw.Text('ENTRATE (I) = FATTURE IN + INCASSI'),
                    pw.SizedBox(height: 10),
                    pw.Text('USCITE (O) = FATTURE OUT + SPESE'),
                    pw.SizedBox(height: 10),
                    pw.Text('SCADENZE (SP) = SCADENZE PAGATE (OUT/IN)'),
                  ]
                )
              ),
              pw.SizedBox(height: 20),
              pw.Text('=> PATRIMONIO NETTO = (I) - (O) - (SP)', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 20),
              pw.Text('Nota: I Preventivi sono ignorati in quanto non fiscalmente esigibili finche non fatturati.', style: pw.TextStyle(fontStyle: pw.FontStyle.italic, fontSize: 10))
            ],
          ),
        );
      }));

  final file = File('grafico_patrimonio.pdf');
  await file.writeAsBytes(await pdf.save());
  print('PDF creato con successo: grafico_patrimonio.pdf');
}
