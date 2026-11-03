import 'dart:io';

import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/catalog.dart';
import '../models/print_set.dart';
import 'matbaa_service.dart';

/// Pakete eklenen tek sayfalık iş emri: sipariş, müşteri, adres ve ürünler.
class WorkOrder {
  /// Ürün satırı: ad, tür, ölçü, sayfa/baskı sayısı, adet.
  static List<String> row(Map<String, dynamic> p, Catalog catalog) {
    final code = '${p['urunKodu']}';
    final count = p['sayfa'] ?? '';
    if (PrintCatalog.isPrintCode(code)) {
      final pr = PrintCatalog.byCode(code);
      return ['${p['ad']}', 'Baskı', '${_cm(pr.widthCm)} × ${_cm(pr.heightCm)} cm', '$count baskı', '${p['adet']}'];
    }
    final size = catalog.products.where((x) => x.code == code).firstOrNull?.dimensionsCm ?? code;
    return ['${p['ad']}', 'Fotokitap', '$size cm', '$count sayfa', '${p['adet']}'];
  }

  static Future<File> write(ShopOrder o, Catalog catalog, File file) async {
    final regular = pw.Font.ttf(await rootBundle.load('assets/fonts/DMSans-Regular.ttf'));
    final bold = pw.Font.ttf(await rootBundle.load('assets/fonts/DMSans-Bold.ttf'));
    final c = o.customer;
    final doc = pw.Document(
      title: 'İş emri ${o.ref}',
      theme: pw.ThemeData.withFont(base: regular, bold: bold),
    );
    pw.Widget label(String s) => pw.Padding(
      padding: const pw.EdgeInsets.only(top: 14, bottom: 4),
      child: pw.Text(
        s,
        style: pw.TextStyle(font: bold, fontSize: 11, color: PdfColors.grey700),
      ),
    );
    pw.Widget box(String s) => pw.Expanded(
      child: pw.Container(
        height: 60,
        margin: const pw.EdgeInsets.symmetric(horizontal: 4),
        padding: const pw.EdgeInsets.all(6),
        decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey600, width: 0.6)),
        child: pw.Text(s, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
      ),
    );
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        build: (_) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Expanded(
                  child: pw.Text('İŞ EMRİ', style: pw.TextStyle(font: bold, fontSize: 22)),
                ),
                pw.Text(o.ref, style: pw.TextStyle(font: bold, fontSize: 18)),
              ],
            ),
            pw.Text(DateFormat('d MMMM y, HH:mm', 'tr').format(o.createdAt)),
            pw.Divider(),
            label('Müşteri'),
            pw.Text(o.customerName, style: pw.TextStyle(font: bold, fontSize: 13)),
            pw.Text([c['email'], c['phone']].where((s) => s != null && '$s'.isNotEmpty).join(' · ')),
            label('Teslimat'),
            for (final l in o.addressLines) pw.Text(l),
            label('Ürünler'),
            pw.TableHelper.fromTextArray(
              headers: ['Ürün', 'Tür', 'Ölçü', 'İçerik', 'Adet'],
              data: [for (final p in o.products) row(p, catalog)],
              headerStyle: pw.TextStyle(font: bold, fontSize: 10),
              cellStyle: const pw.TextStyle(fontSize: 10),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
              cellAlignments: {4: pw.Alignment.centerRight},
              border: pw.TableBorder.all(color: PdfColors.grey500, width: 0.5),
            ),
            pw.Spacer(),
            pw.Row(children: [box('Baskı'), box('Kesim / Cilt'), box('Kontrol'), box('Paketleme')]),
          ],
        ),
      ),
    );
    await file.parent.create(recursive: true);
    return file.writeAsBytes(await doc.save());
  }

  static String _cm(double v) => v == v.roundToDouble() ? v.toInt().toString() : '$v';
}
