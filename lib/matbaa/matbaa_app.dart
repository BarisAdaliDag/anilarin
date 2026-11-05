import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../config/theme.dart';
import '../models/catalog.dart';
import '../repositories/catalog_repository.dart';
import '../print/print_renderer.dart';
import 'matbaa_service.dart';
import 'work_order.dart';

/// Matbaa masaüstü uygulaması: yetkili giriş, sipariş listesi, indirme + baskı PDF'i, durum ve buluttan silme.
class MatbaaApp extends StatelessWidget {
  const MatbaaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Anıların Matbaa',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(Brightness.light),
      darkTheme: buildAppTheme(Brightness.dark),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.userChanges(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          return snap.data == null ? const _LoginScreen() : const _AdminGate();
        },
      ),
    );
  }
}

class _LoginScreen extends StatefulWidget {
  const _LoginScreen();

  @override
  State<_LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<_LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  String? _error;
  bool _busy = false;

  Future<void> _signIn() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(email: _email.text.trim(), password: _password.text);
    } on FirebaseAuthException catch (e) {
      setState(() => _error = 'Giriş yapılamadı (${e.code}).');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Anıların Matbaa', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Text('Yetkili hesabınla giriş yap.', style: TextStyle(color: context.mutedText)),
              const SizedBox(height: 24),
              TextField(
                controller: _email,
                decoration: const InputDecoration(labelText: 'E-posta'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _password,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Şifre'),
                onSubmitted: (_) => _signIn(),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: AppColors.failure)),
              ],
              const SizedBox(height: 20),
              FilledButton(onPressed: _busy ? null : _signIn, child: const Text('Giriş Yap')),
            ],
          ),
        ),
      ),
    );
  }
}

/// Giriş yapan hesabın rolü editor ya da admin değilse içeri almaz.
class _AdminGate extends StatelessWidget {
  const _AdminGate();

  static Future<(String, Catalog)> _check() async => (await MatbaaService().role(), await CatalogRepository().load());

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<(String, Catalog)>(
      future: _check(),
      builder: (context, snap) {
        if (!snap.hasData && !snap.hasError) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snap.hasError || !const ['editor', 'admin'].contains(snap.data!.$1)) {
          final user = FirebaseAuth.instance.currentUser;
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('${user?.email ?? ''} bu uygulama için yetkili değil.', style: const TextStyle(fontSize: 18)),
                  const SizedBox(height: 8),
                  Text(
                    snap.hasError
                        ? '${snap.error}'
                        : 'Firestore\'da users/${user?.uid} kaydına role: "editor" ya da "admin" eklenmeli.',
                    style: TextStyle(color: context.mutedText),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton(onPressed: FirebaseAuth.instance.signOut, child: const Text('Çıkış Yap')),
                ],
              ),
            ),
          );
        }
        return _OrdersScreen(catalog: snap.data!.$2, admin: snap.data!.$1 == 'admin');
      },
    );
  }
}

class _OrdersScreen extends StatefulWidget {
  const _OrdersScreen({required this.catalog, required this.admin});

  final Catalog catalog;
  final bool admin;

