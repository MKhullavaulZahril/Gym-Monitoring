import 'package:flutter/material.dart';
import 'api.dart';
import 'kartu.dart';
import 'widgets.dart';

class AdminHome extends StatefulWidget {
  final Profile p;
  const AdminHome(this.p, {super.key});
  @override
  State<AdminHome> createState() => _AdminHomeState();
}

class _AdminHomeState extends State<AdminHome> {
  int i = 0;
  String? scan; // hasil scan terakhir yang belum diproses halaman tujuan
  int seq = 0;

  /// Dipanggil saat kartu di-scan dari menu mana pun.
  /// Di tab Daftar: nomor masuk ke form pendaftaran. Selain itu: pindah ke Cek Member.
  void onScan(String code) {
    setState(() {
      if (i != 2) i = 1;
      scan = code;
      seq++;
    });
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      const HarianPage(),
      CekPage(
        scan: scan,
        seq: seq,
        onDaftar: (code) => setState(() {
          i = 2;
          scan = code;
          seq++;
        }),
      ),
      DaftarPage(scan: scan, seq: seq),
      const KartuPage(),
    ];
    return ScanListener(
      onScan: onScan,
      child: Scaffold(
        appBar: AppBar(
          title: Text('Admin • ${widget.p.nama}'),
          actions: const [AccountMenu()],
        ),
        body: Padding(padding: const EdgeInsets.all(16), child: pages[i]),
        bottomNavigationBar: NavigationBar(
          selectedIndex: i,
          onDestinationSelected: (v) => setState(() {
            i = v;
            scan = null;
          }),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.today), label: 'Harian'),
            NavigationDestination(icon: Icon(Icons.badge), label: 'Cek Member'),
            NavigationDestination(icon: Icon(Icons.person_add), label: 'Daftar'),
            NavigationDestination(icon: Icon(Icons.credit_card), label: 'Kartu'),
          ],
        ),
      ),
    );
  }
}

// ---------- Pelanggan harian ----------
class HarianPage extends StatefulWidget {
  const HarianPage({super.key});
  @override
  State<HarianPage> createState() => _HarianPageState();
}

class _HarianPageState extends State<HarianPage> {
  final nama = TextEditingController();
  String tipe = tipeBayar.first;
  String kategori = 'umum';
  Map<String, dynamic>? sett;
  int? get harga => sett == null ? null : hargaHarian(sett!, kategori);
  String? err;
  List<Map<String, dynamic>> riwayat = [];
  bool busy = false;

  @override
  void initState() {
    super.initState();
    muat();
  }

  @override
  void dispose() {
    nama.dispose();
    super.dispose();
  }

  Future<void> muat() async {
    try {
      final s = await Api.settings();
      final r = await Api.kunjunganHariIni();
      if (!mounted) return;
      setState(() {
        sett = s;
        riwayat = r;
        err = null;
      });
    } catch (e) {
      if (mounted) setState(() => err = errMsg(e));
    }
  }

  Future<void> simpan() async {
    setState(() => busy = true);
    try {
      final h = await Api.catatKunjungan(nama.text.trim(), tipe, kategori);
      nama.clear();
      FocusManager.instance.primaryFocus?.unfocus();
      if (mounted) toast(context, 'Tersimpan: ${rupiah.format(h)} ($tipe)');
      await muat();
    } catch (e) {
      if (mounted) toast(context, 'Gagal: ${errMsg(e)}');
    }
    if (mounted) setState(() => busy = false);
  }

