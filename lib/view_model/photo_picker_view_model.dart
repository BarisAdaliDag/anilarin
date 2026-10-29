import 'package:flutter/foundation.dart';
import 'package:photo_manager/photo_manager.dart';

import '../constants/strings_tr.dart';
import '../models/catalog.dart';
import '../models/photo_book.dart';
import '../repositories/photo_repository.dart';

enum PickerPermission { unknown, granted, denied }

/// Fotoğraf seçimi: albümler, sayfalı galeri ve min/maks sayaç (Popsa PhotoPickerActivity).
class PhotoPickerViewModel extends ChangeNotifier {
  PhotoPickerViewModel({required this.minPhotos, required this.maxPhotos, required this.recommended, PhotoRepository? repository})
      : _repo = repository ?? PhotoRepository();

  factory PhotoPickerViewModel.forProduct(Product p) =>
      PhotoPickerViewModel(minPhotos: p.photoMin, maxPhotos: p.photoMax, recommended: p.photoRecommend);

  /// Editörden "Fotoğraf ekle" için: alt sınır yok.
  factory PhotoPickerViewModel.addMore({required int max}) =>
      PhotoPickerViewModel(minPhotos: 1, maxPhotos: max, recommended: 1);

  final PhotoRepository _repo;
  final int minPhotos;
  final int maxPhotos;
  final int recommended;
  static const pageSize = 120;
  static const lowResolutionPixels = 1200 * 900;

  PickerPermission permission = PickerPermission.unknown;
  List<AssetPathEntity> albums = [];
  final Map<String, int> albumCounts = {};
  AssetPathEntity? album;
  final List<AssetEntity> assets = [];
  final List<AssetEntity> selected = [];
  bool loading = false;
  bool _hasMore = true;
  int _page = 0;
  String? message;

  Future<void> init() async {
    final ok = await _repo.requestAccess();
    permission = ok ? PickerPermission.granted : PickerPermission.denied;
    notifyListeners();
    if (!ok) return;
    albums = await _repo.albums();
    for (final a in albums) {
      albumCounts[a.id] = await a.assetCountAsync;
    }
    if (albums.isNotEmpty) await selectAlbum(albums.first);
  }

  Future<void> openSettings() => _repo.openSettings();

  Future<void> selectAlbum(AssetPathEntity a) async {
    album = a;
    assets.clear();
    _page = 0;
    _hasMore = true;
    notifyListeners();
    await loadMore();
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
      message = S.selectUpTo(maxPhotos);
    } else {
      selected.add(a);
    }
    notifyListeners();
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
