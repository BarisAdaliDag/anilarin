import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/theme.dart';
import '../../constants/strings_tr.dart';
import '../../models/catalog.dart';
import '../../models/photo_book.dart';
import '../../view_model/app_view_model.dart';
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

/// Sürüklenen öğe: ya bir sayfadaki fotoğraf ya da kullanılmayan fotoğraflar tepsisinden bir fotoğraf.
class DragItem {
  final SlotRef? slot;
  final String? unusedPhotoId;

  const DragItem.slot(SlotRef this.slot) : unusedPhotoId = null;

  const DragItem.unused(String this.unusedPhotoId) : slot = null;

  String photoId(EditorViewModel vm) => unusedPhotoId ?? vm.slotAt(slot!)!.photoId;
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
      create: (_) => EditorViewModel(book: book.clone(), catalog: app.catalog!, onSave: app.saveBook),
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
  bool _dragging = false;

  @override
  void initState() {
    super.initState();
    if (widget.firstCreation) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(S.dragToSwap), duration: Duration(seconds: 4)),
        );
      });
    }
  }

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
    final spreads = <List<int>>[];
    for (var i = 1; i < book.pages.length; i += 2) {
      spreads.add([i, if (i + 1 < book.pages.length) i + 1]);
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: Text(book.title.isEmpty ? S.photoBook : book.title, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(tooltip: S.undo, onPressed: vm.canUndo ? vm.undo : null, icon: const Icon(Icons.undo)),
          IconButton(tooltip: S.redo, onPressed: vm.canRedo ? vm.redo : null, icon: const Icon(Icons.redo)),
          IconButton(onPressed: () => _designMenu(context, vm), icon: const Icon(Icons.more_horiz)),
        ],
      ),
      body: Column(children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              _HeaderCard(vm: vm),
              const SizedBox(height: 20),
              _PageLabel(label: S.cover, onMore: () => _pageMenu(context, vm, 0)),
              Center(
                child: FractionallySizedBox(
                  widthFactor: 0.62,
                  child: _EditablePage(
                    pageIndex: 0,
                    onDragChanged: (d) => setState(() => _dragging = d),
                    onPageTap: () => _pageMenu(context, vm, 0),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              for (final spread in spreads) ...[
                _Spread(
                  pages: spread,
                  onDragChanged: (d) => setState(() => _dragging = d),
                  onPageMenu: (i) => _pageMenu(context, vm, i),
                ),
                const SizedBox(height: 18),
              ],
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: vm.canAddPages ? () => _addPages(context, vm) : null,
                    icon: const Icon(Icons.add),
                    label: const Text(S.addMorePages),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: vm.canRemovePages ? () => _openRemove(context, vm) : null,
                    icon: const Icon(Icons.remove),
                    label: const Text(S.removePages),
                  ),
                ),
              ]),
              if (vm.product.canChangePages)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    S.extraPagesEach(formatPrice(vm.product.incrementPriceCents)),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.text, fontSize: 12),
                  ),
                ),
            ],
          ),
        ),
        if (book.unusedPhotoIds.isNotEmpty || _dragging) _UnusedTray(vm: vm, onDragChanged: (d) => setState(() => _dragging = d)),
        _BottomBar(vm: vm),
      ]),
    );
  }

  Future<void> _addPages(BuildContext context, EditorViewModel vm) async {
    vm.addPages(vm.product.pageIncrement);
  }

  void _openRemove(BuildContext context, EditorViewModel vm) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ChangeNotifierProvider.value(value: vm, child: const RemovePagesScreen()),
    ));
  }

  void _openTemplates(BuildContext context, EditorViewModel vm, int pageIndex) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ChangeNotifierProvider.value(value: vm, child: TemplatePickerScreen(pageIndex: pageIndex)),
    ));
  }

  Future<void> _pageMenu(BuildContext context, EditorViewModel vm, int pageIndex) async {
    final page = vm.book.pages[pageIndex];
    final hasCaptionSlot = vm.templateOf(pageIndex).textSlots(vm.format).isNotEmpty;
    final hasCaption = page.texts.any((t) => t.isNotEmpty);
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (c) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              page.isCover ? S.cover : S.pageN(pageIndex),
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
            ),
          ),
          _menuItem(c, 'template', Icons.dashboard_outlined, S.changeTemplate),
          if (page.isCover) _menuItem(c, 'title', Icons.title, S.editTitle),
          if (!page.isCover) _menuItem(c, 'caption', Icons.short_text, hasCaption ? S.editCaption : S.addCaption),
          if (!page.isCover && hasCaption && hasCaptionSlot)
            _menuItem(c, 'removeCaption', Icons.format_clear, S.removeCaption),
          _menuItem(c, 'theme', Icons.palette_outlined, S.changeTheme),
          if (!page.isCover) ...[
            _menuItem(c, 'insert', Icons.note_add_outlined, S.insertNewPage, enabled: vm.canAddPages),
            _menuItem(c, 'duplicate', Icons.copy_outlined, S.duplicatePage, enabled: vm.canAddPages),
            _menuItem(c, 'delete', Icons.delete_outline, S.deletePage, enabled: vm.canRemovePages, danger: true),
          ],
        ]),
      ),
    );
    if (!context.mounted || action == null) return;
    switch (action) {
      case 'template':
        _openTemplates(context, vm, pageIndex);
      case 'title':
        await editTitleDialog(context, vm);
      case 'caption':
        await editCaptionFlow(context, vm, pageIndex);
      case 'removeCaption':
        for (var i = 0; i < page.texts.length; i++) {
          if (page.texts[i].isNotEmpty) vm.setCaption(pageIndex, i, '');
        }
      case 'theme':
        await showThemeSheet(context, vm, pageIndex: pageIndex);
      case 'insert':
        vm.addPages(1, afterIndex: pageIndex);
      case 'duplicate':
        vm.duplicatePage(pageIndex);
      case 'delete':
        vm.deletePage(pageIndex);
    }
  }

  Future<void> _designMenu(BuildContext context, EditorViewModel vm) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (c) => SafeArea(
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            _menuItem(c, 'title', Icons.title, S.editTitle),
            _menuItem(c, 'theme', Icons.palette_outlined, S.changeTheme),
            _menuItem(c, 'font', Icons.font_download_outlined, S.changeFont),
            _menuItem(c, 'photos', Icons.add_photo_alternate_outlined, S.addMorePhotos),
            _menuItem(c, 'add', Icons.add_box_outlined, S.addMorePages, enabled: vm.canAddPages),
            _menuItem(c, 'remove', Icons.indeterminate_check_box_outlined, S.removePages, enabled: vm.canRemovePages),
            _menuItem(c, 'rearrange', Icons.swap_vert, S.rearrangePages),
            _menuItem(c, 'preview', Icons.menu_book_outlined, S.preview),
            _menuItem(c, 'about', Icons.info_outline, S.aboutBook),
            _menuItem(c, 'delete', Icons.delete_outline, S.deleteBook, danger: true),
          ]),
        ),
      ),
    );
    if (!context.mounted || action == null) return;
    switch (action) {
      case 'title':
        await editTitleDialog(context, vm);
      case 'theme':
        await showThemeSheet(context, vm);
      case 'font':
        await showFontSheet(context, vm);
      case 'photos':
        await addPhotosFlow(context, vm);
      case 'add':
        vm.addPages(vm.product.pageIncrement);
      case 'remove':
        _openRemove(context, vm);
      case 'rearrange':
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => ChangeNotifierProvider.value(value: vm, child: const RearrangePagesScreen()),
        ));
      case 'preview':
        openPreview(context, vm);
      case 'about':
        await showAboutBook(context, vm);
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

