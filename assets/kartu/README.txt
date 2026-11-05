========================================================================
PANDUAN DESAIN & UKURAN GAMBAR KARTU MEMBER (STANDAR ISO CR80)
========================================================================

Aplikasi Gym Monitor mendukung 2 metode tampilan kartu:
1. DESAIN 2D BAWAAN (OTOMATIS):
   Jika Anda belum menaruh gambar apa pun di folder ini, aplikasi
   otomatis membuat kartu 2D mewah tema Luxury Black & Gold (lengkap
   dengan ornamen chip emas, kurva emas, QR Code, dan barcode).

2. MEMAKAI DESAIN LATAR BELAKANG SENDIRI:
   Jika Anda mendesain kartu di Canva, Photoshop, Figma, atau Illustrator,
   simpan desain latar belakang ke dalam folder ini dengan nama:
   - depan.png    (untuk sisi depan kartu)
   - belakang.png (untuk sisi belakang kartu)

------------------------------------------------------------------------
SPESIFIKASI UKURAN GAMBAR YANG BENAR:
------------------------------------------------------------------------
- Standar Fisik      : CR80 / ISO 7810 ID-1 (Standar Kartu ATM / e-KTP)
- Ukuran Fisik       : 85,60 mm x 53,98 mm (Rasio ~1.586 : 1)
- Ukuran Piksel Pas  : 1011 x 638 piksel  (Resolusi 300 DPI - Tajam)
- Format File        : PNG (RGB, 24-bit atau 32-bit dengan transparansi)
- Sudut Kartu        : Radius sudut 3,18 mm (di aplikasi otomatis dibuat melengkung)

TIPS DESAIN SENDIRI:
- Sisi Depan   : Kosongkan area tengah-bawah untuk teks Nama, No Member,
                 dan area kanan-bawah untuk penempatan QR Code.
- Sisi Belakang: Kosongkan area kanan-bawah untuk penempatan Barcode.
                 Area tersebut akan digambar otomatis oleh aplikasi
                 sehingga nomor barcode selalu dinamis dan terbaca scanner.

------------------------------------------------------------------------
EKSPOR & PENCETAKAN:
------------------------------------------------------------------------
- Ekspor PDF   : Menghasilkan PDF ukuran fisik asli 85.6 x 54 mm per halaman
                 atau lembar A4 siap print dengan tanda garis potong.
- Barcode/QR   : Dibuat dalam format vector / resolusi ultra tajam sehingga
                 100% langsung terbaca oleh Scanner USB OM200 dan turnstile.
