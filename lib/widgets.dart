import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'api.dart';

/// Input untuk scanner USB (HID/keyboard). Scanner mengirim kode + Enter.
class ScanField extends StatefulWidget {
  final ValueChanged<String> onScan;
  final String label;
  const ScanField({super.key, required this.onScan, this.label = 'Scan kartu member'});
  @override
  State<ScanField> createState() => _ScanFieldState();
}

class _ScanFieldState extends State<ScanField> {
  final c = TextEditingController();
  final f = FocusNode();
  bool manual = false; // true = keyboard layar muncul untuk ketik manual

  @override
  void dispose() {
    c.dispose();
    f.dispose();
    super.dispose();
  }

  void submit(String v) {
    final t = v.trim();
    c.clear();
    f.requestFocus();
    if (t.isNotEmpty) widget.onScan(t);
  }

  void toggleManual() {
    setState(() => manual = !manual);
    f.requestFocus();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      SystemChannels.textInput.invokeMethod(manual ? 'TextInput.show' : 'TextInput.hide');
    });
  }

  @override
  Widget build(BuildContext context) => TextField(
        controller: c,
        focusNode: f,
        autofocus: true,
        keyboardType: manual ? TextInputType.text : TextInputType.none,
        onSubmitted: submit,
        decoration: InputDecoration(
          labelText: widget.label,
          helperText: 'Scan bisa dari menu mana saja. Kolom ini untuk cari / ketik manual.',
          prefixIcon: const Icon(Icons.qr_code_scanner),
          border: const OutlineInputBorder(),
          suffixIcon: IconButton(
            tooltip: 'Ketik manual',
            icon: Icon(manual ? Icons.keyboard_hide : Icons.keyboard),
            onPressed: toggleManual,
          ),
        ),
      );
}

class PayDropdown extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;
  const PayDropdown({super.key, required this.value, required this.onChanged});
  @override
  Widget build(BuildContext context) => DropdownButtonFormField<String>(
        key: ValueKey(value),
        initialValue: value,
        decoration: const InputDecoration(
            labelText: 'Tipe pembayaran', border: OutlineInputBorder()),
        items: tipeBayar.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
        onChanged: (v) => onChanged(v!),
      );
}

class ErrorView extends StatelessWidget {
  final String msg;
  final VoidCallback onRetry;
  const ErrorView({super.key, required this.msg, required this.onRetry});
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.cloud_off, size: 48),
            const SizedBox(height: 8),
            Text(msg, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton.icon(
                onPressed: onRetry, icon: const Icon(Icons.refresh), label: const Text('Coba lagi')),
          ]),
        ),
      );
}

Future<bool> konfirmasi(BuildContext c, String judul, String isi, {String ya = 'Ya'}) async =>
    (await showDialog<bool>(
      context: c,
      builder: (ctx) => AlertDialog(
        title: Text(judul),
        content: Text(isi),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(ya)),
        ],
      ),
    )) ??
    false;

/// Menu akun di AppBar: ganti password & keluar.
class AccountMenu extends StatelessWidget {
  const AccountMenu({super.key});
  @override
  Widget build(BuildContext context) => PopupMenuButton<String>(
        icon: const Icon(Icons.account_circle),
        onSelected: (v) {
          if (v == 'pw') {
            gantiPassword(context);
          } else {
            db.auth.signOut();
          }
        },
        itemBuilder: (_) => const [
          PopupMenuItem(value: 'pw', child: Text('Ganti password')),
          PopupMenuItem(value: 'out', child: Text('Keluar')),
        ],
      );
}

Future<void> gantiPassword(BuildContext context) async {
  final c = TextEditingController();
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Ganti password'),
      content: TextField(
          controller: c,
          obscureText: true,
          decoration: const InputDecoration(labelText: 'Password baru (min. 6 karakter)')),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Simpan')),
      ],
    ),
  );
  if (ok != true || !context.mounted) return;
  if (c.text.length < 6) {
    toast(context, 'Password minimal 6 karakter');
    return;
  }
  try {
    await db.auth.updateUser(UserAttributes(password: c.text));
    if (context.mounted) toast(context, 'Password diganti');
  } catch (e) {
    if (context.mounted) toast(context, 'Gagal: ${errMsg(e)}');
  }
}

