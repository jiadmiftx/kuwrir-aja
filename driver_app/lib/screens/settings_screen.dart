import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:kuwrir_shared/kuwrir_shared.dart';

/// Account-management actions split out from ProfileScreen so the profile
/// page stays focused on identity/vehicle info — sign-out and delete-account
/// live here instead of competing for attention on the main profile list.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _logout(BuildContext context) async {
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
    if (confirmed != true || !context.mounted) return;
    final nav = Navigator.of(context);
    await ApiClient().clearTokens();
    nav.pushNamedAndRemoveUntil('/login', (_) => false);
  }

  Future<void> _deleteAccount(BuildContext context) async {
    final confirmed = await showDeleteAccountDialog(context);
    if (confirmed != true || !context.mounted) return;

    try {
      await ApiClient().deleteAccount();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e is ApiException ? e.message : 'Gagal menghapus akun',
            ),
          ),
        );
      }
      return;
    }
    if (!context.mounted) return;
    final nav = Navigator.of(context);
    await ApiClient().clearTokens();
    nav.pushNamedAndRemoveUntil('/login', (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KuwrirColors.background,
      appBar: AppBar(
        title: const Text('Pengaturan'),
        backgroundColor: KuwrirColors.background,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'AKUN'.toUpperCase(),
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: KuwrirColors.textHint,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: KuwrirColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: KuwrirColors.border),
            ),
            clipBehavior: Clip.antiAlias,
            child: ListTile(
              leading: _SettingsRowIcon(
                icon: HugeIcons.strokeRoundedLogout01,
                color: KuwrirColors.error,
              ),
              title: Text(
                'Keluar',
                style: TextStyle(
                  color: KuwrirColors.error,
                  fontWeight: FontWeight.w600,
                  fontSize: 14.5,
                ),
              ),
              onTap: () => _logout(context),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: KuwrirColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: KuwrirColors.border),
            ),
            clipBehavior: Clip.antiAlias,
            child: ListTile(
              leading: _SettingsRowIcon(
                icon: HugeIcons.strokeRoundedDelete02,
                color: KuwrirColors.error,
              ),
              title: Text(
                'Hapus Akun',
                style: TextStyle(
                  color: KuwrirColors.error,
                  fontWeight: FontWeight.w600,
                  fontSize: 14.5,
                ),
              ),
              onTap: () => _deleteAccount(context),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsRowIcon extends StatelessWidget {
  final List<List<dynamic>> icon;
  final Color color;
  const _SettingsRowIcon({required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(9),
      ),
      child: HugeIcon(icon: icon, color: color),
    );
  }
}
