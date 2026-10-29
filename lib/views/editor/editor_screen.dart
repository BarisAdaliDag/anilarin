import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../config/theme.dart';
import '../../constants/strings_tr.dart';
import '../../models/photo_book.dart';
import '../../view_model/app_view_model.dart';
import '../../services/palette_service.dart';
import '../../view_model/editor_view_model.dart';
import '../basket/basket_screen.dart';
import '../photo_picker/photo_picker_screen.dart';
import '../preview/preview_screen.dart';
import '../widgets/photo_image.dart';
import '../widgets/print_page_view.dart';
import 'edit_photo_screen.dart';
import 'sheets/editor_dialogs.dart';
import 'sheets/font_sheet.dart';
import 'sheets/pages_screens.dart';
import 'sheets/template_picker_screen.dart';
import 'sheets/theme_sheet.dart';

/// Sürüklenen öğe: ya bir sayfadaki fotoğraf ya da kullanılmayan fotoğraflar panelinden bir fotoğraf.
class DragItem {
  final SlotRef? slot;
  final String? unusedPhotoId;

  const DragItem.slot(SlotRef this.slot) : unusedPhotoId = null;

  const DragItem.unused(String this.unusedPhotoId) : slot = null;
}

/// Fotoğraf kitabı editörü (Popsa PrintLayoutActivity).
class EditorScreen extends StatelessWidget {
  const EditorScreen({super.key, required this.bookId, this.firstCreation = false});

  final String bookId;
  final bool firstCreation;

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppViewModel>();
    final book = app.book(bookId);
    if (book == null) return const Scaffold(body: Center(child: Text('Tasarım bulunamadı')));
    return ChangeNotifierProvider(
      create: (_) =>
          EditorViewModel(book: book.clone(), catalog: app.catalog!, onSave: app.saveBook)
            ..refreshPagePalettes(PaletteService.forPhotos),
      child: _EditorBody(firstCreation: firstCreation),
    );
  }
}

class _EditorBody extends StatefulWidget {
  const _EditorBody({required this.firstCreation});

  final bool firstCreation;

  @override
  State<_EditorBody> createState() => _EditorBodyState();
}

class _EditorBodyState extends State<_EditorBody> {
  bool _photosOpen = false;
  bool _dragging = false;