/// Menampilkan email + password sekali, dengan tombol salin.
/// Password disimpan ter-hash di server sehingga tidak bisa dilihat lagi nanti.
Future<void> tampilKredensial(BuildContext context, String nama, String email, String password) {
  final teks = 'Akun Gym Monitor\nNama: $nama\nEmail: $email\nPassword: $password';
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Data login'),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        SelectableText(teks),
        const SizedBox(height: 12),
        const Text('Salin dan berikan ke yang bersangkutan sekarang. Password tidak bisa dilihat lagi setelah dialog ini ditutup; kalau lupa, buat password baru lewat menu Akun.',
            style: TextStyle(fontSize: 12)),
      ]),
      actions: [
        TextButton(
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: teks));
            if (ctx.mounted) toast(ctx, 'Disalin');
          },
          child: const Text('Salin'),
        ),
        FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('Tutup')),
      ],
    ),
  );
}

/// Pesan error yang tidak hilang sendiri (lebih mudah dibaca dan disalin).
Future<void> tampilError(BuildContext c, String judul, String pesan) => showDialog<void>(
      context: c,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.error_outline, color: Colors.red),
        title: Text(judul),
        content: SelectableText(pesan),
        actions: [FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
      ),
    );

/// Mendengarkan scanner USB (HID/keyboard) di seluruh layar.
/// Deretan karakter yang masuk sangat cepat lalu diakhiri Enter dianggap hasil scan,
/// sehingga kartu bisa di-scan tanpa membuka menu tertentu atau menyorot kolom apa pun.
/// Pengetikan biasa tidak terpengaruh: jika sebuah kolom teks sedang aktif, scan
/// dibiarkan masuk ke kolom itu.
class ScanListener extends StatefulWidget {
  final Widget child;
  final ValueChanged<String> onScan;
  const ScanListener({super.key, required this.child, required this.onScan});
  @override
  State<ScanListener> createState() => _ScanListenerState();
}

class _ScanListenerState extends State<ScanListener> {
  final _buf = StringBuffer();
  Duration? _last;
  Timer? _idle;
  static const _gap = Duration(milliseconds: 60); // jeda antar karakter scanner < 60 ms
  static const _minLen = 3;

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_onKey);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    _idle?.cancel();
    super.dispose();
  }

  void _reset() {
    _buf.clear();
    _last = null;
    _idle?.cancel();
  }

  bool _editing() {
    final ctx = FocusManager.instance.primaryFocus?.context;
    if (ctx == null) return false;
    return ctx.widget is EditableText || ctx.findAncestorWidgetOfExactType<EditableText>() != null;
  }

  void _fire(String code) {
    if (mounted) widget.onScan(code);
  }

  bool _onKey(KeyEvent e) {
    if (e is! KeyDownEvent || !mounted) return false;
    // Abaikan jika ada dialog di atas, atau sedang mengetik di kolom teks.
    if (ModalRoute.of(context)?.isCurrent != true || _editing()) {
      _reset();
      return false;
    }
    final ts = e.timeStamp;
    if (_last != null && ts - _last! > _gap) _buf.clear();
    _last = ts;

    if (e.logicalKey == LogicalKeyboardKey.enter || e.logicalKey == LogicalKeyboardKey.numpadEnter) {
      final code = _buf.toString().trim();
      _reset();
      if (code.length >= _minLen) {
        _fire(code);
        return true; // Enter dari scanner tidak boleh menekan tombol yang sedang fokus
      }
      return false;
    }

    final ch = e.character;
    if (ch == null || ch.length != 1 || ch.codeUnitAt(0) < 32) return false;
    final lanjut = _buf.isNotEmpty; // karakter ke-2 dst. dalam satu rentetan
    _buf.write(ch);
    // Cadangan untuk scanner yang tidak mengirim Enter.
    _idle?.cancel();
    _idle = Timer(const Duration(milliseconds: 150), () {
      final code = _buf.toString().trim();
      _reset();
      if (code.length >= _minLen + 1) _fire(code);
    });
    return lanjut;
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Pilihan kategori harga: Umum / Pelajar.
class KategoriSelector extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;
  const KategoriSelector({super.key, required this.value, required this.onChanged});
  @override
  Widget build(BuildContext context) => SegmentedButton<String>(
        segments: const [
          ButtonSegment(value: 'umum', label: Text('Umum'), icon: Icon(Icons.person)),
          ButtonSegment(value: 'pelajar', label: Text('Pelajar'), icon: Icon(Icons.school)),
        ],
        selected: {value},
        onSelectionChanged: (s) => onChanged(s.first),
      );
}
