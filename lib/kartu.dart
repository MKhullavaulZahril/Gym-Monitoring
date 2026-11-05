import 'package:barcode_widget/barcode_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'api.dart';
import 'kartu_config.dart';
import 'widgets.dart';

// =====================================================================
// MODEL 2D KARTU MEMBER (FLUTTER UI PREVIEW)
// =====================================================================

/// SISI DEPAN: desain dari assets/kartu/Depan.png + ID Member + QR 2D
/// Tidak ada kotak warna di atas desain — teks/QR transparan di atas gambar
class KartuDepan extends StatelessWidget {
  final String nomor;
  final String nama;
  final String kategori;
  final String joinDate;
  final String secId;

  const KartuDepan({
    super.key,
    required this.nomor,
    this.nama = 'MEMBER GYM',
    this.kategori = 'UMUM',
    this.joinDate = '11 / 2026',
    this.secId = '5942',
  });

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: kKartuRasio,
      child: LayoutBuilder(builder: (context, c) {
        final w = c.maxWidth;
        final h = c.maxHeight;

        return ClipRRect(
          borderRadius: BorderRadius.circular(w * 0.038),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // ── Background: gambar desain penuh ──
              Image.asset(
                kKartuTemplateDepan,
                fit: BoxFit.fill,
                errorBuilder: (_, __, ___) => Container(
                  color: const Color(0xFF101116),
                  alignment: Alignment.center,
                  child: const Text('Depan.png tidak ditemukan\ndi assets/kartu/',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.amber, fontSize: 11)),
                ),
              ),

              // ── Overlay: ID Member (teks langsung di atas gambar) ──
              Positioned(
                left: w * kKartuIdLeft,
                top: h * kKartuIdTop,
                width: w * kKartuIdWidth,
                height: h * kKartuIdHeight,
                child: FittedBox(
                  fit: BoxFit.contain,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    nomor,
                    maxLines: 1,
                    style: const TextStyle(
                      color: kKartuIdWarna,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.0,
                      height: 1,
                    ),
                  ),
                ),
              ),

              // ── Overlay: QR Code (transparan bg) ──
              Positioned(
                left: w * kKartuQrLeft,
                top: h * kKartuQrTop,
                width: w * kKartuQrWidth,
                height: h * kKartuQrHeight,
                child: BarcodeWidget(
                  barcode: Barcode.qrCode(),
                  data: nomor,
                  color: kKartuQrWarna,
                  backgroundColor: kKartuQrLatar,
                  padding: EdgeInsets.all(w * 0.004),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}

/// SISI BELAKANG: desain dari assets/kartu/Belakang.png — tanpa overlay apapun
class KartuBelakang extends StatelessWidget {
  final String nomor;
  final String nama;
  final String cvv;

  const KartuBelakang({
    super.key,
    required this.nomor,
    this.nama = 'Aditya Perkasa',
    this.cvv = '884-BM',
  });

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: kKartuRasio,
      child: LayoutBuilder(builder: (context, c) {
        final w = c.maxWidth;
        return ClipRRect(
          borderRadius: BorderRadius.circular(w * 0.038),
          child: Image.asset(
            kKartuTemplateBelakang,
            fit: BoxFit.fill,
            errorBuilder: (_, __, ___) => Container(
              color: const Color(0xFF101116),
              alignment: Alignment.center,
              child: const Text('Belakang.png tidak ditemukan\ndi assets/kartu/',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.amber, fontSize: 11)),
            ),
          ),
        );
      }),
    );
  }
}

typedef KartuMember = KartuMemberInteraktif;

/// Widget Kartu Interaktif: tap untuk balik sisi depan ↔ belakang
class KartuMemberInteraktif extends StatefulWidget {
  final String nomor;
  final String nama;
  final String kategori;

  const KartuMemberInteraktif({
    super.key,
    required this.nomor,
    this.nama = 'MEMBER BARU',
    this.kategori = 'UMUM',
  });

  @override
  State<KartuMemberInteraktif> createState() => _KartuMemberInteraktifState();
}

