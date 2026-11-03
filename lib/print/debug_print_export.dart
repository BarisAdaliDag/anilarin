import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../constants/strings_tr.dart';
import '../models/photo_book.dart';
import '../services/firebase_order_backend.dart';
import '../view_model/app_view_model.dart';
import 'print_renderer.dart';

/// Geliştirme: sepetteki tasarımların baskı PDF'lerini telefonda üretir ve paylaşım menüsünü açar.
/// Firebase'e hiçbir şey göndermez.
Future<void> exportBasketPdfs(BuildContext context) async {
  final app = context.read<AppViewModel>();
  final progress = ValueNotifier<String>(S.pdfPreparing);
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => AlertDialog(
      content: Row(
        children: [
          const CircularProgressIndicator(),
          const SizedBox(width: 20),
          Expanded(
            child: ValueListenableBuilder(valueListenable: progress, builder: (_, v, _) => Text(v)),
          ),
        ],
      ),
    ),
  );
  final nav = Navigator.of(context, rootNavigator: true);
  final messenger = ScaffoldMessenger.of(context);
  final renderer = PrintRenderer(context: context, catalog: app.catalog!, loadPhoto: _galleryPhoto);
  try {
    final stamp = DateTime.now().toIso8601String().substring(0, 19).replaceAll(':', '-');
    final root = Directory('${(await getApplicationDocumentsDirectory()).path}/baski/$stamp');
    final files = <File>[];
    for (final item in app.basket) {
      final out = Directory('${root.path}/${_safe(item.title)}');
      void onPage(int d, int t) => progress.value = '${item.title}: $d / $t';
      if (item.isPrints) {
        final set = app.printSets.where((s) => s.id == item.bookId).firstOrNull;
        if (set != null) files.addAll(await renderer.renderPrintSet(set, out, copies: item.quantity, onPage: onPage));
      } else {
        final book = app.books.where((b) => b.id == item.bookId).firstOrNull;
        if (book != null) files.addAll(await renderer.renderBook(book, out, onPage: onPage));
      }
    }
    nav.pop();
    await SharePlus.instance.share(ShareParams(files: [for (final f in files) XFile(f.path)], subject: S.pdfReady));
  } catch (e) {
    nav.pop();
    messenger.showSnackBar(SnackBar(content: Text('${S.pdfFailed}: $e')));
  } finally {
    progress.dispose();
  }
}

Future<ui.Image> _galleryPhoto(BookPhoto photo, int maxPx) async {
  final long = math.max(photo.width, photo.height);
  final k = long > maxPx ? maxPx / long : 1.0;
  final bytes = await encodeGalleryPhoto(photo, (photo.width * k).round(), (photo.height * k).round());
  return decodePhoto(bytes, maxPx);
}

String _safe(String s) => s.replaceAll(RegExp(r'[^\wçğıöşüÇĞİÖŞÜ -]'), '_').trim();