  @override
  State<_OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<_OrdersScreen> {
  final _service = MatbaaService();
  late final _stream = _service.orders();
  String? _saveRoot;
  String? _selected;
  String _tab = '';
  String _query = '';

  /// Sekmeler: durum → başlık ('' tümü).
  static const _tabs = {
    '': 'Tümü',
    'ready': 'Yeni',
    'downloaded': 'İndirildi',
    'printed': 'Basıldı',
    'shipped': 'Kargoda',
  };

  @override
  void initState() {
    super.initState();
    MatbaaSettings.loadSaveRoot().then((v) => mounted ? setState(() => _saveRoot = v) : null);
  }

  Future<String?> _pickSaveRoot() async {
    final path = await getDirectoryPath(confirmButtonText: 'Bu klasöre kaydet', initialDirectory: _saveRoot);
    if (path == null) return _saveRoot;
    await MatbaaSettings.saveSaveRoot(path);
    if (mounted) setState(() => _saveRoot = path);
    return path;
  }

  bool _matches(ShopOrder o) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return true;
    final groups = [
      for (final g in o.groups) ...[g['code'], formatGroupCode('${g['code']}'), g['name'], g['studentName']],
    ];
    return [o.ref, o.customerName, o.customer['email'] ?? '', ...groups].any((s) => '$s'.toLowerCase().contains(q));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Siparişler'),
        actions: [
          TextButton.icon(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const _GroupsScreen())),
            icon: const Icon(Icons.groups_outlined),
            label: const Text('Gruplar'),
          ),
          const SizedBox(width: 8),
          TextButton.icon(
            onPressed: _pickSaveRoot,
            icon: const Icon(Icons.folder_outlined),
            label: Text(_saveRoot ?? 'Kayıt klasörü seç'),
          ),
          const SizedBox(width: 8),
          TextButton(onPressed: FirebaseAuth.instance.signOut, child: const Text('Çıkış')),
          const SizedBox(width: 12),
        ],
      ),
      body: StreamBuilder<List<ShopOrder>>(
        stream: _stream,
        builder: (context, snap) {
          if (snap.hasError) return Center(child: Text('${snap.error}'));
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final all = snap.data!;
          final orders = all.where((o) => (_tab.isEmpty || o.status == _tab) && _matches(o)).toList();
          final selected = all.where((o) => o.ref == _selected).firstOrNull;
          return Row(
            children: [
              SizedBox(
                width: 400,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final t in _tabs.entries)
                            ChoiceChip(
                              label: Text(
                                '${t.value} ${t.key.isEmpty ? all.length : all.where((o) => o.status == t.key).length}',
                              ),
                              selected: _tab == t.key,
                              onSelected: (_) => setState(() => _tab = t.key),
                            ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: TextField(
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.search),
                          hintText: 'Sipariş no, isim, e-posta ya da grup kodu',
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (v) => setState(() => _query = v),
                      ),
                    ),
                    Expanded(
                      child: orders.isEmpty
                          ? Center(
                              child: Text('Sipariş yok.', style: TextStyle(color: context.mutedText)),
                            )
                          : ListView.builder(
                              itemCount: orders.length,
                              itemBuilder: (_, i) {
                                final o = orders[i];
                                return ListTile(
                                  selected: o.ref == _selected,
                                  title: Text(o.customerName.isEmpty ? o.ref : o.customerName),
                                  subtitle: Text(
                                    '${DateFormat('d MMM y HH:mm', 'tr').format(o.createdAt)} · ${o.ref}\n'
                                    '${o.products.map((p) => '${p['adet']}× ${p['ad']}${o.groupOf(p) == null ? '' : ' (Okul Yıllığı)'}').join(', ')}',
                                  ),
                                  isThreeLine: true,
                                  trailing: _StatusChip(o.status),
                                  onTap: () => setState(() => _selected = o.ref),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
              VerticalDivider(width: 1, color: context.divider),
              Expanded(
                child: selected == null
                    ? Center(
                        child: Text('Soldan bir sipariş seç.', style: TextStyle(color: context.mutedText)),
                      )
                    : _OrderDetail(
                        key: ValueKey(selected.ref),
                        order: selected,
                        service: _service,
                        catalog: widget.catalog,
                        admin: widget.admin,
                        savedRoot: _saveRoot,
                        saveRoot: () async => _saveRoot ?? await _pickSaveRoot(),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip(this.status);

  final String status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      'ready' => ('Yeni', AppColors.accent),
      'downloaded' => ('İndirildi', AppColors.warning),
      'printed' => ('Basıldı', AppColors.success),
      'shipped' => ('Kargoda', AppColors.purple),
      _ => (status, Colors.grey),
    };
    return Chip(
      label: Text(label, style: const TextStyle(color: Colors.white)),
      backgroundColor: color,
    );
  }
}

class _OrderDetail extends StatefulWidget {
  const _OrderDetail({
    super.key,
    required this.order,
    required this.service,
    required this.catalog,
    required this.admin,
    required this.savedRoot,
    required this.saveRoot,
  });

  final ShopOrder order;
  final MatbaaService service;
  final Catalog catalog;
  final bool admin;

  /// Seçili kayıt klasörü (sormadan; yerel klasörü bulmak için).
  final String? savedRoot;
  final Future<String?> Function() saveRoot;

  @override
  State<_OrderDetail> createState() => _OrderDetailState();
}

class _OrderDetailState extends State<_OrderDetail> {
  String? _progress;
  Directory? _dir;
  bool _complete = false;
  bool _busy = false;
  List<String> _lowRes = const [];

  ShopOrder get o => widget.order;

  Directory? get _pdfDir {
    final d = _dir == null ? null : Directory('${_dir!.path}/baski');
    return d != null && d.existsSync() ? d : null;
  }

  File? get _workOrder {
    final f = _pdfDir == null ? null : File('${_pdfDir!.path}/is-emri.pdf');
    return f != null && f.existsSync() ? f : null;
  }

  Future<void> _run(Future<void> Function() job) async {
    setState(() => _busy = true);
    try {
      await job();
    } catch (e) {
      if (mounted) setState(() => _progress = 'Hata: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _findLocal();
  }

  Future<void> _findLocal() async {
    final root = widget.savedRoot;
    if (root == null) return;
    final d = await widget.service.localFolder(o, Directory(root));
    final complete = d != null && await widget.service.isLocalComplete(o, d);
    if (!mounted) return;
    setState(() {
      _dir = d;
      _complete = complete;
    });
  }

  /// Dosyalar diskte tamsa internete çıkmadan üretir; değilse yalnız eksik dosyaları indirir.
  Future<void> _produce() => _run(() async {
    var dir = _dir;
    if (dir == null || !await widget.service.isLocalComplete(o, dir)) {
      final root = await widget.saveRoot();
      if (root == null) return;
      setState(() => _progress = 'İndiriliyor…');
      dir = await widget.service.download(
        o,
        Directory(root),
        onFile: (d, t, skip) => setState(() => _progress = 'İndiriliyor: $d / $t dosya ($skip zaten vardı)'),
      );
      setState(() {
        _dir = dir;
        _complete = true;
      });
    } else {
      setState(() => _progress = 'Dosyalar diskte, indirme yok.');
    }
    if (!mounted) return;
    final r = await widget.service.render(
      context,
      widget.catalog,
      o,
      dir,
      onStep: (s) => setState(() => _progress = 'Üretiliyor: $s'),
    );
    if (o.status == 'ready' && r.files.isNotEmpty) await widget.service.setStatus(o, 'downloaded');
    setState(() {
      _lowRes = r.lowRes;
      _progress = [
        '${r.files.length} dosya hazır: ${dir!.path}/baski',
        ...r.lines,
        if (r.errors.isNotEmpty) ...['', 'Hatalar:', ...r.errors],
      ].join('\n');
    });
  });

  Future<void> _ship() async {
    final controller = TextEditingController(text: o.trackingNo);
    final no = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Kargoya Ver'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Kargo takip numarası'),
          onSubmitted: (v) => Navigator.pop(c, v),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Vazgeç')),
          FilledButton(onPressed: () => Navigator.pop(c, controller.text), child: const Text('Kaydet')),
        ],
      ),
    );
    controller.dispose();
    if (no != null) await _run(() => widget.service.ship(o, no.trim()));
  }

  Future<void> _deleteFromCloud() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Buluttan silinsin mi?'),
        content: const Text('Bu siparişin buluttaki tüm dosyaları kalıcı olarak silinir. Yerel klasör kalır.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Vazgeç')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Sil')),
        ],
      ),
    );
    if (ok == true) await _run(() => widget.service.deleteFromCloud(o));
  }

  void _copyAddress() {
    Clipboard.setData(ClipboardData(text: o.addressLines.join('\n')));
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Adres kopyalandı.')));
  }

  @override
  Widget build(BuildContext context) {
    final c = o.customer;
    final muted = TextStyle(color: context.mutedText);
    const heading = TextStyle(fontWeight: FontWeight.w600);
    final blocked = o.filesDeleted && !_complete;
    Widget open(IconData icon, String tip, FileSystemEntity? target) => IconButton(
      tooltip: tip,
      icon: Icon(icon),
      onPressed: target == null ? null : () => Process.run('open', [target.path]),
    );
    return ListView(
      padding: const EdgeInsets.all(28),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(o.ref, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w600)),
            ),
            open(Icons.folder_open, 'Sipariş klasörü', _dir),
            open(Icons.picture_as_pdf_outlined, 'Baskı dosyaları', _pdfDir),
            open(Icons.assignment_outlined, 'İş emri', _workOrder),
            IconButton(tooltip: 'Adresi kopyala', icon: const Icon(Icons.content_copy), onPressed: _copyAddress),
            const SizedBox(width: 8),
            _StatusChip(o.status),
          ],
        ),
        Text(DateFormat('d MMMM y, EEEE HH:mm', 'tr').format(o.createdAt), style: muted),
        const SizedBox(height: 20),
        const Text('Müşteri', style: heading),
        Text(o.customerName),
        Text([c['email'], c['phone']].where((s) => s != null && '$s'.isNotEmpty).join(' · '), style: muted),
        const SizedBox(height: 16),
        const Text('Teslimat', style: heading),
        Text(o.addressLines.join('\n'), style: muted),
        const SizedBox(height: 16),
        const Text('Ürünler', style: heading),
        for (final p in o.products)
          Builder(
            builder: (context) {
              final r = WorkOrder.row(p, widget.catalog);
              final g = o.groupOf(p);
              if (g == null) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text('${r[4]}× ${r[0]} · ${r[1]} · ${r[2]} · ${r[3]}'),
                );
              }
              final line = '${r[4]}× ${r[0]} · Fotokitap · ${r[2]} · ${r[3]}';
              // Okul yıllığı ürünü: aynı siparişteki normal kitaptan ayırt edilsin.
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(color: Colors.deepOrange, borderRadius: BorderRadius.circular(6)),
                          child: const Text(
                            'OKUL YILLIĞI',
                            style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(line, style: const TextStyle(fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                    SelectableText(ShopOrder.groupLabel(g), style: muted),
                    Text('Baskı klasörü: baski/${r[0]}${ShopOrder.groupSuffix(g)}/', style: muted),
                  ],
                ),
              );
            },
          ),
        const SizedBox(height: 28),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _busy || blocked ? null : _produce,
            icon: const Icon(Icons.print),
            label: const Text('Baskı Dosyalarını Üret'),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          blocked
              ? 'Bulut dosyaları silinmiş ve yerel klasör eksik.'
              : _complete
              ? 'Dosyalar diskte; indirme yapılmaz.'
              : 'Eksik dosyalar indirilir, diskte olanlar atlanır.',
          style: muted,
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (o.status == 'downloaded')
              OutlinedButton(
                onPressed: _busy ? null : () => _run(() => widget.service.setStatus(o, 'printed')),
                child: const Text('Basıldı Olarak İşaretle'),
              ),
            if (o.status == 'printed')
              FilledButton.tonalIcon(
                onPressed: _busy ? null : _ship,
                icon: const Icon(Icons.local_shipping_outlined),
                label: const Text('Kargoya Ver'),
              ),
            if (o.status == 'shipped')
              Text(
                'Kargoda · takip no ${o.trackingNo.isEmpty ? '-' : o.trackingNo}'
                '${o.shippedAt == null ? '' : ' · ${DateFormat('d MMM y HH:mm', 'tr').format(o.shippedAt!)}'}',
              ),
            if (o.status == 'shipped')
              TextButton(onPressed: _busy ? null : _ship, child: const Text('Takip No Değiştir')),
            if (widget.admin && o.status != 'ready' && !o.filesDeleted)
              TextButton(
                onPressed: _busy ? null : _deleteFromCloud,
                style: TextButton.styleFrom(foregroundColor: AppColors.failure),
                child: const Text('Buluttan Sil'),
              ),
            if (o.filesDeleted) Text('Bulut dosyaları silindi.', style: muted),
          ],
        ),
        if (_lowRes.isNotEmpty) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.15),
              border: Border.all(color: AppColors.warning),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              [
                'Düşük çözünürlük (${PrintRenderer.lowResDpi} DPI altı), baskıda yumuşak görünebilir:',
                ..._lowRes,
              ].join('\n'),
            ),
          ),
        ],
        if (_progress != null) ...[const SizedBox(height: 16), SelectableText(_progress!, style: muted)],
      ],
    );
  }
}

