import 'dart:typed_data';
import 'package:barcode_widget/barcode_widget.dart';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'api.dart';
import 'kartu_aset.dart';
import 'kartu_config.dart';
import 'widgets.dart';

// =====================================================================
// MODEL 2D KARTU MEMBER (FLUTTER UI PREVIEW)
// =====================================================================

/// SISI DEPAN: desain dari assets/kartu/Depan.png + (hanya) ID Member + QR 2D
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
        final qrSisi = w * kKartuQrSisi;

        return ClipRRect(
          borderRadius: BorderRadius.circular(w * 0.038),
          child: Stack(
            fit: StackFit.expand,
            children: [
              const KartuLatar(path: kKartuTemplateDepan, depan: true),
              // ID Member (teks contoh di desain sudah dihapus, jadi tidak perlu penutup)
              Positioned(
                left: w * kKartuIdLeft,
                top: h * (kKartuIdTengahY - kKartuIdTinggi / 2),
                width: w * kKartuIdLebar,
                height: h * kKartuIdTinggi,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    nomor,
                    maxLines: 1,
                    style: TextStyle(
                      color: kKartuIdWarna,
                      fontSize: h * kKartuIdFont,
                      fontWeight: FontWeight.w800,
                      letterSpacing: w * 0.002,
                      height: 1,
                    ),
                  ),
                ),
              ),
              // QR 2D: kotak terang berisi modul gelap (paling mudah dibaca scanner)
              Positioned(
                left: w * kKartuQrTengahX - qrSisi / 2,
                top: h * kKartuQrTengahY - qrSisi / 2,
                width: qrSisi,
                height: qrSisi,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: kKartuQrLatar,
                    borderRadius: BorderRadius.circular(qrSisi * 0.07),
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(qrSisi * 0.09),
                    child: BarcodeWidget(
                      barcode: Barcode.qrCode(),
                      data: nomor,
                      color: kKartuQrWarna,
                      backgroundColor: kKartuQrLatar,
                      drawText: false,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}

/// SISI BELAKANG: desain dari assets/kartu/Belakang.png tanpa overlay
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
          child: const KartuLatar(path: kKartuTemplateBelakang),
        );
      }),
    );
  }
}

typedef KartuMember = KartuMemberInteraktif;

/// Widget Kartu Interaktif untuk Layar: Bisa beralih Tampak Depan & Belakang
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
                Icon(depan ? Icons.credit_card : Icons.flip_to_back, size: 18, color: const Color(0xFFD4AF37)),
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
// GENERATOR PDF VECTOR RESMI (MURNI DART - ANTI CRASH & 100% TAJAM)
// =====================================================================

class KartuPdfEngine {
  /// Ukuran fisik pas kartu PVC CR80 (85.60 mm x 53.98 mm)
  static final cardFormat = PdfPageFormat(
    85.60 * PdfPageFormat.mm,
    53.98 * PdfPageFormat.mm,
    marginAll: 0,
  );

  /// Memakai gambar yang sudah diproses (dipotong, rasio CR80) agar ringan dan pas.
  static Future<pw.MemoryImage?> _loadAsset(String path, {bool depan = false}) async {
    final g = await KartuAset.muat(path, bersihkanId: depan);
    return g == null ? null : pw.MemoryImage(g.png);
  }

  /// Bangun dokumen PDF lengkap berisi semua kartu yang dipilih
  static Future<pw.Document> buatDokumen(List<String> daftarNomor) async {
    final pdf = pw.Document(title: 'Kartu Member $kNamaGym');
    final bgDepan = await _loadAsset(kKartuTemplateDepan, depan: true);
    final bgBelakang = await _loadAsset(kKartuTemplateBelakang);

    for (final no in daftarNomor) {
      // Halaman Depan
      pdf.addPage(
        pw.Page(
          pageFormat: cardFormat,
          build: (ctx) => pw.FullPage(
            ignoreMargins: true,
            child: _pdfDepan(no, bgDepan),
          ),
        ),
      );

      // Halaman Belakang
      pdf.addPage(
        pw.Page(
          pageFormat: cardFormat,
          build: (ctx) => pw.FullPage(
            ignoreMargins: true,
            child: _pdfBelakang(bgBelakang),
          ),
        ),
      );
    }

    return pdf;
  }