  @override
  void initState() {
    super.initState();
    if (widget.firstCreation) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _photosOpen = true);
      });
    }
  }

  void _setDragging(bool v) => setState(() => _dragging = v);

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<EditorViewModel>();
    final msg = vm.takeMessage();
    if (msg != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(msg)));
      });
    }
    final book = vm.book;
    final edited = DateFormat(
      "d MMMM y EEEE HH:mm",
      'tr',
    ).format(DateTime.fromMillisecondsSinceEpoch(book.updatedAtMs));

    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(tooltip: S.undo, onPressed: vm.canUndo ? vm.undo : null, icon: const Icon(Icons.undo)),
          IconButton(tooltip: S.redo, onPressed: vm.canRedo ? vm.redo : null, icon: const Icon(Icons.redo)),
          const SizedBox(width: 4),
          _Pill(label: 'Paylaş', onTap: () => _share(context)),
          const SizedBox(width: 8),
          _Pill(label: S.next, icon: Icons.arrow_forward, onTap: () => openPreview(context, vm)),
          const SizedBox(width: 12),
        ],
      ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 180),
            children: [
              Text(
                book.title.isEmpty ? S.photoBook : book.title,
                style: const TextStyle(fontSize: 27, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      '${vm.product.title} · son düzenleme $edited',
                      style: TextStyle(color: context.mutedText, fontSize: 15, height: 1.4),
                    ),
                  ),
                  _CircleButton(icon: Icons.info_outline, onTap: () => showAboutBook(context, vm)),
                ],
              ),
              const SizedBox(height: 16),
              Divider(color: context.divider),
              for (var i = 0; i < book.pages.length; i++) ...[
                _PageHeader(pageIndex: i, onDragChanged: _setDragging),
                _EditablePage(pageIndex: i, onDragChanged: _setDragging),
              ],
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: vm.canAddPages ? () => addPagesFlow(context, vm) : null,
                      child: const Text(S.addMorePages),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: vm.canRemovePages ? () => _openRemove(context, vm) : null,
                      child: const Text(S.removePages),
                    ),
                  ),
                ],
              ),
            ],
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: _photosOpen || _dragging
                    ? _PhotosPanel(
                        key: const ValueKey('photos'),
                        vm: vm,
                        onClose: () => setState(() => _photosOpen = false),
                        onDragChanged: _setDragging,
                      )
                    : _Toolbar(
                        key: const ValueKey('toolbar'),
                        unused: book.unusedPhotoIds.length,
                        onPhotos: () => setState(() => _photosOpen = true),
                        onThemes: () => showThemeSheet(context, vm),
                        onPages: () => _openRearrange(context, vm),
                        onOptions: () => _options(context, vm),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _share(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Paylaşım bu test sürümünde yok.')));
  }

  void _openRemove(BuildContext context, EditorViewModel vm) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider.value(value: vm, child: const RemovePagesScreen()),
      ),
    );
  }

  void _openRearrange(BuildContext context, EditorViewModel vm) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider.value(value: vm, child: const RearrangePagesScreen()),
      ),
    );
  }

  Future<void> _options(BuildContext context, EditorViewModel vm) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (c) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
                child: Text(vm.book.title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w500)),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Text(vm.product.title, style: TextStyle(color: c.mutedText)),
              ),
              menuItem(c, 'title', Icons.edit_outlined, S.editTitle),
              menuItem(c, 'font', Icons.text_fields, S.changeFont),
              menuItem(
                c,
                'borders',
                Icons.border_clear,
                vm.allBorderless ? 'Kenarlıkları Geri Getir' : 'Kenarlıkları Kaldır',
                subtitle: 'Tüm sayfalara uygulanır',
              ),
              menuItem(c, 'add', Icons.note_add_outlined, S.addMorePages, enabled: vm.canAddPages),
              menuItem(c, 'remove', Icons.remove_circle_outline, S.removePages, enabled: vm.canRemovePages),
              menuItem(c, 'photos', Icons.add_photo_alternate_outlined, S.addMorePhotos),
              menuItem(c, 'preview', Icons.view_in_ar_outlined, S.preview),
              menuItem(c, 'duplicate', Icons.copy_outlined, S.duplicateBook),
              menuItem(c, 'delete', Icons.delete_outline, S.deleteBook, danger: true),
            ],
          ),
        ),
      ),
    );
    if (!context.mounted || action == null) return;
    switch (action) {
      case 'title':
        await editTitleDialog(context, vm);
      case 'font':
        await showFontSheet(context, vm);
      case 'borders':
        vm.setAllBorderless(!vm.allBorderless);
      case 'add':
        await addPagesFlow(context, vm);
      case 'remove':
        _openRemove(context, vm);
      case 'photos':
        await addPhotosFlow(context, vm);
      case 'preview':
        openPreview(context, vm);
      case 'duplicate':
        await vm.flush();
        if (!context.mounted) return;
        await context.read<AppViewModel>().duplicateBook(vm.book.id);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Kopya Tasarımlarım\'a eklendi')));
        }
      case 'delete':
        final ok = await confirmDelete(context);
        if (ok && context.mounted) {
          final app = context.read<AppViewModel>();
          final nav = Navigator.of(context);
          await app.deleteBook(vm.book.id);
          nav.pop();
        }
    }
  }
}

Widget menuItem(
  BuildContext c,
  String value,
  IconData icon,
  String label, {
  bool enabled = true,
  bool danger = false,
  String? subtitle,
  Color? color,
}) {
  final fg = danger ? AppColors.failure : color;
  return ListTile(
    enabled: enabled,
    contentPadding: const EdgeInsets.symmetric(horizontal: 20),
    leading: Icon(icon, color: fg),
    title: Text(label, style: TextStyle(color: fg, fontSize: 16)),
    subtitle: subtitle == null ? null : Text(subtitle),
    onTap: () => Navigator.pop(c, value),
  );
}

void openPreview(BuildContext context, EditorViewModel vm) {
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => ChangeNotifierProvider.value(value: vm, child: const PreviewScreen()),
    ),
  );
}

