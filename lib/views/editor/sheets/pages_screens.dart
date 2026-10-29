import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../config/theme.dart';
import '../../../constants/strings_tr.dart';
import '../../../view_model/editor_view_model.dart';
import '../../widgets/print_page_view.dart';

/// Sayfaları sürükleyerek yeniden sırala (Popsa ReArrangePagesActivity).
class RearrangePagesScreen extends StatefulWidget {
  const RearrangePagesScreen({super.key});

  @override
  State<RearrangePagesScreen> createState() => _RearrangePagesScreenState();
}

class _RearrangePagesScreenState extends State<RearrangePagesScreen> {
  late List<String> _order = context.read<EditorViewModel>().book.innerPages.map((p) => p.id).toList();

  @override
  Widget build(BuildContext context) {
    final vm = context.read<EditorViewModel>();
    final indexById = {for (var i = 0; i < vm.book.pages.length; i++) vm.book.pages[i].id: i};
    return Scaffold(
      appBar: AppBar(
        title: const Text(S.rearrangePages),
        actions: [
          TextButton(
            onPressed: () {
              vm.reorderInner(_order);
              Navigator.pop(context);
            },
            child: const Text(
              S.save,
              style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.accent),
            ),
          ),
        ],
      ),
      body: ReorderableListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: _order.length,
        onReorder: (from, to) => setState(() {
          final list = [..._order];
          final id = list.removeAt(from);
          list.insert(to > from ? to - 1 : to, id);
          _order = list;
        }),
        itemBuilder: (_, i) => ListTile(
          key: ValueKey(_order[i]),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          leading: SizedBox(
            width: 90,
            child: PrintPageView(book: vm.book, pageIndex: indexById[_order[i]]!, catalog: vm.catalog, thumbSize: 200),
          ),
          title: Text(S.pageN(i + 1), style: const TextStyle(fontWeight: FontWeight.w600)),
          trailing: const Icon(Icons.drag_handle),
        ),
      ),
    );
  }
}

/// Kaldırılacak sayfaları seç (Popsa RemovePagesActivity).
class RemovePagesScreen extends StatefulWidget {
  const RemovePagesScreen({super.key});

  @override
  State<RemovePagesScreen> createState() => _RemovePagesScreenState();
}

class _RemovePagesScreenState extends State<RemovePagesScreen> {
  final _selected = <int>{};

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<EditorViewModel>();
    final removable = vm.book.pageCount - vm.product.pagesMin;
    return Scaffold(
      appBar: AppBar(title: const Text(S.removePages)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
            child: Text(S.minPagesWarning(vm.product.pagesMin), style: TextStyle(color: context.mutedText)),
          ),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 16,
                crossAxisSpacing: 12,
                childAspectRatio: 0.85,
              ),
              itemCount: vm.book.pages.length - 1,
              itemBuilder: (_, i) {
                final index = i + 1;
                final selected = _selected.contains(index);
                final disabled = !selected && _selected.length >= removable;
                return GestureDetector(
                  onTap: disabled
                      ? null
                      : () => setState(() => selected ? _selected.remove(index) : _selected.add(index)),
                  child: Opacity(
                    opacity: disabled ? 0.4 : 1,
                    child: Column(
                      children: [
                        Stack(
                          children: [
                            DecoratedBox(
                              position: DecorationPosition.foreground,
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: selected ? AppColors.failure : context.divider,
                                  width: selected ? 3 : 1,
                                ),
                              ),
                              child: PrintPageView(
                                book: vm.book,
                                pageIndex: index,
                                catalog: vm.catalog,
                                thumbSize: 200,
                              ),
                            ),
                            if (selected)
                              const Positioned(
                                top: 4,
                                right: 4,
                                child: CircleAvatar(
                                  radius: 12,
                                  backgroundColor: AppColors.failure,
                                  child: Icon(Icons.close, size: 16, color: Colors.white),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(S.pageN(index), style: const TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: FilledButton(
                style: FilledButton.styleFrom(backgroundColor: AppColors.failure),
                onPressed: _selected.isEmpty
                    ? null
                    : () {
                        if (vm.removePages(_selected)) Navigator.pop(context);
                      },
                child: Text(S.removePagesN(_selected.length)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
