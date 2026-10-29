import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';
import 'package:provider/provider.dart';

import '../../config/theme.dart';
import '../../constants/strings_tr.dart';
import '../../models/catalog.dart';
import '../../models/photo_book.dart';
import '../../services/smart_album_service.dart';
import '../../view_model/photo_picker_view_model.dart';
import '../title/title_screen.dart';

/// Fotoğraf seçici. [product] verilirse yeni kitap akışıdır (ardından başlık ekranı);
/// verilmezse seçilen fotoğraflar `Navigator.pop` ile döner (editörden fotoğraf ekleme / değiştirme).
class PhotoPickerScreen extends StatelessWidget {
  const PhotoPickerScreen({super.key, this.product, this.options, this.maxPhotos = 200, this.single = false});

  final Product? product;
  final ProductOptions? options;
  final int maxPhotos;
  final bool single;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) =>
          (product != null
                ? PhotoPickerViewModel.forProduct(product!)
                : PhotoPickerViewModel.addMore(max: single ? 1 : maxPhotos))
            ..init(),
      child: _PickerBody(product: product, options: options, single: single),
    );
  }
}

class _PickerBody extends StatefulWidget {
  const _PickerBody({required this.product, required this.options, required this.single});

  final Product? product;
  final ProductOptions? options;
  final bool single;

  @override
  State<_PickerBody> createState() => _PickerBodyState();
}

class _PickerBodyState extends State<_PickerBody> {
  bool _returned = false;

  void _next(PhotoPickerViewModel vm) {
    final photos = vm.bookPhotos;
    if (widget.product == null) {
      if (_returned) return;
      _returned = true;
      Navigator.of(context).pop<List<BookPhoto>>(photos);
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TitleScreen(product: widget.product!, options: widget.options!, photos: photos),
      ),
    );
  }

  Future<void> _maxDialog(PhotoPickerViewModel vm) async {
    final add = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('En fazlaya ulaşıldı', textAlign: TextAlign.center),
        content: Text(S.maxReached(vm.pageCount), textAlign: TextAlign.center),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          if (vm.canAddPages) FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text(S.addMorePages)),
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text(S.cancel)),
        ],
      ),
    );
    if (add == true && mounted) await _addPagesDialog(vm);
  }

  Future<void> _addPagesDialog(PhotoPickerViewModel vm) async {
    final p = widget.product!;
    final n = await showAddPagesDialog(
      context,
      increment: p.incrementPriceCents,
      photosPerPage: p.photosPerExtraPage,
      max: p.pagesMax - vm.pageCount,
    );
    if (n != null && n > 0) vm.addPages(n);
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<PhotoPickerViewModel>();
    final msg = vm.takeMessage();
    if (msg != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(msg)));
      });
    }
    if (vm.takeMaxReached()) WidgetsBinding.instance.addPostFrameCallback((_) => _maxDialog(vm));
    if (widget.single && vm.selected.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _next(vm);
      });
    }
    final inAlbum = vm.inGrid;
    return PopScope(
      canPop: !inAlbum,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && inAlbum) vm.closeAlbum();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => inAlbum ? vm.closeAlbum() : Navigator.pop(context),
          ),
          // Popsa gibi: albüm içindeyken başlık yok, yalnız geri oku.
          title: inAlbum ? null : Text(widget.single ? S.replacePhoto : S.selectPhotos),
        ),
        body: switch (vm.permission) {
          PickerPermission.unknown => const Center(child: CircularProgressIndicator()),
          PickerPermission.denied => _PermissionView(vm: vm),
          PickerPermission.granted => inAlbum ? _Grid(vm: vm) : _Albums(vm: vm),
        },
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
        floatingActionButton: vm.permission != PickerPermission.granted || widget.single
            ? null
            : vm.selected.isNotEmpty
            ? _SelectionBar(vm: vm, onNext: vm.canContinue ? () => _next(vm) : null)
            : widget.product != null
            ? _StartHint(product: widget.product!)
            : null,
      ),
    );
  }
}

String _albumName(PhotoPickerViewModel vm, AssetPathEntity a) => a.isAll ? S.allPhotos : a.name;

/// Albüm thumbnail'ı.
Widget _thumb(AssetEntity a, int size) => Image(
  image: AssetEntityImageProvider(a, isOriginal: false, thumbnailSize: ThumbnailSize.square(size)),
  fit: BoxFit.cover,
  gaplessPlayback: true,
);

class _PermissionView extends StatelessWidget {
  const _PermissionView({required this.vm});

