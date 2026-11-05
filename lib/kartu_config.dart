import 'package:flutter/material.dart';

// =====================================================================
// PENGATURAN KARTU MEMBER (STANDAR CR80: 85.6 mm x 54.0 mm)
// =====================================================================
// Desain kartu memakai gambar di folder assets/kartu/:
//   - File tampak depan    : assets/kartu/Depan.png
//   - File tampak belakang : assets/kartu/Belakang.png
//
// Data dinamis yang di-overlay dari generate ID:
//   1. ID Member (teks emas) — sisi DEPAN saja
//   2. QR Code 2D            — sisi DEPAN saja
// Sisi belakang ditampilkan utuh sesuai desain tanpa overlay.
// =====================================================================

const kKartuTemplateDepan    = 'assets/kartu/Depan.png';
const kKartuTemplateBelakang = 'assets/kartu/Belakang.png';

// ── Posisi ID Member (relatif terhadap lebar/tinggi kartu, 0.0–1.0) ──
// Sesuaikan nilai ini agar teks ID tepat berada di area desain yang diinginkan
const kKartuIdLeft   = 0.100;   // jarak dari kiri (10%)
const kKartuIdTop    = 0.742;   // jarak dari atas (74.2%)
const kKartuIdWidth  = 0.220;   // lebar area teks (22%)
const kKartuIdHeight = 0.090;   // tinggi area teks (9%)

// ── Posisi QR Code (relatif terhadap lebar/tinggi kartu, 0.0–1.0) ──
// Sesuaikan agar QR tepat berada di kotak desain yang sudah ada
const kKartuQrLeft   = 0.718;   // jarak dari kiri (71.8%)
const kKartuQrTop    = 0.420;   // jarak dari atas (42%) — naik dari 52%
const kKartuQrWidth  = 0.148;   // lebar QR (14.8%)
const kKartuQrHeight = 0.510;   // tinggi QR (51%)

// ── Warna overlay ──
const kKartuIdWarna  = Color(0xFFFBBF24);   // emas — warna teks ID Member
const kKartuQrWarna  = Color(0xFFFBBF24);   // emas — warna modul QR Code
const kKartuQrLatar  = Color(0xFF1A1408);   // hitam gelap — latar QR agar bisa dibaca scanner

// Rasio fisik kartu CR80 (85.6 mm x 53.98 mm)
const kKartuRasio = 85.6 / 53.98;

// ── Identitas Gym ──
const kNamaGym      = 'BULEMAN';
const kSubNamaGym   = 'ATHLETIC & PERFORMANCE CENTER';
const kSloganGym    = '"NO PAIN, NO GAIN"';
const kBadgeKlub    = 'LUXURY FITNESS CLUB • EST. 2026 • INDONESIA';
const kVipClass     = "VIP MEMBERSHIP CLASS • FOUNDER'S CIRCLE";

// ── Kontak & Info Gym ──
const kInstagramGym     = '@buleman.gym';
const kWhatsAppGym      = '0812-3456-7890';
const kAlamatGym        = 'Jl. Fitness No. 88, Denpasar, Bali 80221 - Indonesia';
const kJamOperasional   = 'SENIN - MINGGU: 06:00 - 22:00 WITA';

// ── Aturan Member (sisi belakang) ──
const kAturan1 = 'Kartu wajib ditunjukkan pada turnstile gate / staf setiap kunjungan. Akses fasilitas hanya untuk pemegang kartu resmi yang aktif.';
const kAturan2 = 'Kartu ini strictly non-transferable (tidak dapat dipindahtangankan ke orang lain).';
const kAturan3 = 'Laporkan segera ke front desk jika kartu hilang atau rusak. Biaya penggantian dan cetak ulang kartu sebesar Rp 50.000,-';