/// Okul yıllığı sınıf grupları: matbaa grubu oluşturur, üretilen kodu öğrencilerle paylaşır.
class _GroupsScreen extends StatelessWidget {
  const _GroupsScreen();

  // Tema dolu düğmeyi tam genişlik yapar (Size.fromHeight); AppBar'da sınırsız genişlik düzeni bozuyordu.
  static final _compact = FilledButton.styleFrom(minimumSize: const Size(0, 44));

  static void _copy(BuildContext context, MatbaaGroup g) {
    Clipboard.setData(ClipboardData(text: g.display));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${g.display} kopyalandı')));
  }

  Future<void> _create(BuildContext context) async {
    final name = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Yeni Grup'),
        content: SizedBox(
          width: 420,
          child: TextField(
            controller: name,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Grup adı', hintText: 'Örn. 2026 Atatürk Lisesi 10-A'),
            onSubmitted: (_) => Navigator.pop(c, true),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Vazgeç')),
          FilledButton(style: _compact, onPressed: () => Navigator.pop(c, true), child: const Text('Oluştur')),
        ],
      ),
    );
    if (ok != true || name.text.trim().isEmpty || !context.mounted) return;
    try {
      final g = await MatbaaService().createGroup(name.text);
      if (!context.mounted) return;
      await showDialog<void>(
        context: context,
        builder: (c) => AlertDialog(
          title: Text(g.name),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Grup kodu'),
              const SizedBox(height: 8),
              SelectableText(
                g.display,
                style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w700, letterSpacing: 4),
              ),
              const SizedBox(height: 8),
              Text('Öğrenciler uygulamada bu kodla gruba girer.', style: TextStyle(color: c.mutedText)),
            ],
          ),
          actions: [
            TextButton.icon(onPressed: () => _copy(c, g), icon: const Icon(Icons.copy), label: const Text('Kopyala')),
            FilledButton(style: _compact, onPressed: () => Navigator.pop(c), child: const Text('Tamam')),
          ],
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Grup oluşturulamadı: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final date = DateFormat('d MMM yyyy HH:mm', 'tr');
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gruplar'),
        actions: [
          FilledButton.icon(
            style: _compact,
            onPressed: () => _create(context),
            icon: const Icon(Icons.add),
            label: const Text('Yeni Grup'),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: StreamBuilder<List<MatbaaGroup>>(
        stream: MatbaaService().groups(),
        builder: (context, snap) {
          if (snap.hasError) return Center(child: Text('${snap.error}'));
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final groups = snap.data!;
          if (groups.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Henüz grup yok', style: TextStyle(fontSize: 18, color: context.mutedText)),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    style: _compact,
                    onPressed: () => _create(context),
                    icon: const Icon(Icons.add),
                    label: const Text('Yeni Grup'),
                  ),
                ],
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: groups.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final g = groups[i];
              return ListTile(
                leading: const Icon(Icons.groups_outlined),
                title: Text(g.name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                subtitle: Text(
                  [date.format(g.createdAt), if (g.createdByEmail.isNotEmpty) g.createdByEmail].join(' · '),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SelectableText(
                      g.display,
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: 2),
                    ),
                    IconButton(tooltip: 'Kopyala', onPressed: () => _copy(context, g), icon: const Icon(Icons.copy)),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