  final PhotoPickerViewModel vm;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.photo_library_outlined, size: 64, color: AppColors.accent),
          const SizedBox(height: 16),
          const Text(S.permissionTitle, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text(
            S.permissionBody,
            textAlign: TextAlign.center,
            style: TextStyle(color: context.mutedText),
          ),
          const SizedBox(height: 24),
          FilledButton(onPressed: vm.init, child: const Text(S.allowAccess)),
          TextButton(onPressed: vm.openSettings, child: const Text(S.openSettings)),
        ],
      ),
    );
  }
}

class _Albums extends StatelessWidget {
  const _Albums({required this.vm});

  final PhotoPickerViewModel vm;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.only(bottom: 8, left: 6, right: 6),
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: context.strongText, width: 2.5)),
                  ),
                  child: const Icon(Icons.stay_current_portrait, size: 26, color: Color(0xFFE5537B)),
                ),
                const SizedBox(width: 22),
                for (final (icon, color, name) in const [
                  (Icons.camera, Color(0xFFFBBC05), 'Google Fotoğraflar'),
                  (Icons.inventory_2, Color(0xFF0061FF), 'Dropbox'),
                  (Icons.facebook, Color(0xFF1877F2), 'Facebook'),
                ])
                  Padding(
                    padding: const EdgeInsets.only(right: 26, bottom: 8),
                    child: Tooltip(
                      message: '$name yakında',
                      triggerMode: TooltipTriggerMode.tap,
                      child: Icon(icon, size: 26, color: color),
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (vm.smartAlbums.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 2),
              child: Text(S.suggestedForYou, style: TextStyle(fontSize: 13, color: context.mutedText)),
            ),
          ),
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Text(S.smartAlbums, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w500)),
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 200,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: vm.smartAlbums.length,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (_, i) => _SmartAlbumCard(vm: vm, album: vm.smartAlbums[i]),
              ),
            ),
          ),
        ],
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(20, 24, 20, 12),
            child: Text(S.albums, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w500)),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
          sliver: SliverGrid.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 0.82,
            ),
            itemCount: vm.albums.length,
            itemBuilder: (_, i) {
              final a = vm.albums[i];
              final cover = vm.albumCovers[a.id];
              return GestureDetector(
                onTap: () => vm.selectAlbum(a),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: SizedBox.expand(
                          child: cover == null ? ColoredBox(color: context.cardColor) : _thumb(cover, 400),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _albumName(vm, a),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Text('${vm.albumCounts[a.id] ?? ''}', style: TextStyle(color: context.mutedText, fontSize: 13)),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _Grid extends StatelessWidget {
  const _Grid({required this.vm});

  final PhotoPickerViewModel vm;

  @override
  Widget build(BuildContext context) {
    if (vm.assets.isEmpty) {
      return Center(child: vm.loading ? const CircularProgressIndicator() : const Text(S.noPhotos));
    }
    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n.metrics.pixels > n.metrics.maxScrollExtent - 800) vm.loadMore();
        return false;
      },
      child: GridView.builder(
        padding: const EdgeInsets.only(bottom: 120),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 3,
          crossAxisSpacing: 3,
        ),
        itemCount: vm.assets.length,
        itemBuilder: (context, i) {
          final a = vm.assets[i];
          final selected = vm.isSelected(a);
          return GestureDetector(
            onTap: () => vm.toggle(a),
            onLongPress: () => Navigator.of(context).push(
              MaterialPageRoute(
                fullscreenDialog: true,
                builder: (_) => ChangeNotifierProvider.value(
                  value: vm,
                  child: _FullScreenPhotos(initial: i),
                ),
              ),
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                _thumb(a, 300),
                Positioned(
                  top: 6,
                  right: 6,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 120),
                    opacity: selected ? 1 : 0,
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.accent,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: const Icon(Icons.check, size: 17, color: Colors.white),
                    ),
                  ),
                ),
                if (PhotoPickerViewModel.isLowResolution(a))
                  const Positioned(
                    left: 5,
                    bottom: 5,
                    child: Icon(Icons.warning_amber_rounded, size: 18, color: AppColors.warning),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SmartAlbumCard extends StatelessWidget {
  const _SmartAlbumCard({required this.vm, required this.album});

  final PhotoPickerViewModel vm;
  final SmartAlbum album;

  @override
  Widget build(BuildContext context) {
    final cover = vm.smartCover(album);
    return GestureDetector(
      onTap: () => vm.openSmart(album),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: SizedBox(
          width: 250,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (cover != null) _thumb(cover, 500) else ColoredBox(color: context.cardColor),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x00000000), Color(0xAA000000)],
                    stops: [0.4, 1],
                  ),
                ),
              ),
              Positioned(
                left: 12,
                right: 12,
                bottom: 10,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      album.title,
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    Text(album.dateLabel, style: const TextStyle(color: Colors.white, fontSize: 13)),
                    Text('${album.count} fotoğraf', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Henüz seçim yokken Popsa'nın alttaki kartı: ürün adı ve en az kaç fotoğraf gerektiği.
class _StartHint extends StatelessWidget {
  const _StartHint({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 12),
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
      decoration: BoxDecoration(
        color: context.isDark ? const Color(0xFF2E2E2E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 16, offset: Offset(0, 4))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(product.title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
          const SizedBox(height: 2),
          Text(S.selectMinimumToContinue(product.photoMin), style: TextStyle(color: context.mutedText, fontSize: 13)),
        ],
      ),
    );
  }
}

/// Popsa'nın yüzen seçim kartı: küçük resim, sayı, ipucu, ilerleme ve İleri.
class _SelectionBar extends StatelessWidget {
  const _SelectionBar({required this.vm, required this.onNext});

  final PhotoPickerViewModel vm;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final enough = vm.canContinue;
    final last = vm.selected.last;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
      decoration: BoxDecoration(
        color: context.isDark ? const Color(0xFF2E2E2E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 16, offset: Offset(0, 4))],
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(width: 46, height: 46, child: _thumb(last, 150)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${vm.selected.length} fotoğraf seçildi',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                ),
                Text(
                  vm.meterText,
                  style: TextStyle(color: enough ? context.mutedText : AppColors.failure, fontSize: 12),
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: vm.progress,
                    minHeight: 4,
                    backgroundColor: context.pillColor,
                    color: enough ? AppColors.warning : AppColors.failure,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          FilledButton(
            style: FilledButton.styleFrom(
              minimumSize: const Size(72, 44),
              backgroundColor: context.pillColor,
              foregroundColor: context.strongText,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: onNext,
            child: const Text(S.next),
          ),
        ],
      ),
    );
  }
}

class _FullScreenPhotos extends StatefulWidget {
  const _FullScreenPhotos({required this.initial});

  final int initial;

  @override
  State<_FullScreenPhotos> createState() => _FullScreenPhotosState();
}

class _FullScreenPhotosState extends State<_FullScreenPhotos> {
  late final _controller = PageController(initialPage: widget.initial);
  late int _index = widget.initial;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<PhotoPickerViewModel>();
    final a = vm.assets[_index];
    final selected = vm.isSelected(a);
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(
              selected ? Icons.check_circle : Icons.radio_button_unchecked,
              color: selected ? AppColors.accent : Colors.white,
            ),
            onPressed: () => vm.toggle(a),
          ),
        ],
      ),
      body: Stack(
        children: [
          PageView.builder(
            controller: _controller,
            itemCount: vm.assets.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (_, i) => InteractiveViewer(
              child: Image(
                image: AssetEntityImageProvider(
                  vm.assets[i],
                  isOriginal: false,
                  thumbnailSize: const ThumbnailSize.square(1400),
                ),
                fit: BoxFit.contain,
              ),
            ),
          ),
          if (PhotoPickerViewModel.isLowResolution(a))
            Positioned(
              left: 16,
              right: 16,
              bottom: 24,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(10)),
                child: const Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: AppColors.warning),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${S.lowResolution}: bu fotoğrafın boyutu küçük, baskıda bulanık görünebilir.',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// "N sayfa eklensin mi?" penceresi (Popsa): adım düğmesi, ek fotoğraf alanı ve sayfa başı fiyat.
Future<int?> showAddPagesDialog(
  BuildContext context, {
  required int increment,
  required int photosPerPage,
  required int max,
  int initial = 1,
}) {
  var n = initial.clamp(1, max < 1 ? 1 : max);
  return showDialog<int>(
    context: context,
    builder: (c) => StatefulBuilder(
      builder: (c, setState) => AlertDialog(
        title: Text(n == 1 ? '1 sayfa daha eklensin mi?' : '$n sayfa daha eklensin mi?', textAlign: TextAlign.center),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${n * photosPerPage} ek fotoğraf için yer\nSayfa başı +${formatPrice(increment)}',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton.outlined(
                  onPressed: n > 1 ? () => setState(() => n--) : null,
                  icon: const Icon(Icons.remove),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: Text('$n', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600)),
                ),
                IconButton.outlined(onPressed: n < max ? () => setState(() => n++) : null, icon: const Icon(Icons.add)),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Bunu daha sonra Seçenekler menüsündeki "Sayfaları Kaldır" ile geri alabilirsin.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: c.mutedText),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text(S.cancel)),
          TextButton(onPressed: () => Navigator.pop(c, n), child: const Text(S.done)),
        ],
      ),
    ),
  );
}
