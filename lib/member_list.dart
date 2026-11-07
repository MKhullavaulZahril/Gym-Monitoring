import 'dart:async';
import 'package:flutter/material.dart';
import 'api.dart';
import 'widgets.dart';

/// Daftar member (Super Admin): cari, filter, lihat detail, hapus member yang melanggar
/// peraturan gym (disertai alasan) dan pulihkan bila perlu.
class MemberPage extends StatefulWidget {
  const MemberPage({super.key});
  @override
  State<MemberPage> createState() => _MemberPageState();
}

class _MemberPageState extends State<MemberPage> {
  static const _batch = 50;
  final cari = TextEditingController();
  Timer? _deb;
  String status = 'semua'; // semua | aktif | habis | belum
  String kategori = ''; // '' | umum | pelajar
  bool dihapus = false;
  final List<Map<String, dynamic>> data = [];
  int total = 0;
  bool loading = false;
  String? err;
  int _seq = 0;

  @override
  void initState() {
    super.initState();
    muat(reset: true);
  }

  @override
  void dispose() {
    _deb?.cancel();
    cari.dispose();
    super.dispose();
  }

  Future<void> muat({bool reset = false}) async {
    final saya = ++_seq;
    setState(() {
      loading = true;
      err = null;
      if (reset) {
        data.clear();
        total = 0;
      }
    });
    try {
      final r = await Api.listMember(
        q: cari.text,
        status: status,
        kategori: kategori,
        dihapus: dihapus,
        limit: _batch,
        offset: reset ? 0 : data.length,
      );
      if (!mounted || saya != _seq) return;
      setState(() {
        data.addAll(r);
        if (r.isNotEmpty) total = (r.first['total_baris'] as num).toInt();
        loading = false;
      });
    } catch (e) {
      if (mounted && saya == _seq) {
        setState(() {
          loading = false;
          err = errMsg(e);
        });
      }
    }
  }

  Widget _chip(String label, bool pilih, VoidCallback onTap) => ChoiceChip(
        label: Text(label),
        selected: pilih,
        onSelected: (_) => onTap(),
      );

  String _statusText(Map<String, dynamic> m) {
    if (m['dihapus_at'] != null) return 'DIHAPUS';
    final s = m['sisa_hari'] as int?;
    if (s == null) return 'belum ada membership';
    return s <= 0 ? 'habis' : 'sisa $s hari';
  }

  Color _statusWarna(Map<String, dynamic> m) {
    if (m['dihapus_at'] != null) return Colors.grey;
    final s = m['sisa_hari'] as int?;
    if (s == null || s <= 0) return Colors.red;
    return s <= 7 ? Colors.orange : Colors.green;
  }

  Future<void> detail(Map<String, dynamic> m) async {
    final aksi = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => _DetailMember(m),
    );
    if (aksi == null || !mounted) return;
    if (aksi == 'hapus') {
      await hapus(m);
    } else if (aksi == 'pulih') {
      await pulihkan(m);
    }
  }

  Future<void> hapus(Map<String, dynamic> m) async {
    final alasan = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, set) => AlertDialog(
          icon: const Icon(Icons.gavel, color: Colors.red),
          title: const Text('Hapus member?'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${m['nama']} • ${m['no_member']}', style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text(
                  'Member hilang dari daftar dan kartunya tidak bisa dipakai lagi. '
                  'Riwayat pembayaran tetap tercatat di laporan. '
                  'Bisa dipulihkan lewat filter "Dihapus".',
                  style: TextStyle(fontSize: 12)),
              const SizedBox(height: 12),
              TextField(
                controller: alasan,
                maxLines: 2,
                onChanged: (_) => set(() {}),
                decoration: const InputDecoration(
                    labelText: 'Alasan (pelanggaran peraturan)', border: OutlineInputBorder()),
              ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.error),
              onPressed: alasan.text.trim().length >= 5 ? () => Navigator.pop(ctx, true) : null,
              child: const Text('Hapus'),
            ),
          ],
        ),
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await Api.hapusMember(m['id'], alasan.text.trim());
      if (mounted) toast(context, 'Member dihapus');
    } catch (e) {
      if (mounted) await tampilError(context, 'Gagal menghapus member', errMsg(e));
    }
    await muat(reset: true);
  }

  Future<void> pulihkan(Map<String, dynamic> m) async {
    final ok = await konfirmasi(
        context, 'Pulihkan member?', '${m['nama']} • ${m['no_member']} akan aktif kembali di daftar.',
        ya: 'Pulihkan');
    if (!ok || !mounted) return;
    try {
      await Api.pulihkanMember(m['id']);
      if (mounted) toast(context, 'Member dipulihkan');
    } catch (e) {
      if (mounted) await tampilError(context, 'Gagal memulihkan member', errMsg(e));
    }
    await muat(reset: true);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Column(children: [
      Row(children: [
        Expanded(child: Text('Daftar member', style: t.titleLarge)),
        IconButton(icon: const Icon(Icons.refresh), onPressed: () => muat(reset: true)),
      ]),
      TextField(
        controller: cari,
        onChanged: (_) {
          setState(() {});
          _deb?.cancel();
          _deb = Timer(const Duration(milliseconds: 400), () => muat(reset: true));
        },
        decoration: InputDecoration(
          labelText: 'Cari nama / no. member / no. HP',
          prefixIcon: const Icon(Icons.search),
          border: const OutlineInputBorder(),
          suffixIcon: cari.text.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    cari.clear();
                    setState(() {});
                    muat(reset: true);
                  }),
        ),
      ),
      const SizedBox(height: 8),
      Align(
        alignment: Alignment.centerLeft,
        child: Wrap(spacing: 8, runSpacing: 0, children: [
          _chip('Member', !dihapus, () {
            setState(() {
              dihapus = false;
            });
            muat(reset: true);
          }),
          _chip('Dihapus', dihapus, () {
            setState(() {
              dihapus = true;
            });
            muat(reset: true);
          }),
          const SizedBox(width: 8),
          for (final k in const [['', 'Semua kategori'], ['umum', 'Umum'], ['pelajar', 'Pelajar']])
            _chip(k[1], kategori == k[0], () {
              setState(() {
                kategori = k[0];
              });
              muat(reset: true);
            }),
        ]),
      ),
      if (!dihapus)
        Align(
          alignment: Alignment.centerLeft,
          child: Wrap(spacing: 8, runSpacing: 0, children: [
            for (final s in const [
              ['semua', 'Semua status'],
              ['aktif', 'Aktif'],
              ['habis', 'Habis'],
              ['belum', 'Belum ada membership'],
            ])
              _chip(s[1], status == s[0], () {
                setState(() {
                  status = s[0];
                });
                muat(reset: true);
              }),
          ]),
        ),
      Align(
        alignment: Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Text('$total member${dihapus ? ' dihapus' : ''}', style: t.bodySmall),
        ),
      ),
      Expanded(
        child: err != null && data.isEmpty
            ? ErrorView(msg: err!, onRetry: () => muat(reset: true))
            : data.isEmpty && loading
                ? const Center(child: CircularProgressIndicator())
                : data.isEmpty
                    ? Center(child: Text(dihapus ? 'Belum ada member yang dihapus.' : 'Tidak ada member yang cocok.'))
                    : ListView.builder(
                        itemCount: data.length + (data.length < total ? 1 : 0),
                        itemBuilder: (c, i) {
                          if (i >= data.length) {
                            return Padding(
                              padding: const EdgeInsets.all(8),
                              child: Center(
                                child: loading
                                    ? const CircularProgressIndicator()
                                    : OutlinedButton(
                                        onPressed: () => muat(),
                                        child: Text('Muat lagi (${total - data.length} lagi)')),
                              ),
                            );
                          }
                          final m = data[i];
                          return Card(
                            child: ListTile(
                              onTap: () => detail(m),
                              leading: CircleAvatar(
                                  child: Text('${m['nama']}'.isEmpty ? '?' : '${m['nama']}'[0].toUpperCase())),
                              title: Text('${m['nama']}'),
                              subtitle: Text('${m['no_member']} • ${labelKategori(m['kategori'])}'),
                              trailing: Text(_statusText(m),
                                  style: TextStyle(color: _statusWarna(m), fontWeight: FontWeight.w600)),
                            ),
                          );
                        },
                      ),
      ),
    ]);
  }
}

