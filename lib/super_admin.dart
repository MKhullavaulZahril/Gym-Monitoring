import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'api.dart';
import 'kartu.dart';
import 'staff.dart';
import 'widgets.dart';

class SuperHome extends StatefulWidget {
  final Profile p;
  const SuperHome(this.p, {super.key});
  @override
  State<SuperHome> createState() => _SuperHomeState();
}

class _SuperHomeState extends State<SuperHome> {
  int i = 0;
  @override
  Widget build(BuildContext context) {
    const pages = [DashboardPage(), RekapPage(), StaffPage(), KartuPage(), DataPage()];
    return Scaffold(
      appBar: AppBar(
        title: Text('Super Admin • ${widget.p.nama}'),
        actions: const [AccountMenu()],
      ),
      body: Padding(padding: const EdgeInsets.all(16), child: pages[i]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: i,
        onDestinationSelected: (v) => setState(() => i = v),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard), label: 'Dashboard'),
          NavigationDestination(icon: Icon(Icons.bar_chart), label: 'Rekap'),
          NavigationDestination(icon: Icon(Icons.manage_accounts), label: 'Akun'),
          NavigationDestination(icon: Icon(Icons.credit_card), label: 'Kartu'),
          NavigationDestination(icon: Icon(Icons.settings), label: 'Data'),
        ],
      ),
    );
  }
}

Widget _baris(String l, String v) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Flexible(child: Text(l)),
        const SizedBox(width: 12),
        Text(v, style: const TextStyle(fontWeight: FontWeight.w600)),
      ]),
    );

// ---------- Dashboard harian ----------
class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});
  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  DateTime tgl = DateTime.now();
  late Future<List<dynamic>> f;
  int? aktif;

  @override
  void initState() {
    super.initState();
    muat();
  }

  void muat() {
    f = Api.stats(tgl);
    Api.memberAktif().then((v) {
      if (mounted) setState(() => aktif = v);
    }).catchError((_) {});
  }

  Future<void> pilih() async {
    final d = await showDatePicker(
        context: context, initialDate: tgl, firstDate: DateTime(2020), lastDate: DateTime.now());
    if (d != null) setState(() {
      tgl = d;
      muat();
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Column(children: [
      Row(children: [
        Expanded(child: Text(fTanggal.format(tgl), style: t.titleLarge)),
        IconButton(icon: const Icon(Icons.calendar_month), onPressed: pilih),
        IconButton(icon: const Icon(Icons.refresh), onPressed: () => setState(muat)),
      ]),
      Expanded(
        child: FutureBuilder<List<dynamic>>(
          future: f,
          builder: (c, s) {
            if (s.hasError) return ErrorView(msg: errMsg(s.error!), onRetry: () => setState(muat));
            if (!s.hasData) return const Center(child: CircularProgressIndicator());
            final rows = s.data!
                .where((r) =>
                    r['role'] == 'admin' ||
                    ((r['pelanggan'] as num) +
                            (r['pendapatan'] as num) +
                            (r['member_baru'] as num) +
                            (r['pendapatan_member'] as num)) >
                        0)
                .toList();
            num sum(String k) => rows.fold<num>(0, (a, r) => a + (r[k] as num));
            final bln = fBulan.format(tgl);
            return RefreshIndicator(
              onRefresh: () async {
                setState(muat);
                try {
                  await f;
                } catch (_) {}
              },
              child: ListView(children: [
                Card(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(children: [
                      Text('TOTAL', style: t.titleMedium),
                      _baris('Pelanggan harian', '${sum('pelanggan')}'),
                      _baris('Pendapatan harian', rupiah.format(sum('pendapatan'))),
                      _baris('Member baru ($bln)', '${sum('member_baru')}'),
                      _baris('Pendapatan member ($bln)', rupiah.format(sum('pendapatan_member'))),
                      if (aktif != null) _baris('Member aktif saat ini', '$aktif'),
                    ]),
                  ),
                ),
                if (rows.isEmpty) const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('Belum ada akun admin. Tambahkan di menu Akun.')),
                ...rows.map((r) => Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('${r['nama']}', style: t.titleMedium),
                          _baris('Pelanggan harian', '${r['pelanggan']}'),
                          _baris('Pendapatan harian', rupiah.format(r['pendapatan'])),
                          _baris('Member baru ($bln)', '${r['member_baru']}'),
                          _baris('Pendapatan member ($bln)', rupiah.format(r['pendapatan_member'])),
                        ]),
                      ),
                    )),
              ]),
            );
          },
        ),
      ),
    ]);
  }
}

