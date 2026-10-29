import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/catalog.dart';

class CatalogRepository {
  Catalog? _cache;

  Future<Catalog> load() async {
    if (_cache != null) return _cache!;
    final catalog = await rootBundle.loadString('assets/catalog/catalog.json');
    final templates = await rootBundle.loadString('assets/catalog/templates.json');
    return _cache = Catalog.fromJson(jsonDecode(catalog), jsonDecode(templates));
  }
}