class _DetailMember extends StatefulWidget {
  final Map<String, dynamic> m;
  const _DetailMember(this.m);
  @override
  State<_DetailMember> createState() => _DetailMemberState();
}

class _DetailMemberState extends State<_DetailMember> {
  late final Future<List<Map<String, dynamic>>> riwayat = Api.riwayatMembership(widget.m['id']);

  @override
  Widget build(BuildContext context) {
    final m = widget.m;
    final t = Theme.of(context).textTheme;
    final dihapus = m['dihapus_at'] != null;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Text('${m['nama']}', style: t.titleLarge),
        Text('No. member: ${m['no_member']} • ${labelKategori(m['kategori'])}'),
        if (m['no_hp'] != null) Text('HP: ${m['no_hp']}'),
        if (m['alamat'] != null) Text('Alamat: ${m['alamat']}'),
        Text('Terdaftar: ${fTanggal.format(DateTime.parse(m['created_at']).toLocal())}'
            ' oleh ${m['didaftarkan_oleh'] ?? '-'}'),
        Text('Membership: ${m['jumlah_membership']}x • total ${rupiah.format(m['total_bayar'])}'),
        if (dihapus)
          Card(
            color: Theme.of(context).colorScheme.errorContainer,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text('Dihapus ${fTanggal.format(DateTime.parse(m['dihapus_at']).toLocal())}\n'
                  'Alasan: ${m['alasan_hapus'] ?? '-'}'),
            ),
          ),
        const Divider(height: 24),
        Text('Riwayat membership', style: t.titleSmall),
        FutureBuilder<List<Map<String, dynamic>>>(
          future: riwayat,
          builder: (c, s) {
            if (s.hasError) return Text('Gagal memuat: ${errMsg(s.error!)}');
            if (!s.hasData) return const Padding(padding: EdgeInsets.all(8), child: LinearProgressIndicator());
            if (s.data!.isEmpty) return const Text('Belum ada membership.');
            return Column(
              children: s.data!.map((r) {
                final mulai = DateTime.parse(r['tanggal_mulai']);
                final akhir = DateTime.parse(r['tanggal_berakhir']).subtract(const Duration(days: 1));
                return ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text('${fTanggal.format(mulai)} s/d ${fTanggal.format(akhir)}'),
                  subtitle: Text('${rupiah.format(r['harga'])} • ${r['tipe_pembayaran']} • ${labelKategori(r['kategori'])}'),
                );
              }).toList(),
            );
          },
        ),
        const SizedBox(height: 16),
        if (dihapus)
          FilledButton.icon(
            onPressed: () => Navigator.pop(context, 'pulih'),
            icon: const Icon(Icons.restore),
            label: const Text('Pulihkan member'),
          )
        else
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.pop(context, 'hapus'),
            icon: const Icon(Icons.delete_forever),
            label: const Text('Hapus member (pelanggaran)'),
          ),
      ]),
    );
  }
}
