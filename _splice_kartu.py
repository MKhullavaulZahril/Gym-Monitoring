from pathlib import Path

p = Path(r'd:\laragon\www\gym_monitor\lib\kartu.dart')
text = p.read_text(encoding='utf-8')

start = text.index('  /// Sisi Depan dalam format PDF Vector')
end = text.index('// =====================================================================\n// MENU HALAMAN KARTU')

pdf_methods = r'''  /// Sisi depan PDF: desain + ID Member + QR 2D
  static pw.Widget _pdfDepan(String nomor, pw.MemoryImage? bgImage) {
    const pageW = 85.60 * PdfPageFormat.mm;
    const pageH = 53.98 * PdfPageFormat.mm;
    const idWarna = PdfColor.fromInt(0xFFFBBF24);
    const idLatar = PdfColor.fromInt(0xFF1D1408);
    const qrLatar = PdfColor.fromInt(0xFF151410);

    return pw.Container(
      width: pageW,
      height: pageH,
      color: const PdfColor.fromInt(0xFF101116),
      child: pw.Stack(
        children: [
          if (bgImage != null)
            pw.Positioned.fill(
              child: pw.Image(bgImage, fit: pw.BoxFit.fill),
            ),
          pw.Positioned(
            left: pageW * kKartuIdLeft,
            top: pageH * kKartuIdTop,
            width: pageW * kKartuIdWidth,
            height: pageH * kKartuIdHeight,
            child: pw.Container(
              color: idLatar,
              alignment: pw.Alignment.centerLeft,
              child: pw.FittedBox(
                fit: pw.BoxFit.contain,
                alignment: pw.Alignment.centerLeft,
                child: pw.Text(
                  nomor,
                  maxLines: 1,
                  style: pw.TextStyle(
                    color: idWarna,
                    fontWeight: pw.FontWeight.bold,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
            ),
          ),
          pw.Positioned(
            left: pageW * kKartuQrLeft,
            top: pageH * kKartuQrTop,
            width: pageW * kKartuQrWidth,
            height: pageH * kKartuQrHeight,
            child: pw.Container(
              color: qrLatar,
              padding: const pw.EdgeInsets.all(1.2),
              child: pw.BarcodeWidget(
                barcode: pw.Barcode.qrCode(),
                data: nomor,
                color: idWarna,
                backgroundColor: qrLatar,
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

'''

p.write_text(text[:start] + pdf_methods + text[end:], encoding='utf-8')
print('ok', start, end)