// ---------- Rekap bulanan ----------
class RekapPage extends StatefulWidget {
  const RekapPage({super.key});
  @override
  State<RekapPage> createState() => _RekapPageState();
}

class _RekapPageState extends State<RekapPage> {
  late Future<List<Map<String, dynamic>>> f = Api.rekap();

  Future<void> salin(List<Map<String, dynamic>> rows) async {
    await Clipboard.setData(ClipboardData(text: Api.rekapCsv(rows)));
    if (mounted) toast(context, 'CSV disalin. Tempel di Excel / Google Sheets.');
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Column(children: [
      Row(children: [
        Expanded(child: Text('Rekap 12 bulan', style: t.titleLarge)),
        IconButton(icon: const Icon(Icons.refresh), onPressed: () => setState(() => f = Api.rekap())),
      ]),
      Expanded(
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: f,
          builder: (c, s) {
            if (s.hasError) {
              return ErrorView(msg: errMsg(s.error!), onRetry: () => setState(() => f = Api.rekap()));
            }
            if (!s.hasData) return const Center(child: CircularProgressIndicator());
            final rows = s.data!;
            return ListView(children: [
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton.icon(
                    onPressed: () => salin(rows),
                    icon: const Icon(Icons.copy),
                    label: const Text('Salin CSV')),
              ),
              ...rows.map((r) {
                final total = (r['pendapatan_harian'] as num) + (r['pendapatan_member'] as num);
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(fBulan.format(DateTime.parse(r['bulan'])), style: t.titleMedium),
                      _baris('Pelanggan harian', '${r['pelanggan']}'),
                      _baris('Pendapatan harian', rupiah.format(r['pendapatan_harian'])),
                      _baris('Member baru', '${r['member_baru']}'),
                      _baris('Pendapatan member', rupiah.format(r['pendapatan_member'])),
                      const Divider(),
                      _baris('Total pendapatan', rupiah.format(total)),
                    ]),
                  ),
                );
              }),
            ]);
          },
        ),
      ),
    ]);
  }
}

// ---------- Pengaturan data ----------
class DataPage extends StatefulWidget {
  const DataPage({super.key});
  @override
  State<DataPage> createState() => _DataPageState();
}

class _DataPageState extends State<DataPage> {
  final hh = TextEditingController(), hm = TextEditingController();
  final hhp = TextEditingController(), hmp = TextEditingController();
  final dur = TextEditingController(), ret = TextEditingController();
  int? old;
  DateTime? batas;
  bool busy = false;
  String? err;
  late Future<List<Map<String, dynamic>>> audit = Api.audit();

  @override
  void initState() {
    super.initState();
    Api.settings().then((s) {
      if (!mounted) return;
      hh.text = '${s['harga_harian']}';
      hm.text = '${s['harga_member']}';
      hhp.text = '${s['harga_harian_pelajar']}';
      hmp.text = '${s['harga_member_pelajar']}';
      dur.text = '${s['durasi_member_hari']}';
      ret.text = '${s['retensi_bulan']}';
    }).catchError((Object e) {
      if (mounted) setState(() => err = errMsg(e));
    });
  }

  @override
  void dispose() {
    for (final c in [hh, hm, hhp, hmp, dur, ret]) {
      c.dispose();
    }
    super.dispose();
  }

  int? n(TextEditingController c) => int.tryParse(c.text.trim());

  Future<void> simpan() async {
    final a = n(hh), b = n(hm), p = n(hhp), q = n(hmp), d = n(dur), r = n(ret);
    if (a == null || b == null || p == null || q == null || d == null || r == null ||
        a < 0 || b < 0 || p < 0 || q < 0 || d < 1 || r < 1) {
      toast(context, 'Isi semua angka dengan benar (durasi dan retensi minimal 1)');
      return;
    }
    try {
      await Api.saveSettings({
        'harga_harian': a, 'harga_member': b, 'harga_harian_pelajar': p, 'harga_member_pelajar': q,
        'durasi_member_hari': d, 'retensi_bulan': r,
      });
      if (mounted) toast(context, 'Pengaturan disimpan');
    } catch (e) {
      if (mounted) toast(context, 'Gagal: ${errMsg(e)}');
    }
  }

