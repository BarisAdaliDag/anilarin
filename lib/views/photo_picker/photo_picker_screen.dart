import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';
import 'package:provider/provider.dart';

import '../../config/theme.dart';
import '../../constants/strings_tr.dart';
import '../../models/catalog.dart';
import '../../models/photo_book.dart';
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
      create: (_) => (product != null
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

class _PickerBodyState extends State<_PickerBody> with SingleTickerProviderStateMixin {
  late final _tabs = TabController(length: 2, vsync: this);

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  bool _returned = false;

  void _next(PhotoPickerViewModel vm) {
    final photos = vm.bookPhotos;
    if (widget.product == null) {
      if (_returned) return;
      _returned = true;
      Navigator.of(context).pop<List<BookPhoto>>(photos);
      return;
    }
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => TitleScreen(product: widget.product!, options: widget.options!, photos: photos),
    ));
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
    if (widget.single && vm.selected.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _next(vm);
      });
    }
    return Scaffold(
      appBar: AppBar(
        leadingWidth: 80,
        leading: TextButton(onPressed: () => Navigator.pop(context), child: const Text(S.cancel)),
        title: Text(widget.single ? S.replace : S.selectPhotos),
        actions: [
          if (!widget.single)
            TextButton(
              onPressed: vm.canContinue ? () => _next(vm) : null,
              child: Text(S.next, style: TextStyle(fontWeight: FontWeight.w700, color: vm.canContinue ? AppColors.accent : null)),
            ),
        ],
        bottom: vm.permission == PickerPermission.granted
            ? TabBar(
                controller: _tabs,
                labelColor: AppColors.textStrong,
                indicatorColor: AppColors.accent,
                tabs: const [Tab(text: S.allPhotos), Tab(text: S.albums)],
              )
            : null,
      ),
      body: switch (vm.permission) {
        PickerPermission.unknown => const Center(child: CircularProgressIndicator()),
        PickerPermission.denied => _PermissionView(vm: vm),
        PickerPermission.granted => TabBarView(
            controller: _tabs,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _Grid(vm: vm),
              _AlbumList(vm: vm, onPicked: () => _tabs.animateTo(0)),
            ],
          ),
      },
      bottomNavigationBar: vm.permission == PickerPermission.granted && !widget.single ? _SelectionBar(vm: vm) : null,
    );
  }
}

class _PermissionView extends StatelessWidget {
  const _PermissionView({required this.vm});

  final PhotoPickerViewModel vm;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.photo_library_outlined, size: 64, color: AppColors.accent),
        const SizedBox(height: 16),
        const Text(S.permissionTitle, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        const Text(S.permissionBody, textAlign: TextAlign.center, style: TextStyle(color: AppColors.text)),
        const SizedBox(height: 24),
        FilledButton(onPressed: vm.init, child: const Text(S.allowAccess)),
        TextButton(onPressed: vm.openSettings, child: const Text(S.openSettings)),
      ]),
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
        padding: const EdgeInsets.all(2),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          mainAxisSpacing: 2,
          crossAxisSpacing: 2,
        ),
        itemCount: vm.assets.length,
        itemBuilder: (context, i) {
          final a = vm.assets[i];
          final idx = vm.indexOf(a);
          return GestureDetector(
            onTap: () => vm.toggle(a),
            onLongPress: () => Navigator.of(context).push(MaterialPageRoute(
              fullscreenDialog: true,
              builder: (_) => ChangeNotifierProvider.value(
                value: vm,
                child: _FullScreenPhotos(initial: i),
              ),
            )),
            child: Stack(fit: StackFit.expand, children: [
              Image(
                image: AssetEntityImageProvider(a, isOriginal: false, thumbnailSize: const ThumbnailSize.square(250)),
                fit: BoxFit.cover,
                gaplessPlayback: true,
              ),
              if (idx >= 0) ColoredBox(color: Colors.white.withValues(alpha: 0.25)),
              Positioned(
                top: 6,
                right: 6,
                child: _SelectBadge(index: idx),
              ),
              if (PhotoPickerViewModel.isLowResolution(a))
                const Positioned(
                  left: 4,
                  bottom: 4,
                  child: Icon(Icons.warning_amber_rounded, size: 18, color: AppColors.warning),
                ),
            ]),
          );
        },
      ),
    );
  }
}

class _SelectBadge extends StatelessWidget {
  const _SelectBadge({required this.index});

  final int index;

  @override
  Widget build(BuildContext context) {
    final selected = index >= 0;
    return Container(
      width: 24,
      height: 24,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? AppColors.accent : Colors.black26,
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: selected
          ? Text('${index + 1}', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700))
          : null,
    );
  }
}

class _AlbumList extends StatelessWidget {
  const _AlbumList({required this.vm, required this.onPicked});

  final PhotoPickerViewModel vm;
  final VoidCallback onPicked;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: vm.albums.length,
      itemBuilder: (_, i) {
        final a = vm.albums[i];
        return ListTile(
          leading: const CircleAvatar(
            backgroundColor: AppColors.background,
            child: Icon(Icons.photo_album_outlined, color: AppColors.accent),
          ),
          title: Text(i == 0 ? S.allPhotos : a.name),
          subtitle: Text('${vm.albumCounts[a.id] ?? 0}'),
          trailing: vm.album?.id == a.id ? const Icon(Icons.check, color: AppColors.accent) : null,
          onTap: () {
            vm.selectAlbum(a);
            onPicked();
          },
        );
      },
    );
  }
}

class _SelectionBar extends StatelessWidget {
  const _SelectionBar({required this.vm});

  final PhotoPickerViewModel vm;

  @override
  Widget build(BuildContext context) {
    final enough = vm.canContinue;
    return SafeArea(
      child: Container(
        decoration: const BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8)]),
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            Text(S.selectedCount(vm.selected.length), style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                vm.meterText,
                style: TextStyle(color: enough ? AppColors.text : AppColors.failure, fontSize: 13),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ]),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: vm.progress,
              minHeight: 6,
              backgroundColor: AppColors.grey,
              color: enough ? AppColors.success : AppColors.warning,
            ),
          ),
          if (vm.selected.isNotEmpty) ...[
            const SizedBox(height: 10),
            SizedBox(
              height: 52,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                reverse: true,
                itemCount: vm.selected.length,
                separatorBuilder: (_, _) => const SizedBox(width: 6),
                itemBuilder: (_, i) {
                  final a = vm.selected[vm.selected.length - 1 - i];
                  return GestureDetector(
                    onTap: () => vm.toggle(a),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: SizedBox(
                        width: 52,
                        child: Image(
                          image: AssetEntityImageProvider(a, isOriginal: false, thumbnailSize: const ThumbnailSize.square(150)),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ]),
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
            icon: Icon(selected ? Icons.check_circle : Icons.radio_button_unchecked,
                color: selected ? AppColors.accent : Colors.white),
            onPressed: () => vm.toggle(a),
          ),
        ],
      ),
      body: Stack(children: [
        PageView.builder(
          controller: _controller,
          itemCount: vm.assets.length,
          onPageChanged: (i) => setState(() => _index = i),
          itemBuilder: (_, i) => InteractiveViewer(
            child: Image(
              image: AssetEntityImageProvider(vm.assets[i], isOriginal: false, thumbnailSize: const ThumbnailSize.square(1400)),
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
              child: const Row(children: [
                Icon(Icons.warning_amber_rounded, color: AppColors.warning),
                SizedBox(width: 8),
                Text(S.lowResolution, style: TextStyle(color: Colors.white)),
              ]),
            ),
          ),
      ]),
    );
  }
}
