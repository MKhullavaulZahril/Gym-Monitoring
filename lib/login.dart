import 'package:flutter/material.dart';
import 'api.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final email = TextEditingController(), pass = TextEditingController();
  bool busy = false;

  @override
  void dispose() {
    email.dispose();
    pass.dispose();
    super.dispose();
  }

  Future<void> login() async {
    final e = email.text.trim().toLowerCase();
    if (e.isEmpty || pass.text.isEmpty) {
      toast(context, 'Isi email dan password');
      return;
    }
    setState(() => busy = true);
    try {
      await db.auth.signInWithPassword(email: e, password: pass.text);
    } catch (err) {
      if (mounted) toast(context, errMsg(err));
    }
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.fitness_center, size: 64),
                const SizedBox(height: 8),
                Text('Gym Monitor', style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 8),
                const Text(
                    'Cukup masukkan email dan password.\nRole (Admin / Super Admin) ditentukan otomatis oleh akunmu, tidak perlu dipilih.',
                    textAlign: TextAlign.center),
                const SizedBox(height: 24),
                TextField(
                    controller: email,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder())),
                const SizedBox(height: 12),
                TextField(
                    controller: pass,
                    obscureText: true,
                    autofillHints: const [AutofillHints.password],
                    onSubmitted: (_) => busy ? null : login(),
                    decoration: const InputDecoration(labelText: 'Password', border: OutlineInputBorder())),
                const SizedBox(height: 16),
                SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                        onPressed: busy ? null : login,
                        child: Text(busy ? 'Memproses...' : 'Masuk'))),
                const SizedBox(height: 12),
                const Text('Lupa password? Minta Super Admin mengatur ulang lewat dashboard Supabase.',
                    textAlign: TextAlign.center, style: TextStyle(fontSize: 12)),
              ]),
            ),
          ),
        ),
      );
}