Future<void> addPagesFlow(BuildContext context, EditorViewModel vm, {int? afterIndex}) async {
  final n = await showAddPagesDialog(
    context,
    increment: vm.product.incrementPriceCents,
    photosPerPage: vm.product.photosPerExtraPage,
    max: vm.product.pagesMax - vm.book.pageCount,
  );
  if (n != null && n > 0) vm.addPages(n, afterIndex: afterIndex);
}

Future<void> addPhotosFlow(BuildContext context, EditorViewModel vm) async {
  final photos = await Navigator.of(
    context,
  ).push<List<BookPhoto>>(MaterialPageRoute(builder: (_) => PhotoPickerScreen(maxPhotos: vm.product.photoMax)));
  if (photos != null && photos.isNotEmpty) vm.addPhotos(photos);
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.onTap, this.icon});

  final String label;
  final IconData? icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.pillColor,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
              if (icon != null) ...[const SizedBox(width: 4), Icon(icon, size: 18)],
            ],
          ),
        ),
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  const _CircleButton({required this.icon, required this.onTap, this.child, this.active = false});

  final IconData icon;
  final VoidCallback onTap;
  final Widget? child;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 10),
      child: Material(
        color: active ? AppColors.accent.withValues(alpha: 0.25) : context.pillColor,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(width: 40, height: 40, child: Center(child: child ?? Icon(icon, size: 20))),
        ),
      ),
    );
  }
}

/// Sayfa başlığı ve sayfa düğmeleri: tema rengi, kenarlık, şablon, menü.
class _PageHeader extends StatelessWidget {
  const _PageHeader({required this.pageIndex, required this.onDragChanged});

  final int pageIndex;
  final ValueChanged<bool> onDragChanged;

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<EditorViewModel>();
    final page = vm.book.pages[pageIndex];
    final theme = vm.themeOf(pageIndex);
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 28, 0, 14),
      child: Row(
        children: [
          Expanded(child: Text(page.isCover ? S.frontCover : S.pageN(pageIndex), style: const TextStyle(fontSize: 19))),
          _CircleButton(
            icon: Icons.circle,
            onTap: () => showThemeSheet(context, vm, pageIndex: pageIndex),
            child: Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: theme.background,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.black26),
              ),
            ),
          ),
          if (!page.isCover)
            _CircleButton(icon: Icons.crop_free, active: page.borderless, onTap: () => vm.toggleBorderless(pageIndex)),
          _CircleButton(
            icon: page.isCover ? Icons.call_to_action_outlined : Icons.grid_view,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ChangeNotifierProvider.value(
                  value: vm,
                  child: TemplatePickerScreen(pageIndex: pageIndex),
                ),
              ),
            ),
          ),
          _CircleButton(icon: Icons.more_horiz, onTap: () => _pageMenu(context, vm, pageIndex)),
        ],
      ),
    );
  }

  Future<void> _pageMenu(BuildContext context, EditorViewModel vm, int pageIndex) async {
    final page = vm.book.pages[pageIndex];
    final hasCaption = page.caption.isNotEmpty;
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (c) => SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                page.isCover ? S.frontCover : 'Sayfa $pageIndex / ${vm.book.pageCount}',
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w500),
              ),
            ),
            Divider(color: c.divider, indent: 20, endIndent: 20),
            if (page.isCover) menuItem(c, 'title', Icons.edit_outlined, S.editTitle),
            if (!page.isCover) menuItem(c, 'caption', Icons.text_fields, hasCaption ? S.editCaption : S.addCaption),
            if (!page.isCover && hasCaption) menuItem(c, 'removeCaption', Icons.format_clear, S.removeCaption),
            menuItem(c, 'template', Icons.grid_view, S.changeTemplate),
            if (!page.isCover) ...[
              menuItem(c, 'insert', Icons.playlist_add, S.insertNewPage, enabled: vm.canAddPages),
              menuItem(c, 'duplicate', Icons.copy_outlined, S.duplicatePage, enabled: vm.canAddPages),
              menuItem(c, 'delete', Icons.delete_outline, S.deletePage, enabled: vm.canRemovePages, danger: true),
            ],
          ],
        ),
      ),
    );
    if (!context.mounted || action == null) return;
    switch (action) {
      case 'title':
        await editTitleDialog(context, vm);
      case 'caption':
        await editCaptionFlow(context, vm, pageIndex);
      case 'removeCaption':
        vm.setPageCaption(pageIndex, '');
      case 'template':
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ChangeNotifierProvider.value(
              value: vm,
              child: TemplatePickerScreen(pageIndex: pageIndex),
            ),
          ),
        );
      case 'insert':
        vm.addPages(1, afterIndex: pageIndex);
      case 'duplicate':
        vm.duplicatePage(pageIndex);
      case 'delete':
        vm.deletePage(pageIndex);
    }
  }
}