  Future<void> batal(Map<String, dynamic> r) async {
    final ok = await konfirmasi(
      context,
      'Batalkan input ini?',
      '${rupiah.format(r['harga'])} (${r['tipe_pembayaran']}) tidak akan dihitung di laporan.',
      ya: 'Batalkan',
    );
    if (!ok) return;
    try {
      await Api.batalkanKunjungan(r['id']);
      await muat();
    } catch (e) {
      if (mounted) toast(context, 'Gagal: ${errMsg(e)}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final aktif = riwayat.where((r) => r['batal'] != true);
    final total = aktif.fold<int>(0, (a, r) => a + (r['harga'] as int));
    return ListView(children: [
      if (err != null)
        Card(
          color: Theme.of(context).colorScheme.errorContainer,
          child: ListTile(
            title: Text(err!),
            trailing: TextButton(onPressed: muat, child: const Text('Coba lagi')),
          ),
        ),
      KategoriSelector(value: kategori, onChanged: (v) => setState(() => kategori = v)),
      const SizedBox(height: 12),
      Text('Harga harian ${labelKategori(kategori)}', style: t.titleMedium),
      Text(harga == null ? '-' : rupiah.format(harga), style: t.headlineMedium),
      const SizedBox(height: 16),
      TextField(
          controller: nama,
          onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
          decoration: const InputDecoration(
              labelText: 'Nama pelanggan (opsional)', border: OutlineInputBorder())),
      const SizedBox(height: 12),
      PayDropdown(value: tipe, onChanged: (v) => setState(() => tipe = v)),
      const SizedBox(height: 16),
      FilledButton.icon(
        onPressed: busy || harga == null ? null : simpan,
        icon: const Icon(Icons.check),
        label: const Text('Simpan pelanggan harian'),
      ),
      const Divider(height: 32),
      Text('Input kamu hari ini', style: t.titleMedium),
      Text('${aktif.length} pelanggan • ${rupiah.format(total)}'),
      const SizedBox(height: 8),
      if (riwayat.isEmpty) const Text('Belum ada input hari ini.'),
      ...riwayat.map((r) {
        final batalOk = r['batal'] == true;
        final gaya = batalOk ? const TextStyle(decoration: TextDecoration.lineThrough) : null;
        return Card(
          child: ListTile(
            dense: true,
            title: Text('${r['nama_pelanggan'] ?? 'Pelanggan'} • ${rupiah.format(r['harga'])}',
                style: gaya),
            subtitle: Text(
                '${labelKategori(r['kategori'])} • ${r['tipe_pembayaran']} • ${fJam.format(DateTime.parse(r['waktu']).toLocal())}'
                '${batalOk ? ' • DIBATALKAN' : ''}'),
            trailing: batalOk
                ? null
                : IconButton(
                    tooltip: 'Batalkan input',
                    icon: const Icon(Icons.cancel_outlined),
                    onPressed: () => batal(r)),
          ),
        );
      }),
    ]);
  }
}

// ---------- Cek member (scan / cari) ----------
class CekPage extends StatefulWidget {
  final String? scan; // kode hasil scan dari menu lain
  final int seq;
  final ValueChanged<String>? onDaftar; // pindah ke tab Daftar dengan nomor ini
  const CekPage({super.key, this.scan, this.seq = 0, this.onDaftar});
  @override
  State<CekPage> createState() => _CekPageState();
}

class _CekPageState extends State<CekPage> {
  Map<String, dynamic>? m;
  List<Map<String, dynamic>> hasil = [];
  String? err;
  String? tidakAda; // nomor yang tidak ditemukan
  bool loading = false;

  @override
  void initState() {
    super.initState();
    _cariDariScan();
  }

  @override
  void didUpdateWidget(CekPage old) {
    super.didUpdateWidget(old);
    if (widget.seq != old.seq) _cariDariScan();
  }

  void _cariDariScan() {
    final code = widget.scan;
    if (code == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) cari(code);
    });
  }

  Future<void> cari(String q) async {
    setState(() {
      loading = true;
      err = null;
    });
    try {
      final r = await Api.cekMember(q);
      if (!mounted) return;
      setState(() {
        loading = false;
        tidakAda = null;
        if (r.isEmpty) {
          m = null;
          hasil = [];
          err = 'Member "$q" tidak ditemukan';
          tidakAda = q;
        } else if (r.length == 1 || '${r.first['no_member']}'.toLowerCase() == q.toLowerCase()) {
          m = r.first;
          hasil = [];
        } else {
          m = null;
          hasil = r;
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          loading = false;
          err = 'Gagal: ${errMsg(e)}';
        });
      }
    }
  }

