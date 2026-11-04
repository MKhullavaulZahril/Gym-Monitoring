import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'api.dart';
import 'config.dart';
import 'login.dart';
import 'admin.dart';
import 'super_admin.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('id_ID');
  await Supabase.initialize(url: kSupabaseUrl, publishableKey: kSupabaseKey);
  runApp(const App());
}

class App extends StatelessWidget {
  const App({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Gym Monitor',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(colorSchemeSeed: Colors.deepOrange, useMaterial3: true),
        home: const Gate(),
      );
}

/// Pintu masuk: setelah login, role dibaca dari tabel `profiles`
/// lalu pengguna diarahkan ke layar Super Admin atau Admin.
class Gate extends StatefulWidget {
  const Gate({super.key});
  @override
  State<Gate> createState() => _GateState();
}

class _GateState extends State<Gate> {
  // Profil di-cache supaya tidak dimuat ulang (dan layar tidak berkedip)
  // setiap kali token login diperbarui otomatis.
  Future<Profile?>? _pf;
  String? _uid;

  void _load(String uid) {
    _uid = uid;
    _pf = Api.profile();
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<AuthState>(
        stream: db.auth.onAuthStateChange,
        builder: (_, __) {
          final u = db.auth.currentUser;
          if (u == null) {
            _uid = null;
            _pf = null;
            return const LoginPage();
          }
          if (u.id != _uid) _load(u.id);
          return FutureBuilder<Profile?>(
            future: _pf,
            builder: (c, s) {
              if (s.connectionState != ConnectionState.done) {
                return const Scaffold(body: Center(child: CircularProgressIndicator()));
              }
              if (s.hasError) {
                return _Info(
                  icon: Icons.cloud_off,
                  judul: 'Gagal memuat akun',
                  isi: errMsg(s.error!),
                  email: u.email ?? '-',
                  onRetry: () => setState(() => _load(u.id)),
                );
              }
              final p = s.data;
              if (p != null) return p.isSuper ? SuperHome(p) : AdminHome(p);
              return _Info(
                icon: Icons.lock_person,
                judul: 'Akun belum punya akses',
                isi: 'Email ini belum didaftarkan sebagai Admin atau Super Admin, atau akunnya dinonaktifkan.\n\n'
                    'Minta Super Admin menambahkannya di menu Akun, lalu tekan Cek Ulang.',
                email: u.email ?? '-',
                onRetry: () => setState(() => _load(u.id)),
              );
            },
          );
        },
      );
}

class _Info extends StatelessWidget {
  final IconData icon;
  final String judul, isi, email;
  final VoidCallback onRetry;
  const _Info({
    required this.icon, required this.judul, required this.isi,
    required this.email, required this.onRetry,
  });

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(icon, size: 64, color: Colors.orange),
                const SizedBox(height: 16),
                Text(judul,
                    style: Theme.of(context).textTheme.titleLarge, textAlign: TextAlign.center),
                const SizedBox(height: 8),
                Text(email, style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                Text(isi, textAlign: TextAlign.center),
                const SizedBox(height: 24),
                Row(children: [
                  Expanded(
                      child: OutlinedButton.icon(
                          onPressed: () => db.auth.signOut(),
                          icon: const Icon(Icons.logout),
                          label: const Text('Keluar'))),
                  const SizedBox(width: 12),
                  Expanded(
                      child: FilledButton.icon(
                          onPressed: onRetry,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Cek Ulang'))),
                ]),
              ]),
            ),
          ),
        ),
      );
}
