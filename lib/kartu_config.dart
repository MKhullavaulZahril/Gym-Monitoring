import 'package:flutter/material.dart';

// =====================================================================
// PENGATURAN KARTU MEMBER (STANDAR CR80: 85.6 mm x 54.0 mm)
// =====================================================================
// Desain kartu memakai gambar di folder assets/kartu/. Aplikasi otomatis memotong
// tepat pada tepi kartu (bayangan dibuang) dan mengubahnya ke rasio CR80, jadi file
// desain asli maupun yang sudah dipotong sama-sama bisa dipakai:
// - Sisi depan   : assets/kartu/Depan.png
// - Sisi belakang: assets/kartu/Belakang.png
// Data dinamis dari generate ID HANYA di sisi depan: ID Member + QR 2D.
// Sisi belakang tampil utuh sesuai desain, tanpa overlay.
// =====================================================================

const kKartuTemplateDepan = 'assets/kartu/Depan.png';
const kKartuTemplateBelakang = 'assets/kartu/Belakang.png';

// Rasio fisik kartu CR80 (85.6 mm x 53.98 mm)
const kKartuRasio = 85.6 / 53.98;

// ---- ID Member (posisi sebagai pecahan 0..1 dari lebar / tinggi kartu) ----
const kKartuIdLeft = 0.0538;     // jarak teks dari tepi kiri (pecahan lebar)
const kKartuIdTengahY = 0.8441;  // titik tengah teks dari atas (pecahan tinggi)
const kKartuIdLebar = 0.28;      // lebar maksimal teks; ID yang lebih panjang mengecil otomatis
const kKartuIdTinggi = 0.060;    // tinggi kotak teks (pecahan tinggi)
const kKartuIdFont = 0.034;      // ukuran huruf (pecahan tinggi kartu)
const kKartuIdWarna = Color(0xFFFBBF24);

// Area teks ID contoh di desain yang ditutup otomatis (pecahan lebar / tinggi kartu),
// beserta baris contoh warna latar tepat di atas dan di bawahnya.
const kKartuIdBersihKiri = 0.0485;
const kKartuIdBersihKanan = 0.2316;
const kKartuIdBersihAtas = 0.8237;
const kKartuIdBersihBawah = 0.8723;
const kKartuIdPitaAtas = 0.8198;
const kKartuIdPitaBawah = 0.8763;

// ---- QR 2D: kotak QR berada di tengah bingkai hitam pada desain ----
const kKartuQrTengahX = 0.8107;  // titik tengah dari kiri (pecahan lebar)
const kKartuQrTengahY = 0.6994;  // titik tengah dari atas (pecahan tinggi)
const kKartuQrSisi = 0.104;      // sisi kotak QR (pecahan lebar)
// Modul gelap di atas latar terang = paling mudah dibaca semua scanner.
// (QR emas di atas hitam / terbalik tidak terbaca oleh sebagian scanner.)
const kKartuQrLatar = Color(0xFFFFFFFF);
const kKartuQrWarna = Color(0xFF000000);

// Identitas Gym
const kNamaGym = 'BULEMAN';
