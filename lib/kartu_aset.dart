import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'kartu_config.dart';

/// Gambar satu sisi kartu yang sudah diproses otomatis oleh aplikasi:
///  - dipotong tepat pada tepi kartu (bayangan / area transparan di sekitarnya dibuang),
///  - diubah ke rasio kartu CR80 (2022 x 1275 px),
///  - sisi depan: teks ID contoh di desain ditutup dengan latar yang menyatu.
/// Jadi file desain asli (besar, ada bayangan) maupun yang sudah dipotong sama-sama bisa dipakai.
class KartuGambar {
  final ui.Image image;
  final Uint8List png;
  const KartuGambar(this.image, this.png);
}

class KartuAset {
  static const int lebar = 2022;
  static const int tinggi = 1275;

  static final Map<String, Future<KartuGambar?>> _cache = {};
  static final Map<String, KartuGambar> _siap = {};

  /// Hasil yang sudah selesai diproses (null jika belum), agar tampilan tidak berkedip.
  static KartuGambar? siap(String path) => _siap[path];

  /// [bersihkanId] = true untuk sisi depan.
  static Future<KartuGambar?> muat(String path, {bool bersihkanId = false}) =>
      _cache.putIfAbsent(path, () => _proses(path, bersihkanId));

  static Future<KartuGambar?> _proses(String path, bool bersihkanId) async {
    try {
      final data = await rootBundle.load(path);
      final bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);

      // File besar didecode dalam ukuran lebih kecil supaya ringan.
      int? target;
      final png = bytes.length > 24 && bytes[0] == 0x89 && bytes[1] == 0x50;
      if (png && data.getUint32(16) > 2600) target = 2600;

      final codec = await ui.instantiateImageCodec(bytes, targetWidth: target);
      final src = (await codec.getNextFrame()).image;
      final sw = src.width;
      final sh = src.height;

      // 1) Cari kotak kartu: piksel yang benar-benar tidak transparan.
      final raw = await src.toByteData(format: ui.ImageByteFormat.rawRgba);
      final px = raw!.buffer.asUint8List(raw.offsetInBytes, raw.lengthInBytes);
      var minX = sw, minY = sh, maxX = -1, maxY = -1;
      for (var y = 0; y < sh; y += 2) {
        final row = y * sw * 4;
        for (var x = 0; x < sw; x += 2) {
          if (px[row + x * 4 + 3] >= 250) {
            if (x < minX) minX = x;
            if (x > maxX) maxX = x;
            if (y < minY) minY = y;
            if (y > maxY) maxY = y;
          }
        }
      }
      if (maxX < 0) {
        minX = 0;
        minY = 0;
        maxX = sw - 1;
        maxY = sh - 1;
      }

      // 2) Potong + ubah ukuran ke rasio CR80.
      final rec = ui.PictureRecorder();
      final canvas = Canvas(rec);
      canvas.drawImageRect(
        src,
        Rect.fromLTRB(minX.toDouble(), minY.toDouble(), (maxX + 1).toDouble(), (maxY + 1).toDouble()),
        Rect.fromLTWH(0, 0, lebar.toDouble(), tinggi.toDouble()),
        Paint()
          ..filterQuality = FilterQuality.high
          ..isAntiAlias = true,
      );
      var out = await rec.endRecording().toImage(lebar, tinggi);
      src.dispose();

      // 3) Sisi depan: hapus teks ID contoh.
      if (bersihkanId) out = await _bersihkanId(out);

      final pngData = await out.toByteData(format: ui.ImageByteFormat.png);
      final hasil = KartuGambar(
        out,
        pngData!.buffer.asUint8List(pngData.offsetInBytes, pngData.lengthInBytes),
      );
      _siap[path] = hasil;
      return hasil;
    } catch (e) {
      debugPrint('Gagal memproses desain kartu $path: $e');
      return null;
    }
  }

  /// Menutup area teks ID contoh dengan gradasi latar yang diambil dari
  /// pita bersih tepat di atas dan di bawah teks.
  static Future<ui.Image> _bersihkanId(ui.Image img) async {
    final raw = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
    final px = raw!.buffer.asUint8List(raw.offsetInBytes, raw.lengthInBytes);
    final w = img.width;
    final h = img.height;

    Color rata(int cx, int cy) {
      var r = 0, g = 0, b = 0, n = 0;
      for (var dy = -2; dy <= 2; dy++) {
        for (var dx = -3; dx <= 3; dx++) {
          final x = (cx + dx).clamp(0, w - 1).toInt();
          final y = (cy + dy).clamp(0, h - 1).toInt();
          final i = (y * w + x) * 4;
          r += px[i];
          g += px[i + 1];
          b += px[i + 2];
          n++;
        }
      }
      return Color.fromARGB(255, r ~/ n, g ~/ n, b ~/ n);
    }

    final x0 = (w * kKartuIdBersihKiri).round();
    final x1 = (w * kKartuIdBersihKanan).round();
    final y0 = (h * kKartuIdBersihAtas).round();
    final y1 = (h * kKartuIdBersihBawah).round();
    final yAtas = (h * kKartuIdPitaAtas).round();
    final yBawah = (h * kKartuIdPitaBawah).round();

    final rec = ui.PictureRecorder();
    final canvas = Canvas(rec);
    canvas.drawImage(img, Offset.zero, Paint());
    const lebarStrip = 12;
    for (var x = x0; x < x1; x += lebarStrip) {
      final xe = (x + lebarStrip < x1) ? x + lebarStrip : x1;
      final xc = (x + xe) ~/ 2;
      final paint = Paint()
        ..shader = ui.Gradient.linear(
          Offset(0, y0.toDouble()),
          Offset(0, y1.toDouble()),
          [rata(xc, yAtas), rata(xc, yBawah)],
        )
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
      // tiap strip sedikit tumpang tindih agar tidak ada garis tipis di sambungan
      canvas.drawRect(
        Rect.fromLTRB((x - 6).toDouble(), y0.toDouble(), (xe + 6).toDouble(), y1.toDouble()),
        paint,
      );
    }
    final hasil = await rec.endRecording().toImage(w, h);
    img.dispose();
    return hasil;
  }
}

/// Latar kartu (sudah diproses) sebagai widget; mengisi seluruh area yang tersedia.
class KartuLatar extends StatelessWidget {
  final String path;
  final bool depan;
  const KartuLatar({super.key, required this.path, this.depan = false});

  @override
  Widget build(BuildContext context) => FutureBuilder<KartuGambar?>(
        future: KartuAset.muat(path, bersihkanId: depan),
        initialData: KartuAset.siap(path),
        builder: (context, s) {
          final g = s.data;
          if (g == null) return const ColoredBox(color: Color(0xFF101116));
          return RawImage(image: g.image, fit: BoxFit.fill);
        },
      );
}
