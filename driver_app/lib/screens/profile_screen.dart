import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:kuwrir_shared/kuwrir_shared.dart';
import 'settings_screen.dart';
import 'delivery_history_screen.dart';
import 'stats_screen.dart';
import 'support_chat_screen.dart';
import 'notifications_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  User? _user;
  Map<String, dynamic>? _application;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final api = ApiClient();
    try {
      final results = await Future.wait([
        api.getMe(),
        api.get('/driver/application'),
      ]);
      _user = results[0] as User;
      _application =
          (results[1] as Map<String, dynamic>)['application']
              as Map<String, dynamic>?;
    } catch (_) {
      // Best-effort — show whatever loaded, empty state otherwise.
    }
    if (mounted) setState(() => _loading = false);
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
                  setDialogState(
                    () => error = e is ApiException ? e.message : '$e',
                  );
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
    final app = _application;
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
                        backgroundColor: KuwrirColors.primary.withValues(
                          alpha: 0.08,
                        ),
                        child: HugeIcon(
                          icon: HugeIcons.strokeRoundedUser,
                          size: 40,
                          color: KuwrirColors.primary,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        _user?.name.isNotEmpty == true
                            ? _user!.name
                            : 'Tanpa nama',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _user?.phone ?? '-',
                        style: TextStyle(
                          color: KuwrirColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
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
                        icon: HugeIcons.strokeRoundedBadge,
                        label: 'Nama',
                        value: _user?.name.isNotEmpty == true
                            ? _user!.name
                            : 'Belum diisi',
                        onTap: () => _editField(
                          label: 'Nama',
                          currentValue: _user?.name,
                          keyboardType: TextInputType.name,
                          onSave: (value) =>
                              ApiClient().updateProfile(name: value),
                        ),
                      ),
                      Divider(height: 1, color: KuwrirColors.border),
                      _ProfileRow(
                        icon: HugeIcons.strokeRoundedMail01,
                        label: 'Email',
                        value: _user?.email.isNotEmpty == true
                            ? _user!.email
                            : 'Belum diisi',
                        onTap: () => _editField(
                          label: 'Email',
                          currentValue: _user?.email,
                          keyboardType: TextInputType.emailAddress,
                          onSave: (value) =>
                              ApiClient().updateProfile(email: value),
                        ),
                      ),
                      Divider(height: 1, color: KuwrirColors.border),
                      _ProfileRow(
                        icon: HugeIcons.strokeRoundedCall,
                        label: 'No. Telepon',
                        value: _user?.phone ?? '-',
                      ),
                    ],
                  ),
                ),
                if (app != null) ...[
                  const SizedBox(height: 28),
                  const _ProfileSectionLabel('Info Kendaraan'),
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Text(
                      'Sesuai data pendaftaran & perjanjian kemitraan — hubungi admin untuk mengubahnya.',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: KuwrirColors.textHint,
                      ),
                    ),
                  ),
                  _ProfileSoftPanel(
                    child: Column(
                      children: [
                        _ProfileRow(
                          icon: HugeIcons.strokeRoundedMotorbike01,
                          label: 'Kendaraan',
                          value:
                              '${app['vehicle_brand'] ?? ''} ${app['vehicle_type'] ?? '-'}'
                                  .trim(),
                        ),
                        Divider(height: 1, color: KuwrirColors.border),
                        _ProfileRow(
                          icon: HugeIcons.strokeRoundedTicket01,
                          label: 'Nomor Plat',
                          value: app['vehicle_plate'] as String? ?? '-',
                        ),
                        Divider(height: 1, color: KuwrirColors.border),
                        _ProfileRow(
                          icon: HugeIcons.strokeRoundedCreditCard,
                          label: 'Nomor SIM',
                          value: app['license_number'] as String? ?? '-',
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 28),
                const _ProfileSectionLabel('Lainnya'),
                const SizedBox(height: 10),
                _ProfileSoftPanel(
                  child: Column(
                    children: [
                      _ActionRow(
                        icon: HugeIcons.strokeRoundedWallet01,
                        label: 'Wallet Driver',
                        onTap: () => Navigator.pushNamed(context, '/wallet'),
                      ),
                      Divider(height: 1, color: KuwrirColors.border),
                      _ActionRow(
                        icon: HugeIcons.strokeRoundedClock01,
                        label: 'Riwayat Pengantaran',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const DeliveryHistoryScreen(),
                          ),
                        ),
                      ),
                      Divider(height: 1, color: KuwrirColors.border),
                      _ActionRow(
                        icon: HugeIcons.strokeRoundedChartLineData02,
                        label: 'Statistik & Performa',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const StatsScreen(),
                          ),
                        ),
                      ),
                      Divider(height: 1, color: KuwrirColors.border),
                      _ActionRow(
                        icon: HugeIcons.strokeRoundedCustomerService01,
                        label: 'Pusat Bantuan',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const SupportChatScreen(),
                          ),
                        ),
                      ),
                      Divider(height: 1, color: KuwrirColors.border),
                      _ActionRow(
                        icon: HugeIcons.strokeRoundedNotification03,
                        label: 'Notifikasi',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const NotificationsScreen(),
                          ),
                        ),
                      ),
                      Divider(height: 1, color: KuwrirColors.border),
                      _ActionRow(
                        icon: HugeIcons.strokeRoundedSettings01,
                        label: 'Pengaturan',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const SettingsScreen(),
                          ),
                        ),
                      ),
                    ],
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

/// Leading icon chip shared by every row on this screen — icon renders at
/// HugeIcon's own default size (24px), box sized to fit it comfortably.
class _RowIcon extends StatelessWidget {
  final List<List<dynamic>> icon;
  final Color color;
  const _RowIcon({required this.icon, required this.color});

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

class _ProfileRow extends StatelessWidget {
  final List<List<dynamic>> icon;
  final String label;
  final String value;
  final VoidCallback? onTap;
  const _ProfileRow({
    required this.icon,
    required this.label,
    required this.value,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: _RowIcon(icon: icon, color: KuwrirColors.primary),
      title: Text(
        label,
        style: const TextStyle(fontSize: 13, color: KuwrirColors.textSecondary),
      ),
      subtitle: Text(
        value,
        style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600),
      ),
      trailing: onTap != null
          ? HugeIcon(
              icon: HugeIcons.strokeRoundedEdit02,
              size: 18,
              color: KuwrirColors.textHint,
            )
          : null,
      onTap: onTap,
    );
  }
}

/// Simple navigational/action row (wallet, settings) — label only, no
/// value subtitle, chevron trailing.
class _ActionRow extends StatelessWidget {
  final List<List<dynamic>> icon;
  final String label;
  final VoidCallback onTap;
  const _ActionRow({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: _RowIcon(icon: icon, color: KuwrirColors.primary),
      title: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5),
      ),
      trailing: HugeIcon(
        icon: HugeIcons.strokeRoundedArrowRight01,
        size: 18,
        color: KuwrirColors.textHint,
      ),
      onTap: onTap,
    );
  }
}
