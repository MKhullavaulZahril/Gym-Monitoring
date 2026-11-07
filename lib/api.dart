import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'config.dart';

final db = Supabase.instance.client;
final rupiah = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
final fTanggal = DateFormat('dd MMM yyyy', 'id_ID');
final fBulan = DateFormat('MMMM yyyy', 'id_ID');
final fJam = DateFormat('HH:mm');
const tipeBayar = ['Tunai', 'Transfer', 'QRIS'];
const kategoriList = ['umum', 'pelajar'];
String labelKategori(Object? k) => k == 'pelajar' ? 'Pelajar' : 'Umum';
int hargaHarian(Map<String, dynamic> s, String k) =>
    (k == 'pelajar' ? s['harga_harian_pelajar'] : s['harga_harian']) as int;
int hargaMember(Map<String, dynamic> s, String k) =>
    (k == 'pelajar' ? s['harga_member_pelajar'] : s['harga_member']) as int;

void toast(BuildContext c, String m) => ScaffoldMessenger.of(c)
  ..hideCurrentSnackBar()
  ..showSnackBar(SnackBar(content: Text(m)));

/// Ubah error teknis menjadi pesan yang mudah dibaca.
String errMsg(Object e) {
  if (e is String) return e;
  if (e is AuthException) {
    final m = e.message.toLowerCase();
    if (m.contains('invalid login')) return 'Email atau password salah';
    if (m.contains('rate limit')) return 'Terlalu banyak percobaan, coba lagi nanti';
    return e.message;
  }
  if (e is PostgrestException) {
    if (e.code == '23505') return 'Data sudah ada (duplikat)';
    if (e.code == '42501') return 'Tidak punya izin untuk aksi ini';
    if (e.code == 'PGRST202' || e.code == '42883') {
      return 'Fungsi di database belum terpasang. Jalankan file SQL terbaru di Supabase SQL Editor (lihat README).';
    }
    if (e.code == '42703' || e.code == 'PGRST204') {
      return 'Struktur database belum diperbarui. Jalankan fix_roles.sql lalu akun.sql di Supabase. (${e.message})';
    }
    return e.message;
  }
  final s = e.toString();
  if (s.contains('SocketException') ||
      s.contains('ClientException') ||
      s.contains('Failed host lookup') ||
      s.contains('XMLHttpRequest')) {
    return 'Tidak ada koneksi internet atau server tidak terjangkau';
  }
  return s;
}

/// Password acak 8 karakter (tanpa karakter yang mirip: 0/O, 1/l/I).
String genPassword([int n = 8]) {
  const c = 'abcdefghjkmnpqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  final r = Random.secure();
  return List.generate(n, (_) => c[r.nextInt(c.length)]).join();
}

String _csv(Object? v) {
  final s = '${v ?? ''}';
  return (s.contains(',') || s.contains('"') || s.contains('\n'))
      ? '"${s.replaceAll('"', '""')}"'
      : s;
}

List<Map<String, dynamic>> _rows(dynamic r) => List<Map<String, dynamic>>.from(r as List);

class Profile {
  final String id, nama, role;
  Profile(this.id, this.nama, this.role);
  bool get isSuper => role == 'super_admin';
  String get roleLabel => isSuper ? 'Super Admin' : 'Admin';
}

class Api {
  static String get uid => db.auth.currentUser?.id ?? '';

  static Future<Profile?> profile() async {
    final id = db.auth.currentUser?.id;
    if (id == null) return null;
    final r = await db.from('profiles').select().eq('id', id).maybeSingle();
    if (r == null || r['aktif'] == false) return null; // belum terdaftar / dinonaktifkan
    return Profile(id, r['nama'] ?? '', r['role']);
  }

  static Future<Map<String, dynamic>> settings() =>
      db.from('settings').select().eq('id', 1).single();

  static Future<void> saveSettings(Map<String, dynamic> v) async {
    await db.from('settings').update(v).eq('id', 1);
  }

  // ---------- Pelanggan harian (harga ditentukan server) ----------
  static Future<int> catatKunjungan(String nama, String tipe, String kategori) async =>
      (await db.rpc('catat_kunjungan',
          params: {'p_nama': nama, 'p_tipe': tipe, 'p_kategori': kategori})) as int;

