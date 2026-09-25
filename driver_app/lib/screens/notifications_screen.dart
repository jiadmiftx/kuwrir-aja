import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:kuwrir_shared/kuwrir_shared.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<Map<String, dynamic>> _notifications = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      _notifications = await ApiClient().getMyNotifications();
    } catch (_) {
      // Best-effort — show whatever loaded, empty state otherwise.
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _markRead(Map<String, dynamic> n) async {
    if (n['is_read'] == true) return;
    setState(() => n['is_read'] = true);
    try {
      await ApiClient().markNotificationRead(n['id'] as String);
    } catch (_) {
      // Not critical if this fails silently — worst case it re-shows as unread.
    }
  }

  String _fmtTime(String? iso) {
    if (iso == null) return '';
    final d = DateTime.tryParse(iso);
    if (d == null) return '';
    final diff = DateTime.now().difference(d);
    if (diff.inMinutes < 1) return 'Baru saja';
    if (diff.inMinutes < 60) return '${diff.inMinutes} menit lalu';
    if (diff.inHours < 24) return '${diff.inHours} jam lalu';
    return '${diff.inDays} hari lalu';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KuwrirColors.background,
      appBar: AppBar(
        title: const Text('Notifikasi'),
        backgroundColor: KuwrirColors.background,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _notifications.isEmpty
          ? RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                children: [
                  const SizedBox(height: 140),
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Column(
                        children: [
                          Container(
                            width: 88,
                            height: 88,
                            decoration: BoxDecoration(
                              color: KuwrirColors.primary.withValues(
                                alpha: 0.08,
                              ),
                              shape: BoxShape.circle,
                            ),
                            child: HugeIcon(
                              icon: HugeIcons.strokeRoundedNotification03,
                              size: 36,
                              color: KuwrirColors.primary,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'Belum ada notifikasi',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                              color: KuwrirColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: _notifications.length,
                separatorBuilder: (_, __) =>
                    Divider(height: 1, color: KuwrirColors.border),
                itemBuilder: (context, i) {
                  final n = _notifications[i];
                  final isRead = n['is_read'] == true;
                  return ListTile(
                    onTap: () => _markRead(n),
                    leading: Container(
                      width: 10,
                      height: 10,
                      margin: const EdgeInsets.only(top: 4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isRead
                            ? Colors.transparent
                            : KuwrirColors.primary,
                      ),
                    ),
                    title: Text(
                      n['title'] as String? ?? '',
                      style: TextStyle(
                        fontWeight: isRead ? FontWeight.w500 : FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          n['body'] as String? ?? '',
                          style: TextStyle(
                            fontSize: 13,
                            color: KuwrirColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _fmtTime(n['created_at'] as String?),
                          style: TextStyle(
                            fontSize: 11,
                            color: KuwrirColors.textHint,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
    );
  }
}