  Future<void> perpanjang() async {
    try {
      final s = await Api.settings();
      if (!mounted) return;
      String tipe = tipeBayar.first;
      String kat = '${m!['kategori'] ?? 'umum'}';
      final ok = await showDialog<bool>(
        context: context,
        builder: (_) => StatefulBuilder(
          builder: (ctx, set) => AlertDialog(
            title: const Text('Perpanjang member'),
            content: Column(mainAxisSize: MainAxisSize.min, children: [
              KategoriSelector(value: kat, onChanged: (v) => set(() => kat = v)),
              const SizedBox(height: 12),
              Text('${rupiah.format(hargaMember(s, kat))} • ${s['durasi_member_hari']} hari'),
              const SizedBox(height: 12),
              PayDropdown(value: tipe, onChanged: (v) => set(() => tipe = v)),
            ]),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
              FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Simpan')),
            ],
          ),
        ),
      );
      if (ok != true) return;
      await Api.perpanjangMember(m!['id'], tipe, kat);
      await cari('${m!['no_member']}');
      if (mounted) toast(context, 'Membership diperpanjang');
    } catch (e) {
      if (mounted) toast(context, 'Gagal: ${errMsg(e)}');
    }
  }

  Future<void> ubah() async {
    final no = TextEditingController(text: '${m!['no_member']}');
    final nama = TextEditingController(text: '${m!['nama']}');
    final hp = TextEditingController(text: '${m!['no_hp'] ?? ''}');
    final alamat = TextEditingController(text: '${m!['alamat'] ?? ''}');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ubah data member'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: no, decoration: const InputDecoration(labelText: 'No. member')),
            TextField(controller: nama, decoration: const InputDecoration(labelText: 'Nama')),
            TextField(
                controller: hp,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'No. HP')),
            TextField(controller: alamat, decoration: const InputDecoration(labelText: 'Alamat')),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Simpan')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await Api.ubahMember(
          id: m!['id'], no: no.text, nama: nama.text, hp: hp.text, alamat: alamat.text);
      await cari(no.text.trim());
      if (mounted) toast(context, 'Data diperbarui');
    } catch (e) {
      if (mounted) toast(context, 'Gagal: ${errMsg(e)}');
    }
  }

  String sisaText(Map<String, dynamic> r) {
    final s = r['sisa_hari'] as int?;
    return s == null ? 'belum ada membership' : s <= 0 ? 'habis' : 'sisa $s hari';
  }

  Widget kartu(TextTheme t) {
    final sisa = m!['sisa_hari'] as int?;
    final warna = sisa == null || sisa <= 0
        ? Colors.red
        : sisa <= 7 ? Colors.orange : Colors.green;
    final status = sisa == null
        ? 'Belum punya membership'
        : sisa <= 0 ? 'Habis / kedaluwarsa' : 'Sisa $sisa hari';
    final akhir = m!['berakhir'] == null
        ? null
        : DateTime.parse(m!['berakhir']).subtract(const Duration(days: 1)); // hari terakhir berlaku
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${m!['nama']}', style: t.headlineSmall),
          Text('No. member: ${m!['no_member']}'),
          Text('Kategori: ${labelKategori(m!['kategori'])}'),
          if (m!['no_hp'] != null) Text('HP: ${m!['no_hp']}'),
          if (m!['alamat'] != null) Text('Alamat: ${m!['alamat']}'),
          const Divider(height: 24),
          Text(status, style: t.titleLarge?.copyWith(color: warna)),
          if (akhir != null) Text('Masa aktif sampai ${fTanggal.format(akhir)}'),
          const SizedBox(height: 12),
          Wrap(spacing: 8, children: [
            FilledButton.icon(
                onPressed: perpanjang,
                icon: const Icon(Icons.autorenew),
                label: const Text('Perpanjang')),
            OutlinedButton.icon(
                onPressed: ubah, icon: const Icon(Icons.edit), label: const Text('Ubah data')),
          ]),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return ListView(children: [
      ScanField(label: 'Scan kartu / cari nama / no. HP', onScan: cari),
      const SizedBox(height: 16),
      if (loading) const LinearProgressIndicator(),
      if (err != null) Text(err!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
      if (tidakAda != null && widget.onDaftar != null)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: FilledButton.icon(
            onPressed: () => widget.onDaftar!(tidakAda!),
            icon: const Icon(Icons.person_add),
            label: Text('Daftarkan "$tidakAda" sebagai member baru'),
          ),
        ),
      ...hasil.map((r) => Card(
            child: ListTile(
              title: Text('${r['nama']}'),
              subtitle: Text('${r['no_member']} • ${sisaText(r)}'),
              onTap: () => setState(() {
                m = r;
                hasil = [];
              }),
            ),
          )),
      if (m != null) kartu(t),
    ]);
  }
}

