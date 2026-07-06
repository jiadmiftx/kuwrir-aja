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
      appBar: AppBar(
        title: const Text('Profil Saya'),
        backgroundColor: KuwrirColors.background,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Center(
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 40,
                        backgroundColor: KuwrirColors.primary.withValues(alpha: 0.08),
                        child: Icon(Icons.person, size: 40, color: KuwrirColors.primary),
                      ),
                      const SizedBox(height: 14),
                      Text(_user?.name.isNotEmpty == true ? _user!.name : 'Tanpa nama',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text(_user?.phone ?? '-',
                          style: TextStyle(color: KuwrirColors.textSecondary, fontSize: 13)),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                const _ProfileSectionLabel('Informasi Akun'),
                const SizedBox(height: 10),
                _ProfileSoftPanel(
                  child: Column(
                    children: [
                      _ProfileRow(
                        icon: Icons.badge_outlined,
                        label: 'Nama',
                        value: _user?.name.isNotEmpty == true ? _user!.name : 'Belum diisi',
                        onTap: () => _editField(
                          label: 'Nama',
                          currentValue: _user?.name,
                          keyboardType: TextInputType.name,
                          onSave: (value) => ApiClient().updateProfile(name: value),
                        ),
                      ),
                      Divider(height: 1, color: KuwrirColors.border),
                      _ProfileRow(
                        icon: Icons.email_outlined,
                        label: 'Email',
                        value: _user?.email.isNotEmpty == true ? _user!.email : 'Belum diisi',
                        onTap: () => _editField(
                          label: 'Email',
                          currentValue: _user?.email,
                          keyboardType: TextInputType.emailAddress,
                          onSave: (value) => ApiClient().updateProfile(email: value),
                        ),
                      ),
                      Divider(height: 1, color: KuwrirColors.border),
                      _ProfileRow(
                        icon: Icons.phone_outlined,
                        label: 'No. Telepon',
                        value: _user?.phone ?? '-',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                const _ProfileSectionLabel('Alamat'),
                const SizedBox(height: 10),
                _ProfileSoftPanel(
                  child: ListTile(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: KuwrirColors.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.location_on_outlined, size: 18, color: KuwrirColors.primary),
                    ),
                    title: const Text('Alamat Tersimpan', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5)),
                    trailing: Icon(Icons.chevron_right, color: KuwrirColors.textHint),
                    onTap: () => Navigator.pushNamed(context, '/addresses'),
                  ),
                ),
                const SizedBox(height: 28),
                _ProfileSoftPanel(
                  child: ListTile(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    leading: Icon(Icons.logout, color: KuwrirColors.error),
                    title: Text('Keluar', style: TextStyle(color: KuwrirColors.error, fontWeight: FontWeight.w600)),
                    onTap: _logout,
                  ),
                ),
              ],
            ),
    );
  }
}

class _ProfileSectionLabel extends StatelessWidget {
  final String text;
  const _ProfileSectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
        fontSize: 11.5,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
        color: KuwrirColors.textHint,
      ),
    );
  }
}

class _ProfileSoftPanel extends StatelessWidget {
  final Widget child;
  const _ProfileSoftPanel({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: KuwrirColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: KuwrirColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}

class _ProfileRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;
  const _ProfileRow({required this.icon, required this.label, required this.value, this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: KuwrirColors.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 18, color: KuwrirColors.primary),
      ),
      title: Text(label, style: const TextStyle(fontSize: 13, color: KuwrirColors.textSecondary)),
      subtitle: Text(value, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600)),
      trailing: onTap != null ? Icon(Icons.edit_outlined, size: 18, color: KuwrirColors.textHint) : null,
      onTap: onTap,
    );
  }
}