  Future<void> hitung() async {
    final r = n(ret);
    if (r == null || r < 1) {
      toast(context, 'Isi batas bulan dengan angka minimal 1');
      return;
    }
    try {
      final c = await Api.countOld(r);
      final b = await Api.purgeCutoff(r);
      if (mounted) {
        setState(() {
          old = c;
          batas = b;
        });
      }
    } catch (e) {
      if (mounted) toast(context, 'Gagal: ${errMsg(e)}');
    }
  }

  Future<void> salinCsv() async {
    setState(() => busy = true);
    try {
      final csv = await Api.csvDataLama(n(ret)!);
      await Clipboard.setData(ClipboardData(text: csv));
      final baris = csv.trim().split('\n').length - 1;
      if (mounted) toast(context, '$baris baris disalin. Tempel di Excel / Google Sheets lalu simpan.');
    } catch (e) {
      if (mounted) toast(context, 'Gagal: ${errMsg(e)}');
    }
    if (mounted) setState(() => busy = false);
  }

  Future<void> bersihkan() async {
    final c = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Bersihkan data lama'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('$old data kunjungan harian sebelum ${fTanggal.format(batas!)} akan dihapus PERMANEN. '
              'Rekap bulanan tetap tersimpan. Sudah menyalin CSV? Ketik HAPUS untuk lanjut.'),
          TextField(controller: c, decoration: const InputDecoration(hintText: 'HAPUS')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, c.text.trim() == 'HAPUS'),
              child: const Text('Hapus')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final hapus = await Api.purge(n(ret)!);
      if (mounted) toast(context, '$hapus data dihapus');
      await hitung();
      if (mounted) setState(() => audit = Api.audit());
    } catch (e) {
      if (mounted) toast(context, 'Gagal: ${errMsg(e)}');
    }
  }

  Widget f(TextEditingController c, String l) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(
            controller: c,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(labelText: l, border: const OutlineInputBorder())),
      );

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return ListView(children: [
      if (err != null) Text(err!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
      Text('Harga & paket', style: t.titleMedium),
      const SizedBox(height: 8),
      f(hh, 'Harga harian UMUM (Rp)'),
      f(hhp, 'Harga harian PELAJAR (Rp)'),
      f(hm, 'Harga member UMUM (Rp)'),
      f(hmp, 'Harga member PELAJAR (Rp)'),
      f(dur, 'Durasi member (hari)'),
      f(ret, 'Simpan data kunjungan (bulan)'),
      FilledButton(onPressed: simpan, child: const Text('Simpan pengaturan')),
      const Divider(height: 40),
      Text('Bersihkan database', style: t.titleMedium),
      const SizedBox(height: 8),
      const Text('Menghapus detail kunjungan harian yang lebih lama dari batas di atas. '
          'Rekap bulanan tetap ada di tab Rekap. Data member tidak dihapus.'),
      const SizedBox(height: 8),
      Text(old == null
          ? 'Hitung dulu berapa data lama yang akan dihapus.'
          : '$old data kunjungan sebelum ${fTanggal.format(batas!)}.'),
      const SizedBox(height: 8),
      OutlinedButton(onPressed: hitung, child: const Text('Hitung data lama')),
      const SizedBox(height: 8),
      OutlinedButton.icon(
        onPressed: (old ?? 0) > 0 && !busy ? salinCsv : null,
        icon: const Icon(Icons.copy),
        label: const Text('Salin CSV data lama (cadangan)'),
      ),
      const SizedBox(height: 8),
      FilledButton.icon(
        style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
        onPressed: (old ?? 0) > 0 && !busy ? bersihkan : null,
        icon: const Icon(Icons.delete_forever),
        label: const Text('Bersihkan data lama'),
      ),
      const Divider(height: 40),
      Text('Riwayat aktivitas', style: t.titleMedium),
      FutureBuilder<List<Map<String, dynamic>>>(
        future: audit,
        builder: (c, s) {
          if (s.hasError) return Text('Gagal memuat: ${errMsg(s.error!)}');
          if (!s.hasData) return const Padding(padding: EdgeInsets.all(8), child: LinearProgressIndicator());
          if (s.data!.isEmpty) return const Text('Belum ada aktivitas.');
          return Column(
            children: s.data!.map((r) {
              final w = DateTime.parse(r['created_at']).toLocal();
              return ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text('${r['aksi']} • ${r['detail'] ?? ''}'),
                subtitle: Text('${fTanggal.format(w)} ${fJam.format(w)}'),
              );
            }).toList(),
          );
        },
      ),
    ]);
  }
}
