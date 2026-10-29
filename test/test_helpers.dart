import 'dart:convert';
import 'dart:io';

import 'package:anilarin/models/catalog.dart';
import 'package:anilarin/models/photo_book.dart';

Catalog loadTestCatalog() => Catalog.fromJson(
      jsonDecode(File('assets/catalog/catalog.json').readAsStringSync()),
      jsonDecode(File('assets/catalog/templates.json').readAsStringSync()),
    );

/// Sırayla tarihli, dönüşümlü yatay/dikey test fotoğrafları.
List<BookPhoto> testPhotos(int n, {bool undatedFirst = false}) => List.generate(
      n,
      (i) => BookPhoto(
        id: 'p$i',
        width: i.isEven ? 4000 : 3000,
        height: i.isEven ? 3000 : 4000,
        takenAtMs: undatedFirst && i == n - 1 ? null : DateTime(2025, 6, 1).add(Duration(hours: i)).millisecondsSinceEpoch,
      ),
    );
