import 'package:flutter/material.dart';
import 'package:kuwrir_shared/kuwrir_shared.dart';
import '../services/notification_service.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<AppNotification> _notifications = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final all = await NotificationService.getAll();
    if (!mounted) return;
    setState(() {
      _notifications = all;
      _loading = false;
    });
    // Opening the list is the read receipt — clears the homepage badge.
    await NotificationService.markAllRead();
  }

  String _timeAgo(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inMinutes < 1) return 'Baru saja';
    if (diff.inMinutes < 60) return '${diff.inMinutes} menit lalu';
    if (diff.inHours < 24) return '${diff.inHours} jam lalu';
    if (diff.inDays < 7) return '${diff.inDays} hari lalu';
    return '${t.day}/${t.month}/${t.year}';
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
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 88,
                          height: 88,
                          decoration: BoxDecoration(
                            color: KuwrirColors.primary.withValues(alpha: 0.08),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.notifications_none_rounded, size: 36, color: KuwrirColors.primary),
                        ),
                        const SizedBox(height: 20),
                        const Text('Belum ada notifikasi',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: KuwrirColors.textPrimary)),
                        const SizedBox(height: 6),
                        Text('Kabar pesanan dan promo akan muncul di sini',
                            style: TextStyle(color: KuwrirColors.textSecondary, fontSize: 13),
                            textAlign: TextAlign.center),
                      ],
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(20),
                  itemCount: _notifications.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) {
                    final n = _notifications[i];
                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: KuwrirColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: KuwrirColors.border),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: KuwrirColors.primary.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(Icons.notifications_outlined, color: KuwrirColors.primary, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(n.title,
                                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
                                    ),
                                    if (!n.read)
                                      Container(
                                        width: 7,
                                        height: 7,
                                        margin: const EdgeInsets.only(left: 6, top: 3),
                                        decoration: const BoxDecoration(
                                          color: KuwrirColors.primary,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 3),
                                Text(n.body,
                                    style: TextStyle(fontSize: 13, color: KuwrirColors.textSecondary, height: 1.35)),
                                const SizedBox(height: 6),
                                Text(_timeAgo(n.receivedAt),
                                    style: TextStyle(fontSize: 11, color: KuwrirColors.textHint)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}