class _KartuMemberInteraktifState extends State<KartuMemberInteraktif> {
  bool depan = true;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(depan ? Icons.credit_card : Icons.flip_to_back,
                    size: 18, color: const Color(0xFFD4AF37)),
                const SizedBox(width: 6),
                Text(
                  depan ? 'Tampak Depan (Sisi Depan)' : 'Tampak Belakang (Sisi Belakang)',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            TextButton.icon(
              onPressed: () => setState(() => depan = !depan),
              icon: const Icon(Icons.sync, size: 16),
              label: Text(depan ? 'Balik ke Belakang' : 'Balik ke Depan'),
            ),
          ],
        ),
        const SizedBox(height: 4),
        InkWell(
          onTap: () => setState(() => depan = !depan),
          borderRadius: BorderRadius.circular(16),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            transitionBuilder: (child, animation) => FadeTransition(opacity: animation, child: child),
            child: depan
                ? KartuDepan(key: const ValueKey('depan'), nomor: widget.nomor, nama: widget.nama, kategori: widget.kategori)
                : KartuBelakang(key: const ValueKey('belakang'), nomor: widget.nomor, nama: widget.nama),
          ),
        ),
      ],
    );
  }
}

// =====================================================================
// GENERATOR PDF VECTOR (MURNI DART — ANTI CRASH, TAJAM, SIAP CETAK)
// =====================================================================

class KartuPdfEngine {
  /// Ukuran fisik kartu PVC CR80 (85.60 mm × 53.98 mm)
  static final cardFormat = PdfPageFormat(
    85.60 * PdfPageFormat.mm,
    53.98 * PdfPageFormat.mm,
    marginAll: 0,
  );

  /// Muat gambar dari assets; kembalikan null kalau gagal
  static Future<pw.MemoryImage?> muatGambar(String path) async {
    try {
      final data = await rootBundle.load(path);
      return pw.MemoryImage(data.buffer.asUint8List());
    } catch (_) {
      return null;
    }
  }

  /// Bangun dokumen PDF — setiap nomor kartu = 2 halaman (depan + belakang)
  /// Terima gambar yang sudah di-load agar tidak freeze saat tombol ditekan
  static Future<pw.Document> buatDokumen(
    List<String> daftarNomor, {
    pw.MemoryImage? bgDepan,
    pw.MemoryImage? bgBelakang,
  }) async {
    final pdf = pw.Document(title: 'Kartu Member $kNamaGym');

    // Fallback: muat di sini jika belum di-preload
    final imgDepan = bgDepan ?? await muatGambar(kKartuTemplateDepan);
    final imgBelakang = bgBelakang ?? await muatGambar(kKartuTemplateBelakang);

    for (final no in daftarNomor) {
      // ── Halaman Depan ──
      pdf.addPage(
        pw.Page(
          pageFormat: cardFormat,
          build: (ctx) => pw.FullPage(
            ignoreMargins: true,
            child: _pdfDepan(no, imgDepan),
          ),
        ),
      );

      // ── Halaman Belakang ──
      pdf.addPage(
        pw.Page(
          pageFormat: cardFormat,
          build: (ctx) => pw.FullPage(
            ignoreMargins: true,
            child: _pdfBelakang(imgBelakang),
          ),
        ),
      );
    }

    return pdf;
  }

