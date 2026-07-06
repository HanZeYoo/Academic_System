import 'dart:io';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';

class ReportService {
  /// Generate and preview a PDF report
  static Future<void> generatePDFReport({
    required String title,
    required String subtitle,
    required List<String> headers,
    required List<List<dynamic>> data,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (pw.Context context) {
          return [
            pw.Header(
              level: 0,
              decoration: const pw.BoxDecoration(
                border: pw.Border(bottom: pw.BorderSide(color: PdfColors.blue900, width: 2)),
              ),
              padding: const pw.EdgeInsets.only(bottom: 10),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('ACADEMIC SYSTEM', style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                      pw.SizedBox(height: 4),
                      pw.Text('Official Generated Report', style: pw.TextStyle(fontSize: 12, color: PdfColors.grey700)),
                    ]
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(title, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(height: 4),
                      pw.Text(subtitle, style: const pw.TextStyle(fontSize: 12)),
                    ]
                  )
                ]
              )
            ),
            pw.SizedBox(height: 20),
            pw.TableHelper.fromTextArray(
              headers: headers,
              data: data,
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 11),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.blue800),
              cellStyle: const pw.TextStyle(fontSize: 10),
              cellPadding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 10),
              cellAlignments: {
                for (var i = 0; i < headers.length; i++) i: pw.Alignment.centerLeft,
              },
            ),
            pw.SizedBox(height: 30),
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Text('Generated on: ${DateTime.now().toString().split('.')[0]}', style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600, fontStyle: pw.FontStyle.italic)),
            ),
          ];
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: '${title.replaceAll(' ', '_')}.pdf',
    );
  }

  /// Generate and save a CSV report (returns file path, or null if failed)
  static Future<String?> generateCSVReport({
    required String title,
    required String subtitle,
    required List<String> headers,
    required List<List<dynamic>> data,
  }) async {
    try {
      List<List<dynamic>> csvData = [
        ['ACADEMIC SYSTEM - OFFICIAL REPORT'],
        ['Report:', title],
        ['Details:', subtitle],
        ['Generated on:', DateTime.now().toString().split('.')[0]],
        [], // Empty row for spacing
        headers,
        ...data,
      ];

      String escapeCsv(dynamic item) {
        String text = item.toString();
        if (text.contains(',') || text.contains('"') || text.contains('\n')) {
          return '"${text.replaceAll('"', '""')}"';
        }
        return text;
      }
      String csvString = csvData.map((row) => row.map(escapeCsv).join(',')).join('\n');
      
      final directory = await getApplicationDocumentsDirectory();
      final path = '${directory.path}/${title.replaceAll(' ', '_')}_${DateTime.now().millisecondsSinceEpoch}.csv';
      final file = File(path);
      await file.writeAsString(csvString);
      return path;
    } catch (e) {
      print('Error generating CSV: $e');
      return null;
    }
  }
}
