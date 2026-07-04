import 'package:flutter/material.dart';
import 'package:kuwrir_shared/kuwrir_shared.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  User? _user;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      _user = await ApiClient().getMe();
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Keluar'),
        content: const Text('Yakin ingin keluar dari akun ini?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Keluar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ApiClient().clearTokens();
    if (mounted) {
      Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
    }
  }

  Future<void> _editField({
    required String label,
    required String? currentValue,
    required TextInputType keyboardType,
    required Future<User> Function(String value) onSave,
  }) async {
    final ctrl = TextEditingController(text: currentValue ?? '');
    String? error;

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text('Ubah $label'),
          content: TextField(
            controller: ctrl,
            keyboardType: keyboardType,
            autofocus: true,
            decoration: InputDecoration(labelText: label, errorText: error),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () async {
                final value = ctrl.text.trim();
                if (value.isEmpty) {
                  setDialogState(() => error = '$label wajib diisi');
                  return;
                }
                try {
                  _user = await onSave(value);
                  if (dialogContext.mounted) Navigator.pop(dialogContext, true);
                } catch (e) {
                  setDialogState(() => error = e is ApiException ? e.message : '$e');
                }
              },
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
    if (saved == true && mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KuwrirColors.background,
      appBar: AppBar(title: const Text('Profil Saya')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Center(
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 40,
                        backgroundColor: KuwrirColors.primary.withValues(alpha: 0.1),
                        child: Icon(Icons.person, size: 40, color: KuwrirColors.primary),
                      ),
                      const SizedBox(height: 12),
                      Text(_user?.name.isNotEmpty == true ? _user!.name : 'Tanpa nama',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      Text(_user?.phone ?? '-',
                          style: TextStyle(color: KuwrirColors.textSecondary)),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Card(
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.badge_outlined),
                        title: const Text('Nama'),
                        subtitle: Text(_user?.name.isNotEmpty == true ? _user!.name : 'Belum diisi'),
                        trailing: const Icon(Icons.edit_outlined, size: 18),
                        onTap: () => _editField(
                          label: 'Nama',
                          currentValue: _user?.name,
                          keyboardType: TextInputType.name,
                          onSave: (value) => ApiClient().updateProfile(name: value),
                        ),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.email_outlined),
                        title: const Text('Email'),
                        subtitle: Text(_user?.email.isNotEmpty == true ? _user!.email : 'Belum diisi'),
                        trailing: const Icon(Icons.edit_outlined, size: 18),
                        onTap: () => _editField(
                          label: 'Email',
                          currentValue: _user?.email,
                          keyboardType: TextInputType.emailAddress,
                          onSave: (value) => ApiClient().updateProfile(email: value),
                        ),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.phone_outlined),
                        title: const Text('No. Telepon'),
                        subtitle: Text(_user?.phone ?? '-'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.logout, color: Colors.red),
                    title: const Text('Keluar', style: TextStyle(color: Colors.red)),
                    onTap: _logout,
                  ),
                ),
              ],
            ),
    );
  }
}