  static Future<List<Map<String, dynamic>>> kunjunganHariIni() async =>
      _rows(await db.rpc('kunjungan_saya_hari_ini'));

  static Future<void> batalkanKunjungan(String id) async {
    await db.rpc('batalkan_kunjungan', params: {'p_id': id});
  }

  // ---------- Member ----------
  static Future<List<Map<String, dynamic>>> cekMember(String q) async =>
      _rows(await db.rpc('cek_member', params: {'p_q': q}));

  static Future<int> daftarMember({
    required String no, required String nama, String? hp, String? alamat,
    required String tipe, required String kategori,
  }) async =>
      (await db.rpc('daftar_member', params: {
        'p_no': no, 'p_nama': nama, 'p_hp': hp, 'p_alamat': alamat,
        'p_tipe': tipe, 'p_kategori': kategori,
      })) as int;

  static Future<int> perpanjangMember(String memberId, String tipe, String kategori) async =>
      (await db.rpc('perpanjang_member',
          params: {'p_member_id': memberId, 'p_tipe': tipe, 'p_kategori': kategori})) as int;

  static Future<void> ubahMember({
    required String id, required String no, required String nama, String? hp, String? alamat,
  }) async {
    await db.rpc('ubah_member', params: {
      'p_id': id, 'p_no': no, 'p_nama': nama, 'p_hp': hp, 'p_alamat': alamat,
    });
  }

  // ---------- Daftar member (Super Admin) ----------
  static Future<List<Map<String, dynamic>>> listMember({
    String q = '', String status = 'semua', String kategori = '',
    bool dihapus = false, int limit = 50, int offset = 0,
  }) async =>
      _rows(await db.rpc('list_member', params: {
        'p_q': q, 'p_status': status, 'p_kategori': kategori,
        'p_dihapus': dihapus, 'p_limit': limit, 'p_offset': offset,
      }));

  static Future<List<Map<String, dynamic>>> riwayatMembership(String id) async =>
      _rows(await db.rpc('riwayat_membership', params: {'p_member_id': id}));

  static Future<void> hapusMember(String id, String alasan) async {
    await db.rpc('hapus_member', params: {'p_id': id, 'p_alasan': alasan});
  }

  static Future<void> pulihkanMember(String id) async {
    await db.rpc('pulihkan_member', params: {'p_id': id});
  }

  // ---------- Kartu member ----------
  static Future<List<String>> buatNomorKartu(String prefix, int jumlah) async => List<String>.from(
      (await db.rpc('buat_nomor_kartu', params: {'p_prefix': prefix, 'p_jumlah': jumlah})) as List);

  static Future<List<Map<String, dynamic>>> riwayatKartu() async =>
      _rows(await db.rpc('riwayat_kartu', params: {'p_limit': 50}));

  // ---------- Laporan ----------
  static Future<List<dynamic>> stats(DateTime d) async {
    final r = await db.rpc('dashboard_stats', params: {'p_date': DateFormat('yyyy-MM-dd').format(d)});
    return r as List;
  }

  static Future<int> memberAktif() async => (await db.rpc('member_aktif')) as int;

  static Future<List<Map<String, dynamic>>> rekap([int bulan = 12]) async =>
      _rows(await db.rpc('rekap_bulanan', params: {'p_bulan': bulan}));

  static String rekapCsv(List<Map<String, dynamic>> rows) {
    final sb = StringBuffer('bulan,pelanggan_harian,pendapatan_harian,member_baru,pendapatan_member\n');
    for (final r in rows) {
      sb.writeln([
        r['bulan'], r['pelanggan'], r['pendapatan_harian'], r['member_baru'], r['pendapatan_member']
      ].map(_csv).join(','));
    }
    return sb.toString();
  }

  // ---------- Pembersihan data ----------
  static Future<int> countOld(int bulan) async =>
      (await db.rpc('count_old_data', params: {'p_bulan': bulan})) as int;

  static Future<DateTime> purgeCutoff(int bulan) async =>
      DateTime.parse((await db.rpc('purge_cutoff', params: {'p_bulan': bulan})) as String).toLocal();