Widget _menuItem(BuildContext c, String value, IconData icon, String label, {bool enabled = true, bool danger = false}) {
  return ListTile(
    enabled: enabled,
    leading: Icon(icon, color: danger ? AppColors.failure : AppColors.textStrong),
    title: Text(label, style: TextStyle(color: danger ? AppColors.failure : null, fontWeight: FontWeight.w500)),
    onTap: () => Navigator.pop(c, value),
  );
}

void openPreview(BuildContext context, EditorViewModel vm) {
  Navigator.of(context).push(MaterialPageRoute(
    fullscreenDialog: true,
    builder: (_) => ChangeNotifierProvider.value(value: vm, child: const PreviewScreen()),
  ));
}

Future<void> addPhotosFlow(BuildContext context, EditorViewModel vm) async {
  final photos = await Navigator.of(context).push<List<BookPhoto>>(
    MaterialPageRoute(builder: (_) => PhotoPickerScreen(maxPhotos: vm.product.photoMax)),
  );
  if (photos != null && photos.isNotEmpty) vm.addPhotos(photos);
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.vm});

  final EditorViewModel vm;

  @override
  Widget build(BuildContext context) {
    final p = vm.product;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(p.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            const SizedBox(height: 2),
            Text(
              '${p.sizeLabel} · ${p.formatLabel} · ${p.dimensionsCm} cm · ${S.pagesCount(vm.book.pageCount)}',
              style: const TextStyle(color: AppColors.text, fontSize: 13),
            ),
          ]),
        ),
        Text(
          formatPrice(p.totalPrice(vm.book.pageCount, vm.book.options)),
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17, color: AppColors.accentDark),
        ),
      ]),
    );
  }
}

class _PageLabel extends StatelessWidget {
  const _PageLabel({required this.label, required this.onMore});

  final String label;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      Text(label, style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.text)),
      IconButton(
        visualDensity: VisualDensity.compact,
        onPressed: onMore,
        icon: const Icon(Icons.more_horiz, size: 20, color: AppColors.text),
      ),
    ]);
  }
}

class _Spread extends StatelessWidget {
  const _Spread({required this.pages, required this.onDragChanged, required this.onPageMenu});