// ---------- Daftar member baru ----------
class DaftarPage extends StatefulWidget {
  final String? scan; // kode hasil scan saat tab Daftar sedang terbuka
  final int seq;
  const DaftarPage({super.key, this.scan, this.seq = 0});
  @override
  State<DaftarPage> createState() => _DaftarPageState();
}

class _DaftarPageState extends State<DaftarPage> {
  final no = TextEditingController(), nama = TextEditingController();
  final hp = TextEditingController(), alamat = TextEditingController();
  String tipe = tipeBayar.first;
  String kategori = 'umum';
  Map<String, dynamic>? s;
  String? err;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    muat();
    if (widget.scan != null) no.text = widget.scan!;
  }

  @override
  void didUpdateWidget(DaftarPage old) {
    super.didUpdateWidget(old);
    if (widget.scan != null && widget.seq != old.seq) no.text = widget.scan!;
  }

  @override
  void dispose() {
    for (final c in [no, nama, hp, alamat]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> muat() async {
    try {
      final v = await Api.settings();
      if (mounted) {
        setState(() {
          s = v;
          err = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => err = errMsg(e));
    }
  }

  Future<void> daftar() async {
    if (no.text.trim().isEmpty || nama.text.trim().isEmpty) {
      toast(context, 'No. member dan nama wajib diisi');
      return;
    }
    setState(() => busy = true);
    try {
      final h = await Api.daftarMember(
        no: no.text.trim(), nama: nama.text.trim(), hp: hp.text.trim(),
        alamat: alamat.text.trim(), tipe: tipe, kategori: kategori,
      );
      for (final c in [no, nama, hp, alamat]) {
        c.clear();
      }
      if (mounted) toast(context, 'Member terdaftar • ${rupiah.format(h)} ($tipe)');
    } catch (e) {
      if (mounted) toast(context, 'Gagal: ${errMsg(e)}');
    }
    if (mounted) setState(() => busy = false);
  }

  Widget f(TextEditingController c, String l, {TextInputType? k}) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(
            controller: c,
            keyboardType: k,
            decoration: InputDecoration(labelText: l, border: const OutlineInputBorder())),
      );

  @override
  Widget build(BuildContext context) => ListView(children: [
        ScanField(label: 'Scan kartu member baru', onScan: (v) => setState(() => no.text = v)),
        const SizedBox(height: 12),
        f(no, 'No. member'),
        f(nama, 'Nama member'),
        f(hp, 'No. HP', k: TextInputType.phone),
        f(alamat, 'Alamat'),
        if (err != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(children: [
              Expanded(child: Text(err!, style: TextStyle(color: Theme.of(context).colorScheme.error))),
              TextButton(onPressed: muat, child: const Text('Coba lagi')),
            ]),
          ),
        KategoriSelector(value: kategori, onChanged: (v) => setState(() => kategori = v)),
        const SizedBox(height: 12),
        if (s != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text('Paket ${labelKategori(kategori)}: ${rupiah.format(hargaMember(s!, kategori))} • ${s!['durasi_member_hari']} hari'),
          ),
        PayDropdown(value: tipe, onChanged: (v) => setState(() => tipe = v)),
        const SizedBox(height: 16),
        FilledButton.icon(
            onPressed: busy || s == null ? null : daftar,
            icon: const Icon(Icons.person_add),
            label: const Text('Daftarkan member')),
      ]);
}
