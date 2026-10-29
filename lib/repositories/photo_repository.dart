import 'package:photo_manager/photo_manager.dart';

import '../models/photo_book.dart';

/// Cihaz galerisine erişim (photo_manager).
class PhotoRepository {
  static final Map<String, AssetEntity> _cache = {};

  Future<bool> requestAccess() async {
    final state = await PhotoManager.requestPermissionExtend();
    return state.hasAccess;
  }

  Future<void> openSettings() => PhotoManager.openSetting();

  /// İlk eleman "Tüm Fotoğraflar"dır.
  Future<List<AssetPathEntity>> albums() => PhotoManager.getAssetPathList(
    type: RequestType.image,
    filterOption: FilterOptionGroup(orders: [const OrderOption(type: OrderOptionType.createDate, asc: false)]),
  );

  Future<List<AssetEntity>> page(AssetPathEntity album, int page, {int size = 120}) async {
    final list = await album.getAssetListPaged(page: page, size: size);
    for (final a in list) {
      _cache[a.id] = a;
    }
    return list;
  }

  static AssetEntity? cached(String id) => _cache[id];

  static Future<AssetEntity?> entity(String id) async {
    final hit = _cache[id];
    if (hit != null) return hit;
    final e = await AssetEntity.fromId(id);
    if (e != null) _cache[id] = e;
    return e;
  }

  static BookPhoto toBookPhoto(AssetEntity a) => BookPhoto(
    id: a.id,
    width: a.orientatedWidth,
    height: a.orientatedHeight,
    takenAtMs: a.createDateTime.millisecondsSinceEpoch <= 0 ? null : a.createDateTime.millisecondsSinceEpoch,
  );
}
