import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:kuwrir_shared/kuwrir_shared.dart';

import '../screens/delivery_history_screen.dart';
import '../screens/notifications_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/stats_screen.dart';
import '../screens/support_chat_screen.dart';

/// Single navigation surface for everything outside Job Board itself — the
/// one screen a driver actually watches while riding stays uncluttered, and
/// every secondary menu (checked occasionally, not constantly) lives one
/// swipe away instead of two taps deep inside Profile.
class DriverDrawer extends StatefulWidget {
  const DriverDrawer({super.key});

  @override
  State<DriverDrawer> createState() => _DriverDrawerState();
}

class _DriverDrawerState extends State<DriverDrawer> {
  User? _user;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      _user = await ApiClient().getMe();
    } catch (_) {
      // Best-effort — header falls back to placeholder text.
    }
    if (mounted) setState(() {});
  }

  void _openScreen(Widget screen) {
    Navigator.pop(context);
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: KuwrirColors.background,
      child: SafeArea(
        child: Column(
          children: [
            InkWell(
              onTap: () => _openScreen(const ProfileScreen()),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: KuwrirColors.primary.withValues(
                        alpha: 0.08,
                      ),
                      child: HugeIcon(
                        icon: HugeIcons.strokeRoundedUser,
                        size: 28,
                        color: KuwrirColors.primary,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _user?.name.isNotEmpty == true
                                ? _user!.name
                                : 'Tanpa nama',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
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
                    HugeIcon(
                      icon: HugeIcons.strokeRoundedArrowRight01,
                      size: 18,
                      color: KuwrirColors.textHint,
                    ),
                  ],
                ),
              ),
            ),
            Divider(height: 1, color: KuwrirColors.border),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  _DrawerRow(
                    icon: HugeIcons.strokeRoundedWallet01,
                    label: 'Wallet Driver',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, '/wallet');
                    },
                  ),
                  _DrawerRow(
                    icon: HugeIcons.strokeRoundedClock01,
                    label: 'Riwayat Pengantaran',
                    onTap: () => _openScreen(const DeliveryHistoryScreen()),
                  ),
                  _DrawerRow(
                    icon: HugeIcons.strokeRoundedChartLineData02,
                    label: 'Statistik & Performa',
                    onTap: () => _openScreen(const StatsScreen()),
                  ),
                  _DrawerRow(
                    icon: HugeIcons.strokeRoundedCustomerService01,
                    label: 'Pusat Bantuan',
                    onTap: () => _openScreen(const SupportChatScreen()),
                  ),
                  _DrawerRow(
                    icon: HugeIcons.strokeRoundedNotification03,
                    label: 'Notifikasi',
                    onTap: () => _openScreen(const NotificationsScreen()),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Divider(height: 1),
                  ),
                  _DrawerRow(
                    icon: HugeIcons.strokeRoundedSettings01,
                    label: 'Pengaturan',
                    onTap: () => _openScreen(const SettingsScreen()),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DrawerRow extends StatelessWidget {
  final List<List<dynamic>> icon;
  final String label;
  final VoidCallback onTap;
  const _DrawerRow({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: KuwrirColors.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(9),
        ),
        child: HugeIcon(icon: icon, color: KuwrirColors.primary),
      ),
      title: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5),
      ),
      onTap: onTap,
    );
  }
}
