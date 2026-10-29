import 'package:flutter/foundation.dart';
import 'package:photo_manager/photo_manager.dart';

import '../constants/strings_tr.dart';
import '../models/catalog.dart';
import '../models/photo_book.dart';
import '../repositories/photo_repository.dart';
import '../services/smart_album_service.dart';

enum PickerPermission { unknown, granted, denied }

/// Fotoğraf seçimi: albümler, sayfalı galeri ve min/maks sayaç (Popsa PhotoPickerActivity).
class PhotoPickerViewModel extends ChangeNotifier {
  PhotoPickerViewModel({
    required this.minPhotos,
    required int maxPhotos,
    required this.recommended,
    this.product,
    PhotoRepository? repository,
  }) : _baseMax = maxPhotos,
       _repo = repository ?? PhotoRepository();

  /// Yeni kitap: başlangıç sınırı varsayılan sayfa sayısına göre; "Sayfa ekle" ile artar.
  factory PhotoPickerViewModel.forProduct(Product p) =>
      PhotoPickerViewModel(minPhotos: p.photoMin, maxPhotos: p.photoMaxBase, recommended: p.photoRecommend, product: p);

  /// Editörden "Fotoğraf ekle" / "Değiştir" için: alt sınır yok.
  factory PhotoPickerViewModel.addMore({required int max}) =>
      PhotoPickerViewModel(minPhotos: 1, maxPhotos: max, recommended: 1);

  final PhotoRepository _repo;
  final Product? product;
  final int minPhotos;
  final int recommended;
  final int _baseMax;
  int extraPages = 0;
  static const pageSize = 120;
  static const lowResolutionPixels = 1200 * 900;

  PickerPermission permission = PickerPermission.unknown;
  List<AssetPathEntity> albums = [];
  final Map<String, int> albumCounts = {};
  final Map<String, AssetEntity> albumCovers = {};
  AssetPathEntity? album;
  SmartAlbum? smart;
  List<SmartAlbum> smartAlbums = [];
  final Map<String, AssetEntity> _recent = {};
  static const smartScanLimit = 3000;
  final List<AssetEntity> assets = [];
  final List<AssetEntity> selected = [];
  bool loading = false;
  bool maxReached = false;
  bool _hasMore = true;
  int _page = 0;
  String? message;

  int get maxPhotos {
    final p = product;
    if (p == null) return _baseMax;
    return (_baseMax + extraPages * p.photosPerExtraPage).clamp(0, p.photoMax);
  }

  int get pageCount => (product?.pagesDefault ?? 0) + extraPages;

  bool get canAddPages => product != null && pageCount < product!.pagesMax;

  Future<void> init() async {
    final ok = await _repo.requestAccess();
    permission = ok ? PickerPermission.granted : PickerPermission.denied;
    notifyListeners();
    if (!ok) return;
    albums = await _repo.albums();
    for (final a in albums) {
      albumCounts[a.id] = await a.assetCountAsync;
      final first = await a.getAssetListRange(start: 0, end: 1);
      if (first.isNotEmpty) albumCovers[a.id] = first.first;
      notifyListeners();
    }
    await _buildSmartAlbums();
  }

  /// Son fotoğrafları aylara göre gruplayıp akıllı albüm önerileri üretir.
  Future<void> _buildSmartAlbums() async {
    if (albums.isEmpty) return;
    final all = albums.firstWhere((a) => a.isAll, orElse: () => albums.first);
    final recent = await all.getAssetListRange(start: 0, end: smartScanLimit);
    for (final a in recent) {
      _recent[a.id] = a;
    }
    smartAlbums = SmartAlbumService.build([
      for (final a in recent)
        SmartPhoto(
          id: a.id,
          takenAt: a.createDateTime,
          screenshot: SmartAlbumService.isScreenshotPath(a.relativePath),
          camera: SmartAlbumService.isCameraPath(a.relativePath),
        ),
    ]);
    notifyListeners();
  }

  AssetEntity? smartCover(SmartAlbum s) => _recent[s.coverId];

  void openSmart(SmartAlbum s) {
    smart = s;
    album = null;
    assets
      ..clear()
      ..addAll(s.photoIds.map((id) => _recent[id]).whereType<AssetEntity>());
    _hasMore = false;
    notifyListeners();
  }

  bool get inGrid => album != null || smart != null;

  Future<void> openSettings() => _repo.openSettings();

  Future<void> selectAlbum(AssetPathEntity a) async {
    album = a;
    smart = null;
    assets.clear();
    _page = 0;
    _hasMore = true;
    notifyListeners();
    await loadMore();
  }

  void closeAlbum() {
    album = null;
    smart = null;
    notifyListeners();
  }

  Future<void> loadMore() async {
    final a = album;
    if (a == null || loading || !_hasMore) return;
    loading = true;
    notifyListeners();
    final list = await _repo.page(a, _page, size: pageSize);
    _page++;
    _hasMore = list.length == pageSize;
    assets.addAll(list);
    loading = false;
    notifyListeners();
  }

  int indexOf(AssetEntity a) => selected.indexWhere((s) => s.id == a.id);

  bool isSelected(AssetEntity a) => indexOf(a) >= 0;

  static bool isLowResolution(AssetEntity a) => a.width * a.height < lowResolutionPixels;

  void toggle(AssetEntity a) {
    final i = indexOf(a);
    if (i >= 0) {
      selected.removeAt(i);
    } else if (selected.length >= maxPhotos) {
      if (product != null) {
        maxReached = true;
      } else {
        message = S.selectUpTo(maxPhotos);
      }
    } else {
      selected.add(a);
    }
    notifyListeners();
  }

  void addPages(int n) {
    final p = product;
    if (p == null) return;
    extraPages = (extraPages + n).clamp(0, p.pagesMax - p.pagesDefault);
    notifyListeners();
  }

  bool takeMaxReached() {
    final v = maxReached;
    maxReached = false;
    return v;
  }

  void selectAllVisible() {
    for (final a in assets) {
      if (selected.length >= maxPhotos) break;
      if (!isSelected(a)) selected.add(a);
    }
    notifyListeners();
  }

  bool get canContinue => selected.length >= minPhotos;

  double get progress => (selected.length / recommended).clamp(0, 1).toDouble();

  String get meterText {
    final n = selected.length;
    if (n < minPhotos) return S.minimumRequired(minPhotos);
    if (n < recommended) return S.selectMoreForBest;
    return S.selectUpTo(maxPhotos);
  }

  List<BookPhoto> get bookPhotos => selected.map(PhotoRepository.toBookPhoto).toList();

  String? takeMessage() {
    final m = message;
    message = null;
    return m;
  }
}