  static Future<int> purge(int bulan) async =>
      (await db.rpc('purge_old_data', params: {'p_bulan': bulan})) as int;

  /// CSV seluruh kunjungan yang akan dihapus (diambil per 1000 baris).
  static Future<String> csvDataLama(int bulan) async {
    final cutoff = (await db.rpc('purge_cutoff', params: {'p_bulan': bulan})) as String;
    final sb = StringBuffer('waktu,nama_pelanggan,kategori,harga,tipe_pembayaran,admin,dibatalkan\n');
    var from = 0;
    while (true) {
      final rows = _rows(await db
          .from('daily_visits')
          .select('created_at,nama_pelanggan,kategori,harga,tipe_pembayaran,batal,profiles(nama)')
          .lt('created_at', cutoff)
          .order('created_at')
          .order('id')
          .range(from, from + 999));
      for (final r in rows) {
        final waktu = DateTime.parse(r['created_at']).toLocal().toString().substring(0, 19);
        sb.writeln([
          waktu, r['nama_pelanggan'], r['kategori'], r['harga'], r['tipe_pembayaran'],
          (r['profiles'] as Map?)?['nama'], r['batal'],
        ].map(_csv).join(','));
      }
      if (rows.length < 1000) break;
      from += 1000;
    }
    return sb.toString();
  }

  static Future<List<Map<String, dynamic>>> audit() async => _rows(
      await db.from('audit_log').select().order('created_at', ascending: false).limit(15));

  // ---------- Kelola akun (khusus Super Admin) ----------
  static Future<List<Map<String, dynamic>>> staff() async => _rows(await db.rpc('daftar_staff'));

  static Future<void> updateStaff(String id, Map<String, dynamic> v) async {
    final r = await db.from('profiles').update(v).eq('id', id).select();
    if ((r as List).isEmpty) {
      throw 'Perubahan ditolak. Pastikan fix_roles.sql sudah dijalankan dan kamu login sebagai Super Admin.';
    }
  }

  /// Super Admin menetapkan password baru untuk akun lain.
  static Future<void> resetPassword(String id, String password) async {
    await db.rpc('reset_staff_password', params: {'p_id': id, 'p_password': password});
  }

  /// Hapus akun permanen (hanya jika akun belum punya riwayat data).
  static Future<void> hapusStaff(String id) async {
    await db.rpc('hapus_staff', params: {'p_id': id});
  }

  /// Buat akun login baru. true = akun baru dibuat,
  /// false = email sudah punya akun (hanya nama/role yang diatur).
  /// Cara 1: fungsi database. Jika gagal karena kendala teknis, Cara 2: pendaftaran biasa lalu atur role.
  static Future<bool> createStaff({
    required String email, required String password,
    required String nama, required String role,
  }) async {
    String? gagal1;
    try {
      return (await db.rpc('buat_akun_staff', params: {
        'p_email': email, 'p_password': password, 'p_nama': nama, 'p_role': role,
      })) as bool;
    } on PostgrestException catch (e) {
      // Pesan aturan dari fungsi (mis. email tidak valid, bukan Super Admin) ditampilkan apa adanya.
      if (e.code == 'P0001') throw e.message;
      gagal1 = '${e.message} (kode ${e.code ?? '-'})';
    }

    // Cara 2
    final tmp = SupabaseClient(kSupabaseUrl, kSupabaseKey); // sesi terpisah
    String? signUpErr;
    var baru = true;
    try {
      final r = await tmp.auth.signUp(email: email, password: password);
      if (r.user?.identities?.isEmpty ?? false) baru = false;
    } on AuthException catch (e) {
      signUpErr = e.message;
      baru = false;
    } finally {
      await tmp.dispose();
    }
    try {
      await db.rpc('set_staff_role', params: {'p_email': email, 'p_nama': nama, 'p_role': role});
      return baru;
    } on PostgrestException catch (e) {
      throw 'Cara 1 gagal: $gagal1\n'
          'Cara 2 gagal: ${signUpErr ?? e.message}\n'
          '(Pastikan Sign Up aktif dan Confirm email dimatikan di Supabase, atau buat akun lewat Authentication > Users lalu tekan Tambah lagi dengan email yang sama.)';
    }
  }
}
