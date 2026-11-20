import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

Future<void> shareGivingReceipt(Map<String, dynamic> transaction) async {
  final category = transaction['category'] as Map<String, dynamic>? ?? {};
  final receipt =
      '${transaction['receiptNumber'] ?? transaction['paymentReference'] ?? 'giving'}';
  final document = pw.Document();
  document.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      build: (_) => pw.Padding(
        padding: const pw.EdgeInsets.all(40),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'MYGROWTH MINISTRY',
              style: pw.TextStyle(fontSize: 12, color: PdfColors.grey700),
            ),
            pw.SizedBox(height: 10),
            pw.Text(
              'Giving Receipt',
              style: pw.TextStyle(fontSize: 28, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 30),
            _line('Receipt number', receipt),
            _line('Donor', '${transaction['donorName'] ?? 'Member'}'),
            _line('Giving category', '${category['name'] ?? 'Giving'}'),
            _line(
              'Amount',
              '${transaction['currency'] ?? 'NGN'} ${transaction['amount'] ?? ''}',
            ),
            _line('Payment status', '${transaction['status'] ?? 'PAID'}'),
            _line('Payment date', '${transaction['paidAt'] ?? ''}'),
            pw.SizedBox(height: 40),
            pw.Text(
              'Thank you for supporting the ministry.',
              style: const pw.TextStyle(fontSize: 14),
            ),
          ],
        ),
      ),
    ),
  );
  await Printing.sharePdf(
    bytes: await document.save(),
    filename: 'mygrowth-receipt-$receipt.pdf',
    subject: 'MyGrowth Ministry giving receipt',
  );
}

Future<void> shareGivingReport(Map<String, dynamic> report) async {
  final document = pw.Document();
  final categories = report['categories'] as List<dynamic>? ?? [];
  final transactions = report['transactions'] as List<dynamic>? ?? [];
  document.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      build: (_) => [
        pw.Text(
          'MYGROWTH MINISTRY',
          style: pw.TextStyle(fontSize: 12, color: PdfColors.grey700),
        ),
        pw.SizedBox(height: 8),
        pw.Text(
          'Giving Report · ${report['period']} · ${report['date']}',
          style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
        ),
        pw.Text('Timezone: ${report['timezone']}'),
        pw.SizedBox(height: 18),
        pw.Text(
          'Total received: NGN ${report['totalAmount'] ?? 0} · ${report['count'] ?? 0} gifts',
        ),
        pw.SizedBox(height: 18),
        pw.Text(
          'By category',
          style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
        ),
        pw.TableHelper.fromTextArray(
          headers: const ['Category', 'Gifts', 'Amount (NGN)'],
          data: categories.map((item) {
            final row = item as Map<String, dynamic>;
            return ['${row['name']}', '${row['count']}', '${row['amount']}'];
          }).toList(),
        ),
        pw.SizedBox(height: 18),
        pw.Text(
          'Transactions',
          style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
        ),
        pw.TableHelper.fromTextArray(
          headers: const ['Date', 'Receipt', 'Category', 'Donor', 'Amount'],
          data: transactions.map((item) {
            final row = item as Map<String, dynamic>;
            return [
              '${row['paidAt'] ?? ''}',
              '${row['receiptNumber'] ?? ''}',
              '${row['category'] ?? ''}',
              '${row['donorName'] ?? ''}',
              '${row['currency'] ?? 'NGN'} ${row['amount'] ?? ''}',
            ];
          }).toList(),
        ),
      ],
    ),
  );
  final date = '${report['date'] ?? 'report'}';
  await Printing.sharePdf(
    bytes: await document.save(),
    filename: 'mygrowth-giving-$date.pdf',
    subject: 'MyGrowth Ministry giving report',
  );
}

/// Save the period's confirmed gifts as an Excel-compatible UTF-8 CSV.
Future<bool> saveGivingReportCsv(Map<String, dynamic> report) async {
  final transactions = report['transactions'] as List<dynamic>? ?? [];
  final rows = <List<Object?>>[
    <Object?>['Report period', report['period'], 'Report date', report['date']],
    <Object?>[
      'Paid At',
      'Receipt Number',
      'Payment Reference',
      'Category',
      'Donor Name',
      'Donor Email',
      'Currency',
      'Amount',
    ],
    ...transactions.map((item) {
      final row = item as Map<String, dynamic>;
      return <Object?>[
        row['paidAt'],
        row['receiptNumber'],
        row['paymentReference'],
        row['category'],
        row['donorName'],
        row['donorEmail'],
        row['currency'] ?? 'NGN',
        row['amount'],
      ];
    }),
  ];
  String csvCell(Object? value) {
    var text = value == null ? '' : '$value';
    if (value is String && RegExp(r'^\s*[=+@-]').hasMatch(text)) {
      text = "'$text";
    }
    return '"${text.replaceAll('"', '""')}"';
  }

  final csv = rows.map((row) => row.map(csvCell).join(',')).join('\r\n');
  final bytes = Uint8List.fromList([0xEF, 0xBB, 0xBF, ...utf8.encode(csv)]);
  final date = '${report['date'] ?? 'report'}';
  final saved = await FilePicker.saveFile(
    fileName: 'mygrowth-giving-$date.csv',
    bytes: bytes,
    mimeType: 'text/csv',
    dialogTitle: 'Save giving report',
    allowedExtensions: const ['csv'],
  );
  return saved != null;
}

pw.Widget _line(String label, String value) => pw.Padding(
  padding: const pw.EdgeInsets.only(bottom: 12),
  child: pw.Row(
    children: [
      pw.SizedBox(
        width: 140,
        child: pw.Text(label, style: pw.TextStyle(color: PdfColors.grey700)),
      ),
      pw.Expanded(child: pw.Text(value)),
    ],
  ),
);