  /// Sisi depan PDF: desain + (hanya) ID Member + QR 2D
  static pw.Widget _pdfDepan(String nomor, pw.MemoryImage? bgImage) {
    const pageW = 85.60 * PdfPageFormat.mm;
    const pageH = 53.98 * PdfPageFormat.mm;
    const qrSisi = pageW * kKartuQrSisi;

    return pw.Container(
      width: pageW,
      height: pageH,
      color: const PdfColor.fromInt(0xFF101116),
      child: pw.Stack(
        children: [
          if (bgImage != null)
            pw.Positioned(
              left: 0,
              top: 0,
              right: 0,
              bottom: 0,
              child: pw.Image(bgImage, fit: pw.BoxFit.fill),
            ),
          pw.Positioned(
            left: pageW * kKartuIdLeft,
            top: pageH * (kKartuIdTengahY - kKartuIdTinggi / 2),
            child: pw.SizedBox(
              width: pageW * kKartuIdLebar,
              height: pageH * kKartuIdTinggi,
              child: pw.FittedBox(
                fit: pw.BoxFit.scaleDown,
                alignment: pw.Alignment.centerLeft,
                child: pw.Text(
                  nomor,
                  maxLines: 1,
                  style: pw.TextStyle(
                    color: const PdfColor.fromInt(0xFFFBBF24),
                    fontWeight: pw.FontWeight.bold,
                    fontSize: pageH * kKartuIdFont,
                    letterSpacing: pageW * 0.002,
                  ),
                ),
              ),
            ),
          ),
          pw.Positioned(
            left: pageW * kKartuQrTengahX - qrSisi / 2,
            top: pageH * kKartuQrTengahY - qrSisi / 2,
            child: pw.Container(
              width: qrSisi,
              height: qrSisi,
              decoration: pw.BoxDecoration(
                color: PdfColors.white,
                borderRadius: pw.BorderRadius.all(pw.Radius.circular(qrSisi * 0.07)),
              ),
              padding: pw.EdgeInsets.all(qrSisi * 0.09),
              child: pw.BarcodeWidget(
                barcode: pw.Barcode.qrCode(),
                data: nomor,
                color: PdfColors.black,
                drawText: false,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Sisi belakang PDF: desain utuh tanpa overlay
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
// MENU HALAMAN KARTU (GENERASI ID, EXPORT PDF OTOMATIS & SHARING)
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

  @override
  void initState() {
    super.initState();
    muatRiwayat();
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
    setState(() {
      nomor = daftar;
    });
    if (ctrl.hasClients) {
      ctrl.animateTo(0, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    }
  }

  /// Eksekusi buat nomor baru di database
  Future<void> buat() async {
    final n = int.tryParse(jumlah.text.trim());
    if (n == null || n < 1 || n > 30) {
      toast(context, 'Jumlah kartu 1 sampai 30');
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
        // Otomatis munculkan opsi Export PDF & Cetak setelah selesai
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
              'Format PDF dibuat murni vector standar fisik CR80 (85.6 x 54 mm) siap cetak di printer kartu PVC atau kertas stiker.',
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

  /// Export kartu ke PDF resmi standar ISO CR80 (85.6 mm x 54 mm) murni vector
  Future<void> exportPdf(List<String> daftar) async {
    if (daftar.isEmpty) return;
    setState(() => busy = true);
    try {
      final doc = await KartuPdfEngine.buatDokumen(daftar);
      final bytes = await doc.save();
      final filename = 'Kartu_Member_${daftar.first}.pdf';

      // Langsung munculkan print preview bawaan OS / Chrome
      await Printing.layoutPdf(
        name: filename,
        onLayout: (PdfPageFormat format) async => bytes,
      );
    } catch (e) {
      if (mounted) await tampilError(context, 'Gagal membuat file PDF', errMsg(e));
    }
    if (mounted) setState(() => busy = false);
  }

  /// Simpan/bagikan gambar PNG (Depan & Belakang) via PDF Raster (300 DPI - pas untuk Word)
  Future<void> simpanPngWord(String no) async {
    setState(() => busy = true);
    try {
      final doc = await KartuPdfEngine.buatDokumen([no]);
      final pdfBytes = await doc.save();

      // Render halaman PDF ke PNG resolusi 300 DPI
      final files = <XFile>[];
      var idx = 0;
      await for (final page in Printing.raster(pdfBytes, dpi: 300)) {
        final pngBytes = await page.toPng();
        final suffix = idx == 0 ? 'depan' : 'belakang';
        files.add(XFile.fromData(pngBytes, name: '${no}_$suffix.png', mimeType: 'image/png'));
        idx++;
      }

      await SharePlus.instance.share(
        ShareParams(files: files, text: 'Kartu Member $no (Depan & Belakang - 300 DPI)'),
      );
    } catch (e) {
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
          'Format ID terstruktur (misal: BM-2026-0001). Dilengkapi QR Code untuk Turnstile Gate '
          'dan Barcode Code 128 untuk Scanner USB OM200. Hasil otomatis bisa diexport ke PDF berstandar cetak.',
          style: TextStyle(fontSize: 12),
        ),
        const SizedBox(height: 14),

        // Input Prefiks & Jumlah
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
                  helperText: 'Akan menjadi: BM-2026-0001',
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
                  labelText: 'Jumlah kartu (1-30)',
                  helperText: 'Buat nomor berurutan',
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

        // Tampilan Kartu Hasil Generate
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
                label: const Text('Export / Cetak Semua (PDF)'),
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
                    // Kartu Interaktif (Preview di layar)
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

        // Riwayat Kartu yang pernah dibuat
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