  /// Halaman depan PDF: gambar desain + ID Member + QR Code
  static pw.Widget _pdfDepan(String nomor, pw.MemoryImage? bgImage) {
    const pageW = 85.60 * PdfPageFormat.mm;
    const pageH = 53.98 * PdfPageFormat.mm;

    // Warna untuk overlay (sama dengan konstanta di kartu_config.dart)
    const idWarna = PdfColor.fromInt(0xFFFBBF24);  // emas
    const qrWarna = PdfColor.fromInt(0xFFFBBF24);  // emas
    const qrLatar = PdfColor.fromInt(0xFF151410);  // hitam gelap (biar kontras)

    return pw.Stack(
      children: [
        // ── Background: gambar desain penuh ──
        if (bgImage != null)
          pw.Positioned.fill(
            child: pw.Image(bgImage, fit: pw.BoxFit.fill),
          )
        else
          pw.Positioned.fill(
            child: pw.Container(color: const PdfColor.fromInt(0xFF101116)),
          ),

        // ── Overlay: ID Member (teks emas langsung di atas gambar) ──
        // pw.Positioned tidak punya width/height → pakai SizedBox di dalam child
        pw.Positioned(
          left: pageW * kKartuIdLeft,
          top: pageH * kKartuIdTop,
          child: pw.SizedBox(
            width: pageW * kKartuIdWidth,
            height: pageH * kKartuIdHeight,
            child: pw.FittedBox(
              fit: pw.BoxFit.contain,
              alignment: pw.Alignment.centerLeft,
              child: pw.Text(
                nomor,
                maxLines: 1,
                style: pw.TextStyle(
                  color: idWarna,
                  fontWeight: pw.FontWeight.bold,
                  letterSpacing: 0.8,
                ),
              ),
            ),
          ),
        ),

        // ── Overlay: QR Code 2D (latar hitam agar bisa dibaca scanner) ──
        pw.Positioned(
          left: pageW * kKartuQrLeft,
          top: pageH * kKartuQrTop,
          child: pw.SizedBox(
            width: pageW * kKartuQrWidth,
            height: pageH * kKartuQrHeight,
            child: pw.Container(
              color: qrLatar,
              padding: const pw.EdgeInsets.all(1.5),
              child: pw.BarcodeWidget(
                barcode: pw.Barcode.qrCode(),
                data: nomor,
                color: qrWarna,
                backgroundColor: qrLatar,
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Halaman belakang PDF: gambar desain utuh, tanpa overlay apapun
  static pw.Widget _pdfBelakang(pw.MemoryImage? bgImage) {
    const pageW = 85.60 * PdfPageFormat.mm;
    const pageH = 53.98 * PdfPageFormat.mm;
    return pw.Container(
      width: pageW,
      height: pageH,
      color: const PdfColor.fromInt(0xFF101116),
      child: bgImage == null
          ? pw.SizedBox()
          : pw.Image(bgImage, fit: pw.BoxFit.fill),
    );
  }
}

// =====================================================================
// MENU HALAMAN KARTU (GENERATE ID, EXPORT PDF, SHARING)
// =====================================================================

class KartuPage extends StatefulWidget {
  const KartuPage({super.key});
  @override
  State<KartuPage> createState() => _KartuPageState();
}

class _KartuPageState extends State<KartuPage> {
  final prefix = TextEditingController(text: 'BM');
  final jumlah = TextEditingController(text: '1');
  final ctrl = ScrollController();
  List<String> nomor = [];
  List<Map<String, dynamic>> riwayat = [];
  bool busy = false;
  String? riwayatErr;

  // Gambar desain di-preload saat halaman dibuka agar export tidak freeze
  pw.MemoryImage? _imgDepan;
  pw.MemoryImage? _imgBelakang;
  bool _gambarSiap = false;

  @override
  void initState() {
    super.initState();
    muatRiwayat();
    _preloadGambar();
    muatRiwayat();
  }

  /// Load gambar desain di background saat halaman pertama dibuka
  Future<void> _preloadGambar() async {
    final d = await KartuPdfEngine.muatGambar(kKartuTemplateDepan);
    final b = await KartuPdfEngine.muatGambar(kKartuTemplateBelakang);
    if (mounted) {
      setState(() {
        _imgDepan = d;
        _imgBelakang = b;
        _gambarSiap = true;
      });
    }
  }


  @override
  void dispose() {
    prefix.dispose();
    jumlah.dispose();
    ctrl.dispose();
    super.dispose();
  }

  Future<void> muatRiwayat() async {
    try {
      final r = await Api.riwayatKartu();
      if (mounted) {
        setState(() {
          riwayat = r;
          riwayatErr = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => riwayatErr = errMsg(e));
    }
  }

  void setDaftarNomor(List<String> daftar) {
    setState(() => nomor = daftar);
    if (ctrl.hasClients) {
      ctrl.animateTo(0, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    }
  }

  /// Buat nomor kartu baru di database
  Future<void> buat() async {
    final n = int.tryParse(jumlah.text.trim());
    if (n == null || n < 1 || n > 50) {
      toast(context, 'Jumlah kartu 1 sampai 50');
      return;
    }
    setState(() => busy = true);
    try {
      final pre = prefix.text.trim().isEmpty ? 'BM' : prefix.text.trim();
      final hasil = await Api.buatNomorKartu(pre, n);
      setDaftarNomor(hasil);
      await muatRiwayat();
      if (mounted) {
        toast(context, '${hasil.length} kartu berhasil dibuat!');
        // Otomatis tampilkan dialog export PDF setelah selesai
        _tampilDialogSelesai(hasil);
      }
    } catch (e) {
      if (mounted) await tampilError(context, 'Gagal membuat kartu', errMsg(e));
    }
    if (mounted) setState(() => busy = false);
  }

  /// Dialog otomatis setelah ID selesai digenerate
  Future<void> _tampilDialogSelesai(List<String> daftar) async {
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: const [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 8),
            Text('Nomor Kartu Selesai!'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Berhasil membuat ${daftar.length} kartu baru:'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(ctx).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                daftar.length <= 4
                    ? daftar.join('\n')
                    : '${daftar.first}  s/d  ${daftar.last} (${daftar.length} kartu)',
                style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1),
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'PDF vector standar fisik CR80 (85.6 × 54 mm), siap cetak di printer kartu PVC atau kertas stiker.',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Nanti Saja'),
          ),
          FilledButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              exportPdf(daftar);
            },
            icon: const Icon(Icons.picture_as_pdf),
            label: const Text('Export / Cetak PDF'),
          ),
        ],
      ),
    );
  }

  /// Export ke PDF — 2 halaman per kartu (depan + belakang), siap cetak
  Future<void> exportPdf(List<String> daftar) async {
    if (daftar.isEmpty) return;
    setState(() => busy = true);

    // Tampilkan dialog loading agar app tidak terlihat freeze
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: AlertDialog(
          content: Row(
            children: const [
              CircularProgressIndicator(),
              SizedBox(width: 20),
              Expanded(child: Text('Menyiapkan PDF...\nMohon tunggu, gambar sedang diproses.')),
            ],
          ),
        ),
      ),
    );

    try {
      final doc = await KartuPdfEngine.buatDokumen(
        daftar,
        bgDepan: _imgDepan,
        bgBelakang: _imgBelakang,
      );
      final bytes = await doc.save();
      final filename = 'Kartu_Member_${daftar.first}.pdf';

      if (mounted) Navigator.of(context, rootNavigator: true).pop(); // tutup loading

      // Tampilkan print dialog / download PDF di Chrome
      await Printing.layoutPdf(
        name: filename,
        onLayout: (PdfPageFormat format) async => bytes,
      );
    } catch (e) {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      if (mounted) await tampilError(context, 'Gagal membuat file PDF', errMsg(e));
    }
    if (mounted) setState(() => busy = false);
  }

  /// Simpan/bagikan PNG (Depan & Belakang) resolusi 300 DPI — untuk Word/desain
  Future<void> simpanPngWord(String no) async {
    setState(() => busy = true);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: AlertDialog(
          content: Row(
            children: const [
              CircularProgressIndicator(),
              SizedBox(width: 20),
              Expanded(child: Text('Menyiapkan gambar PNG 300 DPI...\nMohon tunggu.')),
            ],
          ),
        ),
      ),
    );

    try {
      final doc = await KartuPdfEngine.buatDokumen(
        [no],
        bgDepan: _imgDepan,
        bgBelakang: _imgBelakang,
      );
      final pdfBytes = await doc.save();

      // Render halaman PDF ke PNG 300 DPI
      final files = <XFile>[];
      var idx = 0;
      await for (final page in Printing.raster(pdfBytes, dpi: 300)) {
        final pngBytes = await page.toPng();
        final suffix = idx == 0 ? 'depan' : 'belakang';
        files.add(XFile.fromData(pngBytes, name: '${no}_$suffix.png', mimeType: 'image/png'));
        idx++;
      }

      if (mounted) Navigator.of(context, rootNavigator: true).pop();

      await SharePlus.instance.share(
        ShareParams(files: files, text: 'Kartu Member $no (Depan & Belakang — 300 DPI)'),
      );
    } catch (e) {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      if (mounted) await tampilError(context, 'Gagal membagikan gambar PNG', errMsg(e));
    }
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    return ListView(
      controller: ctrl,
      children: [
        Text('Buat Kartu Member (CR80)', style: t.titleLarge),
        const SizedBox(height: 4),
        const Text(
          'Format ID terstruktur (misal: BM-2026-0001). Dilengkapi QR Code 2D untuk Turnstile Gate. '
          'Kartu menampilkan desain asli dari assets/kartu/ — ID Member & QR di-overlay otomatis.',
          style: TextStyle(fontSize: 12),
        ),

        // Indikator loading gambar desain
        if (!_gambarSiap)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
                SizedBox(width: 10),
                Text('Memuat desain kartu...', style: TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ),
        const SizedBox(height: 14),

        // ── Input Prefiks & Jumlah ──
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: prefix,
                textCapitalization: TextCapitalization.characters,
                maxLength: 6,
                onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
                decoration: const InputDecoration(
                  labelText: 'Kode / Awalan (Prefix)',
                  hintText: 'BM atau GYM',
                  helperText: 'Contoh hasil: BM-2026-0001',
                  border: OutlineInputBorder(),
                  counterText: '',
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: jumlah,
                keyboardType: TextInputType.number,
                onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
                decoration: const InputDecoration(
                  labelText: 'Jumlah kartu (1–50)',
                  helperText: 'Nomor urut otomatis',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        FilledButton.icon(
          onPressed: busy ? null : buat,
          icon: const Icon(Icons.credit_card),
          label: Text(busy ? 'Memproses...' : 'Buat Nomor & Generate Kartu'),
        ),

        // ── Tampilan Kartu Hasil Generate ──
        if (nomor.isNotEmpty) ...[
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${nomor.length} Kartu Siap Digunakan',
                  style: t.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              FilledButton.tonalIcon(
                onPressed: busy ? null : () => exportPdf(nomor),
                icon: const Icon(Icons.picture_as_pdf),
                label: const Text('Export Semua (PDF)'),
              ),
            ],
          ),
          const SizedBox(height: 12),

          for (var i = 0; i < nomor.length; i++) ...[
            Card(
              margin: const EdgeInsets.only(bottom: 24),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Preview kartu interaktif
                    KartuMemberInteraktif(nomor: nomor[i]),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton.icon(
                          onPressed: busy ? null : () => simpanPngWord(nomor[i]),
                          icon: const Icon(Icons.image, size: 18),
                          label: const Text('Simpan PNG (Word)'),
                        ),
                        const SizedBox(width: 8),
                        FilledButton.icon(
                          onPressed: busy ? null : () => exportPdf([nomor[i]]),
                          icon: const Icon(Icons.print, size: 18),
                          label: const Text('Cetak / PDF'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],

        const Divider(height: 40),

        // ── Riwayat Kartu ──
        Row(
          children: [
            Expanded(child: Text('Riwayat Nomor Kartu', style: t.titleMedium)),
            IconButton(icon: const Icon(Icons.refresh), onPressed: muatRiwayat),
          ],
        ),
        if (riwayatErr != null)
          Text(riwayatErr!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
        if (riwayat.isEmpty && riwayatErr == null)
          const Text('Belum ada kartu yang dibuat.'),

        ...riwayat.map((r) {
          final terdaftar = r['terdaftar'] == true;
          final w = DateTime.parse(r['dibuat']).toLocal();
          final no = '${r['nomor']}';
          return Card(
            child: ListTile(
              dense: true,
              title: Text(no, style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.0)),
              subtitle: Text(
                '${terdaftar ? 'Sudah Terdaftar' : 'Belum Dipakai'} • ${fTanggal.format(w)}',
              ),
              trailing: const Icon(Icons.visibility),
              onTap: () => setDaftarNomor([no]),
            ),
          );
        }),
      ],
    );
  }
}
