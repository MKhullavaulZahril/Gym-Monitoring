import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'api.dart';
import 'widgets.dart';

/// Menu Akun (Super Admin): tambah akun, buat password baru, atur role, aktif/nonaktif.
/// Ketuk salah satu akun untuk membuka menu aksinya.
class StaffPage extends StatefulWidget {
  const StaffPage({super.key});
  @override
  State<StaffPage> createState() => _StaffPageState();
}

class _StaffPageState extends State<StaffPage> {
  late Future<List<Map<String, dynamic>>> f = Api.staff();
  void reload() {
    setState(() {
      f = Api.staff();
    });
  }

  InputDecoration _pwDeco(TextEditingController c, String label, {String? helper}) => InputDecoration(
      labelText: label,
      helperText: helper,
      suffixIcon: IconButton(
          tooltip: 'Buat password acak',
          icon: const Icon(Icons.casino),
          onPressed: () => c.text = genPassword()));

  Future<void> tambah() async {
    final nama = TextEditingController();
    final email = TextEditingController();
    final pass = TextEditingController(text: genPassword());
    String role = 'admin';
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, set) => AlertDialog(
          title: const Text('Tambah akun'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: nama, decoration: const InputDecoration(labelText: 'Nama')),
              TextField(
                  controller: email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Email')),
              TextField(
                  controller: pass,
                  decoration: _pwDeco(pass, 'Password (min. 6 karakter)',
                      helper: 'Diabaikan jika email sudah punya akun')),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                key: ValueKey(role),
                initialValue: role,
                decoration: const InputDecoration(labelText: 'Role'),
                items: const [
                  DropdownMenuItem(value: 'admin', child: Text('Admin')),
                  DropdownMenuItem(value: 'super_admin', child: Text('Super Admin')),
                ],
                onChanged: (v) => set(() => role = v!),
              ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Simpan')),
          ],
        ),
      ),
    );
    if (ok != true || !mounted) return;
    final em = email.text.trim().toLowerCase();
    final nm = nama.text.trim();
    if (nm.isEmpty || !em.contains('@') || pass.text.length < 6) {
      await tampilError(context, 'Data belum lengkap',
          'Isi nama, email yang benar, dan password minimal 6 karakter.');
      return;
    }
    try {
      final baru = await Api.createStaff(email: em, password: pass.text, nama: nm, role: role);
      reload();
      if (!mounted) return;
      if (baru) {
        await tampilKredensial(context, nm, em, pass.text);
      } else {
        toast(context, 'Email sudah punya akun: nama dan role diatur. Password lama tetap berlaku.');
      }
    } catch (e) {
      if (mounted) await tampilError(context, 'Gagal menambah akun', errMsg(e));
    }
  }

  Future<void> resetPw(Map<String, dynamic> r) async {
    final pass = TextEditingController(text: genPassword());
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Password baru: ${r['nama']}'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('${r['email'] ?? '-'}'),
          const SizedBox(height: 8),
          TextField(
              controller: pass,
              decoration: _pwDeco(pass, 'Password baru (min. 6 karakter)',
                  helper: 'Akun ini otomatis keluar dari semua perangkat')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Ganti')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    if (pass.text.length < 6) {
      await tampilError(context, 'Password terlalu pendek', 'Password minimal 6 karakter.');
      return;
    }
    try {
      await Api.resetPassword(r['id'], pass.text);
      if (mounted) {
        await tampilKredensial(context, '${r['nama']}', '${r['email'] ?? '-'}', pass.text);
      }
    } catch (e) {
      if (mounted) await tampilError(context, 'Gagal mengganti password', errMsg(e));
    }
  }

  Future<void> ubahNama(Map<String, dynamic> r) async {
    final c = TextEditingController(text: '${r['nama'] ?? ''}');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ubah nama'),
        content: TextField(controller: c, decoration: const InputDecoration(labelText: 'Nama')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Simpan')),
        ],
      ),
    );
    if (ok != true || !mounted || c.text.trim().isEmpty) return;
    await _update(r, {'nama': c.text.trim()});
  }

  Future<void> _update(Map<String, dynamic> r, Map<String, dynamic> data) async {
    try {
      await Api.updateStaff(r['id'], data);
      if (mounted) toast(context, 'Diperbarui');
    } catch (e) {
      if (mounted) await tampilError(context, 'Gagal memperbarui', errMsg(e));
    }
    reload();
  }

  /// Menu aksi untuk satu akun (muncul saat kartu akun diketuk).
  Future<void> detail(Map<String, dynamic> r) async {
    final me = r['id'] == Api.uid;
    final aktif = r['aktif'] != false;
    final isSuper = r['role'] == 'super_admin';
    final aksi = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            ListTile(
              title: Text('${r['nama'] ?? '-'}', style: Theme.of(ctx).textTheme.titleMedium),
              subtitle: Text('${r['email'] ?? '-'}\n'
                  '${isSuper ? 'Super Admin' : 'Admin'}${aktif ? '' : ' • NONAKTIF'}'),
              isThreeLine: true,
            ),
            const Divider(height: 1),
            ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('Ubah nama'),
                onTap: () => Navigator.pop(ctx, 'nama')),
            if (me)
              ListTile(
                  leading: const Icon(Icons.key),
                  title: const Text('Ganti password saya'),
                  onTap: () => Navigator.pop(ctx, 'pwme'))
            else ...[
              ListTile(
                  leading: const Icon(Icons.key),
                  title: const Text('Buat password baru'),
                  onTap: () => Navigator.pop(ctx, 'reset')),
              ListTile(
                  leading: Icon(isSuper ? Icons.person : Icons.shield),
                  title: Text(isSuper ? 'Jadikan Admin' : 'Jadikan Super Admin'),
                  onTap: () => Navigator.pop(ctx, isSuper ? 'admin' : 'super')),
              ListTile(
                  leading: Icon(aktif ? Icons.block : Icons.check_circle),
                  title: Text(aktif ? 'Nonaktifkan akun' : 'Aktifkan akun'),
                  onTap: () => Navigator.pop(ctx, aktif ? 'off' : 'on')),
            ],
          ]),
        ),
      ),
    );
    if (aksi == null || !mounted) return;
    switch (aksi) {
      case 'nama':
        await ubahNama(r);
      case 'pwme':
        await gantiPassword(context);
      case 'reset':
        await resetPw(r);
      case 'super':
        await _update(r, {'role': 'super_admin'});
      case 'admin':
        await _update(r, {'role': 'admin'});
      case 'off':
        await _update(r, {'aktif': false});
      case 'on':
        await _update(r, {'aktif': true});
    }
  }

  Future<void> salinEmail(List<Map<String, dynamic>> rows) async {
    final t = rows
        .map((r) => '${r['role'] == 'super_admin' ? 'Super Admin' : 'Admin'}: ${r['nama']} <${r['email'] ?? '-'}>')
        .join('\n');
    await Clipboard.setData(ClipboardData(text: t));
    if (mounted) toast(context, 'Daftar email disalin (tanpa password)');
  }

  @override
  Widget build(BuildContext context) => Column(children: [
        Row(children: [
          Expanded(child: Text('Akun & Role', style: Theme.of(context).textTheme.titleLarge)),
          FilledButton.icon(
              onPressed: tambah, icon: const Icon(Icons.person_add), label: const Text('Tambah')),
          IconButton(icon: const Icon(Icons.refresh), onPressed: reload),
        ]),
        const SizedBox(height: 4),
        const Align(
            alignment: Alignment.centerLeft,
            child: Text('Ketuk akun untuk membuka menu (password baru, role, nonaktifkan).',
                style: TextStyle(fontSize: 12))),
        const SizedBox(height: 8),
        Expanded(
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: f,
            builder: (c, s) {
              if (s.hasError) return ErrorView(msg: errMsg(s.error!), onRetry: reload);
              if (!s.hasData) return const Center(child: CircularProgressIndicator());
              return ListView(children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                      onPressed: () => salinEmail(s.data!),
                      icon: const Icon(Icons.copy, size: 18),
                      label: const Text('Salin daftar email')),
                ),
                ...s.data!.map((r) {
                  final me = r['id'] == Api.uid;
                  final aktif = r['aktif'] != false;
                  final isSuper = r['role'] == 'super_admin';
                  return Card(
                    child: ListTile(
                      onTap: () => detail(r),
                      leading: CircleAvatar(child: Icon(isSuper ? Icons.shield : Icons.person)),
                      title: Text(r['nama'] ?? '-'),
                      subtitle: Text('${r['email'] ?? '-'}\n'
                          '${isSuper ? 'Super Admin' : 'Admin'}${aktif ? '' : ' • NONAKTIF'}'),
                      isThreeLine: true,
                      trailing: me ? const Chip(label: Text('Anda')) : const Icon(Icons.chevron_right),
                    ),
                  );
                }),
              ]);
            },
          ),
        ),
      ]);
}
