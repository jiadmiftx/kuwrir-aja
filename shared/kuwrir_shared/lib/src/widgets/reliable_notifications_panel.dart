import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../services/power_permission_service.dart';
import '../theme/kuwrir_colors.dart';

/// Profile-screen section that surfaces the three OS-level settings a
/// backgrounded/killed push actually depends on to reach the user reliably
/// (see driver_app/merchant_app NotificationService docs): notification
/// permission itself is already requested on app start elsewhere, so this
/// covers the rest — battery-optimization exemption and the Android 14+
/// full-screen-intent permission (both checkable, both one-tap fixable via
/// [PowerPermissionService]), plus OEM autostart allow-listing (not
/// checkable — no public API — so that row is just a jump-off point with
/// per-brand instructions).
///
/// Android-only in effect: [PowerPermissionService] reports every status as
/// already-fine on other platforms, so this renders as an all-green,
/// action-free panel there rather than something meaningless to show.
class ReliableNotificationsPanel extends StatefulWidget {
  /// Only meaningful for an app that actually posts a full-screen-intent
  /// notification somewhere (the merchant new-order alarm does; driver_app
  /// deliberately doesn't — see AssignDriverToOrder's comment on why a
  /// plain push was chosen there). Showing this row for an app that never
  /// uses the permission would just be a confusing, no-op toggle.
  final bool showFullScreenIntentRow;

  const ReliableNotificationsPanel({
    super.key,
    this.showFullScreenIntentRow = true,
  });

  @override
  State<ReliableNotificationsPanel> createState() =>
      _ReliableNotificationsPanelState();
}

class _ReliableNotificationsPanelState
    extends State<ReliableNotificationsPanel>
    with WidgetsBindingObserver {
  bool? _batteryOk;
  bool? _fullScreenOk;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// The battery/full-screen-intent fixes both hand off to a system
  /// Settings screen — this is what picks the result back up once the user
  /// returns to the app, instead of leaving a stale ❌ showing after they
  /// actually granted it.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    final results = await Future.wait([
      PowerPermissionService.isIgnoringBatteryOptimizations(),
      PowerPermissionService.canUseFullScreenIntent(),
    ]);
    if (!mounted) return;
    setState(() {
      _batteryOk = results[0];
      _fullScreenOk = results[1];
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'NOTIFIKASI ANDAL',
          style: const TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
            color: KuwrirColors.textHint,
          ),
        ),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text(
            'Beberapa HP (Xiaomi, Oppo, Vivo, Samsung, dll) mematikan '
            'notifikasi saat aplikasi tidak dibuka. Aktifkan pengaturan ini '
            'supaya kamu tidak ketinggalan tugas.',
            style: TextStyle(fontSize: 11.5, color: KuwrirColors.textHint),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: KuwrirColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: KuwrirColors.border),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              _PermissionRow(
                icon: HugeIcons.strokeRoundedBatteryFull,
                label: 'Baterai: Tanpa Batasan',
                ok: _batteryOk,
                actionLabel: 'Aktifkan',
                onTap: () async {
                  await PowerPermissionService.requestIgnoreBatteryOptimizations();
                  _refresh();
                },
              ),
              if (widget.showFullScreenIntentRow) ...[
                Divider(height: 1, color: KuwrirColors.border),
                _PermissionRow(
                  icon: HugeIcons.strokeRoundedFullScreen,
                  label: 'Notifikasi Layar Penuh',
                  subtitle: 'Android 14 ke atas',
                  ok: _fullScreenOk,
                  actionLabel: 'Aktifkan',
                  onTap: () async {
                    await PowerPermissionService.requestFullScreenIntentPermission();
                    _refresh();
                  },
                ),
              ],
              Divider(height: 1, color: KuwrirColors.border),
              _PermissionRow(
                icon: HugeIcons.strokeRoundedPower,
                label: 'Izinkan Berjalan di Background',
                subtitle: 'Khusus Xiaomi/Oppo/Vivo/Samsung dll',
                ok: null, // not checkable — no public OS API
                actionLabel: 'Buka Pengaturan',
                onTap: PowerPermissionService.openAutostartSettings,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PermissionRow extends StatelessWidget {
  final List<List<dynamic>> icon;
  final String label;
  final String? subtitle;
  final bool? ok; // null = not checkable
  final String actionLabel;
  final VoidCallback onTap;

  const _PermissionRow({
    required this.icon,
    required this.label,
    this.subtitle,
    required this.ok,
    required this.actionLabel,
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
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        subtitle ?? (ok == null ? 'Tidak bisa dicek otomatis' : ''),
        style: TextStyle(fontSize: 11.5, color: KuwrirColors.textHint),
      ),
      trailing: ok == true
          ? HugeIcon(
              icon: HugeIcons.strokeRoundedCheckmarkCircle02,
              color: KuwrirColors.success,
              size: 20,
            )
          : TextButton(
              onPressed: onTap,
              child: Text(
                actionLabel,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
    );
  }
}