/// Fotoğrafları sürükle-bırak ile değiştirilebilen, dokunarak düzenlenebilen sayfa.
class _EditablePage extends StatelessWidget {
  const _EditablePage({required this.pageIndex, required this.onDragChanged});

  final int pageIndex;
  final ValueChanged<bool> onDragChanged;

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<EditorViewModel>();
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: PrintPageView(
        book: vm.book,
        pageIndex: pageIndex,
        catalog: vm.catalog,
        showPlaceholders: true,
        thumbSize: 700,
        onTextTap: (i) => vm.book.pages[pageIndex].isCover
            ? editTitleDialog(context, vm)
            : editCaptionDialog(context, vm, pageIndex, i),
        slotWrapper: (context, slot, child) =>
            _SlotTarget(vm: vm, ref: SlotRef(pageIndex, slot), onDragChanged: onDragChanged, child: child),
      ),
    );
  }
}

class _SlotTarget extends StatelessWidget {
  const _SlotTarget({required this.vm, required this.ref, required this.onDragChanged, required this.child});

  final EditorViewModel vm;
  final SlotRef ref;
  final ValueChanged<bool> onDragChanged;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final slot = vm.slotAt(ref);
    return DragTarget<DragItem>(
      onWillAcceptWithDetails: (d) => d.data.slot != ref,
      onAcceptWithDetails: (d) {
        final item = d.data;
        if (item.slot != null) {
          vm.swap(item.slot!, ref);
        } else {
          vm.placeUnused(item.unusedPhotoId!, ref);
        }
      },
      builder: (context, candidates, _) {
        Widget content = GestureDetector(onTap: () => _tap(context, slot), child: child);
        if (slot != null) {
          content = LongPressDraggable<DragItem>(
            data: DragItem.slot(ref),
            onDragStarted: () => onDragChanged(true),
            onDragEnd: (_) => onDragChanged(false),
            feedback: _DragFeedback(photoId: slot.photoId),
            childWhenDragging: Opacity(opacity: 0.35, child: child),
            child: content,
          );
        }
        if (candidates.isNotEmpty) {
          content = DecoratedBox(
            position: DecorationPosition.foreground,
            decoration: BoxDecoration(border: Border.all(color: AppColors.accent, width: 3)),
            child: content,
          );
        }
        return content;
      },
    );
  }

  Future<void> _tap(BuildContext context, PhotoSlot? slot) async {
    if (slot != null) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ChangeNotifierProvider.value(
            value: vm,
            child: EditPhotoScreen(ref: ref),
          ),
        ),
      );
      return;
    }
    await fillEmptySlot(context, vm, ref);
  }
}

Future<void> fillEmptySlot(BuildContext context, EditorViewModel vm, SlotRef ref) async {
  final unused = vm.book.unusedPhotoIds;
  String? choice;
  if (unused.isNotEmpty) {
    choice = await showModalBottomSheet<String>(
      context: context,
      builder: (c) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(S.unusedPhotos, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 17)),
            const SizedBox(height: 12),
            SizedBox(
              height: 96,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                itemCount: unused.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (_, i) => GestureDetector(
                  onTap: () => Navigator.pop(c, unused[i]),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(width: 96, child: PhotoImage(photoId: unused[i], size: 250)),
                  ),
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text(S.addMorePhotos),
              onTap: () => Navigator.pop(c, '__gallery__'),
            ),
          ],
        ),
      ),
    );
    if (choice == null) return;
  }
  if (!context.mounted) return;
  if (choice != null && choice != '__gallery__') {
    vm.placeUnused(choice, ref);
    return;
  }
  final picked = await Navigator.of(
    context,
  ).push<List<BookPhoto>>(MaterialPageRoute(builder: (_) => const PhotoPickerScreen(single: true)));
  if (picked != null && picked.isNotEmpty) vm.replacePhoto(ref, picked.first);
}

class _DragFeedback extends StatelessWidget {
  const _DragFeedback({required this.photoId});

