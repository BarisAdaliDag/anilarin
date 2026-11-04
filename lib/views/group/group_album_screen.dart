import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/theme.dart';
import '../../constants/strings_tr.dart';
import '../../models/group_code.dart';
import '../../models/photo_book.dart';
import '../../services/firebase_order_backend.dart';
import '../../view_model/app_view_model.dart';
import '../photo_picker/photo_picker_screen.dart';
import '../product/format_detail_screen.dart';
import '../widgets/photo_image.dart';

/// Grup Albümü (okul yıllığı): matbaanın verdiği kodla gruba girilir, öğrenci adını ve fotoğrafını ekler,
/// ardından dikey albümünü oluşturur. Ad ve fotoğraf siparişle birlikte matbaaya gider.
class GroupAlbumScreen extends StatefulWidget {
  const GroupAlbumScreen({super.key});

  @override
  State<GroupAlbumScreen> createState() => _GroupAlbumScreenState();
}

class _GroupAlbumScreenState extends State<GroupAlbumScreen> {
  final _code = TextEditingController();
  final _name = TextEditingController();
  GroupMembership? _group;
  bool _checking = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _group = context.read<AppViewModel>().group?.copy();
    _name.text = _group?.studentName ?? '';
    _name.addListener(() => setState(() => _group?.studentName = _name.text));
  }

  @override
  void dispose() {
    _code.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _join() async {
    final code = normalizeGroupCode(_code.text);
    if (code.length != groupCodeLength) return setState(() => _error = S.groupCodeInvalid);
    if (!FirebaseSetup.available) return setState(() => _error = S.groupServerMissing);
    FocusScope.of(context).unfocus();
    setState(() {
      _checking = true;
      _error = null;
    });
    try {
      final name = await FirebaseOrderBackend().groupName(code);
      if (!mounted) return;
      if (name == null) {
        setState(() => _error = S.groupNotFound);
      } else {
        setState(() => _group = GroupMembership(code: code, name: name, studentName: _name.text));
        await context.read<AppViewModel>().saveGroup(_group);
      }
    } catch (_) {
      if (mounted) setState(() => _error = S.groupConnectionError);
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _pickPhoto() async {
    final picked = await Navigator.of(
      context,
    ).push<List<BookPhoto>>(MaterialPageRoute(builder: (_) => const PhotoPickerScreen(single: true)));
    if (picked == null || picked.isEmpty || !mounted) return;
    setState(() => _group!.studentPhoto = picked.first);
    await context.read<AppViewModel>().saveGroup(_group);
  }

  Future<void> _createAlbum() async {
    final g = _group!..studentName = _name.text.trim();
    await context.read<AppViewModel>().saveGroup(g);
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FormatDetailScreen(type: 'hardback', format: 'portrait', group: g.copy()),
      ),
    );
  }

  Future<void> _leave() async {
    setState(() {
      _group = null;
      _code.clear();
      _error = null;
    });
    await context.read<AppViewModel>().saveGroup(null);
  }

  @override
  Widget build(BuildContext context) {
    final g = _group;
    return Scaffold(
      appBar: AppBar(title: const Text(S.groupAlbum)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: g == null ? _codeStep(context) : _studentStep(context, g),
      ),
    );
  }

  List<Widget> _codeStep(BuildContext context) => [
    Text(S.groupAlbumBody, style: TextStyle(fontSize: 16, height: 1.45, color: context.mutedText)),
    const SizedBox(height: 28),
    TextField(
      controller: _code,
      autofocus: true,
      textCapitalization: TextCapitalization.characters,
      style: const TextStyle(fontSize: 24, letterSpacing: 3, fontWeight: FontWeight.w600),
      decoration: InputDecoration(labelText: S.groupCode, hintText: 'K7M-4QX', errorText: _error),
      onSubmitted: (_) => _join(),
    ),
    const SizedBox(height: 20),
    FilledButton(
      onPressed: _checking ? null : _join,
      child: _checking
          ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
          : const Text(S.groupJoin),
    ),
  ];

  List<Widget> _studentStep(BuildContext context, GroupMembership g) => [
    Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: context.cardColor, borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          const Icon(Icons.school_outlined, size: 30),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(g.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                Text(formatGroupCode(g.code), style: TextStyle(color: context.mutedText, letterSpacing: 2)),
              ],
            ),
          ),
          TextButton(onPressed: _leave, child: const Text(S.groupChange)),
        ],
      ),
    ),
    const SizedBox(height: 24),
    Text(S.groupStudentBody, style: TextStyle(fontSize: 15, height: 1.45, color: context.mutedText)),
    const SizedBox(height: 18),
    TextField(
      controller: _name,
      textCapitalization: TextCapitalization.words,
      decoration: const InputDecoration(labelText: S.groupStudentName),
    ),
    const SizedBox(height: 20),
    Center(
      child: GestureDetector(
        onTap: _pickPhoto,
        child: SizedBox(
          width: 180,
          child: AspectRatio(
            // Vesikalık oranı: matbaa sınıf sayfasında bu oranda dizer.
            aspectRatio: 0.8,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: g.studentPhoto == null
                  ? ColoredBox(
                      color: context.pillColor,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_a_photo_outlined, size: 38, color: context.mutedText),
                          const SizedBox(height: 8),
                          Text(S.groupStudentPhoto, style: TextStyle(color: context.mutedText)),
                        ],
                      ),
                    )
                  : PhotoImage(photoId: g.studentPhoto!.id, size: 600),
            ),
          ),
        ),
      ),
    ),
    if (g.studentPhoto != null)
      Center(
        child: TextButton(onPressed: _pickPhoto, child: const Text(S.groupStudentPhotoChange)),
      ),
    const SizedBox(height: 24),
    FilledButton(onPressed: g.complete ? _createAlbum : null, child: const Text(S.groupCreateAlbum)),
    const SizedBox(height: 10),
    Text(
      S.groupSendNote,
      textAlign: TextAlign.center,
      style: TextStyle(fontSize: 13, color: context.mutedText),
    ),
  ];
}