  final List<int> pages;
  final ValueChanged<bool> onDragChanged;
  final ValueChanged<int> onPageMenu;

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Container(
        decoration: const BoxDecoration(boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 4))]),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          for (var k = 0; k < 2; k++)
            Expanded(
              child: k < pages.length
                  ? Stack(children: [
                      _EditablePage(
                        pageIndex: pages[k],
                        onDragChanged: onDragChanged,
                        onPageTap: () => onPageMenu(pages[k]),
                      ),
                      // sırt gölgesi
                      Positioned.fill(
                        child: IgnorePointer(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: k == 0 ? Alignment.centerRight : Alignment.centerLeft,
                                end: k == 0 ? Alignment.centerLeft : Alignment.centerRight,
                                colors: const [Color(0x22000000), Color(0x00000000)],
                                stops: const [0, 0.08],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ])
                  : const SizedBox.shrink(),
            ),
        ]),
      ),
      Row(children: [
        for (var k = 0; k < 2; k++)
          Expanded(
            child: k < pages.length
                ? _PageLabel(label: S.pageN(pages[k]), onMore: () => onPageMenu(pages[k]))
                : const SizedBox.shrink(),
          ),
      ]),
    ]);
  }
}

/// Fotoğrafları sürükle-bırak ile değiştirilebilen, dokunarak düzenlenebilen sayfa.
class _EditablePage extends StatelessWidget {
  const _EditablePage({required this.pageIndex, required this.onDragChanged, required this.onPageTap});

  final int pageIndex;
  final ValueChanged<bool> onDragChanged;
  final VoidCallback onPageTap;

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<EditorViewModel>();
    return GestureDetector(
      onTap: onPageTap,
      child: PrintPageView(
        book: vm.book,
        pageIndex: pageIndex,
        catalog: vm.catalog,
        showPlaceholders: true,
        thumbSize: 500,
        onTextTap: (i) => vm.book.pages[pageIndex].isCover
            ? editTitleDialog(context, vm)
            : editCaptionDialog(context, vm, pageIndex, i),
        slotWrapper: (context, slot, child) => _SlotTarget(
          vm: vm,
          ref: SlotRef(pageIndex, slot),
          onDragChanged: onDragChanged,
          child: child,
        ),
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
        Widget content = GestureDetector(
          onTap: () => _tap(context, slot),
          child: child,
        );
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
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider.value(value: vm, child: EditPhotoScreen(ref: ref)),
      ));
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
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text(S.unusedPhotos, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
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
        ]),
      ),
    );
    if (choice == null) return;
  }
  if (!context.mounted) return;
  if (choice != null && choice != '__gallery__') {
    vm.placeUnused(choice, ref);
    return;
  }
  final picked = await Navigator.of(context).push<List<BookPhoto>>(
    MaterialPageRoute(builder: (_) => const PhotoPickerScreen(single: true)),
  );
  if (picked != null && picked.isNotEmpty) vm.replacePhoto(ref, picked.first);
}

class _DragFeedback extends StatelessWidget {
  const _DragFeedback({required this.photoId});

  final String photoId;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(8),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(width: 90, height: 90, child: PhotoImage(photoId: photoId, size: 250)),
    );
  }
}

class _UnusedTray extends StatelessWidget {
  const _UnusedTray({required this.vm, required this.onDragChanged});

  final EditorViewModel vm;
  final ValueChanged<bool> onDragChanged;

  @override
  Widget build(BuildContext context) {
    final unused = vm.book.unusedPhotoIds;
    return DragTarget<DragItem>(
      onWillAcceptWithDetails: (d) => d.data.slot != null,
      onAcceptWithDetails: (d) => vm.removePhoto(d.data.slot!),
      builder: (context, candidates, _) => Container(
        color: candidates.isNotEmpty ? AppColors.accent.withValues(alpha: 0.12) : Colors.white,
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            Text('${S.unusedPhotos} (${unused.length})', style: const TextStyle(fontWeight: FontWeight.w700)),
            const Spacer(),
            if (unused.isNotEmpty)
              TextButton(onPressed: vm.discardUnused, child: const Text(S.discardUnused)),
          ]),
          SizedBox(
            height: 64,
            child: unused.isEmpty
                ? const Center(child: Text('Fotoğrafı buraya bırakarak sayfadan çıkar', style: TextStyle(color: AppColors.text)))
                : ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: unused.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 6),
                    itemBuilder: (_, i) => LongPressDraggable<DragItem>(
                      data: DragItem.unused(unused[i]),
                      delay: const Duration(milliseconds: 150),
                      onDragStarted: () => onDragChanged(true),
                      onDragEnd: (_) => onDragChanged(false),
                      feedback: _DragFeedback(photoId: unused[i]),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: SizedBox(width: 64, child: PhotoImage(photoId: unused[i], size: 200)),
                      ),
                    ),
                  ),
          ),
          if (unused.isNotEmpty)
            const Text(S.unusedHint, style: TextStyle(fontSize: 11, color: AppColors.text)),
        ]),
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.vm});

  final EditorViewModel vm;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        decoration: const BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 6)]),
        child: Row(children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => openPreview(context, vm),
              icon: const Icon(Icons.menu_book_outlined),
              label: const Text(S.preview),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton(
              onPressed: () => buyBook(context, vm),
              child: const Text(S.buy),
            ),
          ),
        ]),
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