  final String photoId;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 10,
      borderRadius: BorderRadius.circular(8),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(width: 96, height: 96, child: PhotoImage(photoId: photoId, size: 250)),
    );
  }
}

/// Popsa'nın yüzen alt araç çubuğu.
class _Toolbar extends StatelessWidget {
  const _Toolbar({
    super.key,
    required this.unused,
    required this.onPhotos,
    required this.onThemes,
    required this.onPages,
    required this.onOptions,
  });

  final int unused;
  final VoidCallback onPhotos;
  final VoidCallback onThemes;
  final VoidCallback onPages;
  final VoidCallback onOptions;

  @override
  Widget build(BuildContext context) {
    Widget item(IconData icon, String label, VoidCallback onTap, {bool badge = false}) => InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Badge(isLabelVisible: badge, smallSize: 9, backgroundColor: AppColors.accent, child: Icon(icon, size: 28)),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontSize: 13)),
          ],
        ),
      ),
    );
    return Center(
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        decoration: BoxDecoration(
          color: context.isDark ? const Color(0xFF2A2A2A) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 16, offset: Offset(0, 4))],
        ),
        child: IntrinsicHeight(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              item(Icons.photo_library_outlined, S.photos, onPhotos, badge: unused > 0),
              item(Icons.palette_outlined, S.themes, onThemes),
              item(Icons.menu_book_outlined, S.pages, onPages),
              VerticalDivider(width: 1, color: context.divider, indent: 8, endIndent: 8),
              item(Icons.more_horiz, S.options, onOptions),
            ],
          ),
        ),
      ),
    );
  }
}

/// Kalıcı "Fotoğraflar" paneli: kullanılmayan fotoğraflar sayfalara sürüklenir, sayfadan buraya bırakılan çıkarılır.
class _PhotosPanel extends StatelessWidget {
  const _PhotosPanel({super.key, required this.vm, required this.onClose, required this.onDragChanged});

  final EditorViewModel vm;
  final VoidCallback onClose;
  final ValueChanged<bool> onDragChanged;

  @override
  Widget build(BuildContext context) {
    final unused = vm.book.unusedPhotoIds;
    return DragTarget<DragItem>(
      onWillAcceptWithDetails: (d) => d.data.slot != null,
      onAcceptWithDetails: (d) => vm.removePhoto(d.data.slot!),
      builder: (context, candidates, _) => Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 14),
        decoration: BoxDecoration(
          color: candidates.isNotEmpty
              ? AppColors.accent.withValues(alpha: 0.3)
              : (context.isDark ? const Color(0xFF2A2A2A) : Colors.white),
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 16, offset: Offset(0, 4))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(S.photos, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                      Text('${unused.length} kullanılmıyor', style: TextStyle(color: context.mutedText, fontSize: 13)),
                    ],
                  ),
                ),
                if (unused.isNotEmpty)
                  IconButton(
                    tooltip: S.discardUnused,
                    onPressed: vm.discardUnused,
                    icon: const Icon(Icons.delete_sweep_outlined),
                  ),
                IconButton(onPressed: onClose, icon: const Icon(Icons.close)),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 78,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  GestureDetector(
                    onTap: () => addPhotosFlow(context, vm),
                    child: Container(
                      width: 78,
                      decoration: BoxDecoration(
                        border: Border.all(color: context.divider, width: 1.5),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.add, size: 30),
                    ),
                  ),
                  for (final id in unused)
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: LongPressDraggable<DragItem>(
                        data: DragItem.unused(id),
                        delay: const Duration(milliseconds: 150),
                        onDragStarted: () => onDragChanged(true),
                        onDragEnd: (_) => onDragChanged(false),
                        feedback: _DragFeedback(photoId: id),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: SizedBox(width: 78, child: PhotoImage(photoId: id, size: 220)),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              unused.isEmpty ? 'Bir fotoğrafı çıkarmak için buraya sürükle.' : S.dragToSwap,
              style: TextStyle(color: context.mutedText, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> buyBook(BuildContext context, EditorViewModel vm) async {
  final app = context.read<AppViewModel>();
  final nav = Navigator.of(context);
  await vm.flush();
  await app.addToBasket(vm.book);
  nav.push(MaterialPageRoute(builder: (_) => const BasketScreen()));
}
