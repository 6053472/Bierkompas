import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'notifications_service.dart';

const _background = Color(0xFF1E1712);
const _cardColor = Color(0xFF2C221C);
const _primary = Color(0xFFD4B28C);
const _onSurface = Color(0xFFEFE6DD);
const _onSurfaceVariant = Color(0xFF9E8A7D);
const _outlineVariant = Color(0xFF3E312A);

const _months = ['jan', 'feb', 'mrt', 'apr', 'mei', 'jun', 'jul', 'aug', 'sep', 'okt', 'nov', 'dec'];

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final _service = NotificationsService();
  late Future<List<AppNotification>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<AppNotification>> _load() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return const [];
    return _service.fetchAll(userId);
  }

  Future<void> _openNotification(AppNotification notification) async {
    if (!notification.isRead) {
      try {
        await _service.markRead(notification.id);
        setState(() => _future = _load());
      } catch (_) {
        // Negeren: gelezen-status is niet kritiek.
      }
    }
  }

  String _formatDate(DateTime date) {
    final local = date.toLocal();
    return '${local.day} ${_months[local.month - 1]} ${local.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: _cardColor,
        foregroundColor: _onSurface,
        iconTheme: const IconThemeData(color: _onSurface),
        elevation: 0,
        title: Text('Berichten', style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.bold)),
      ),
      body: SafeArea(
        child: FutureBuilder<List<AppNotification>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator(color: _primary));
            }
            final notifications = snapshot.data ?? const [];
            if (notifications.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.notifications_none, color: _onSurfaceVariant.withOpacity(0.5), size: 48),
                      const SizedBox(height: 12),
                      Text('Nog geen berichten.', style: GoogleFonts.openSans(color: _onSurfaceVariant)),
                    ],
                  ),
                ),
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: notifications.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final notification = notifications[index];
                return GestureDetector(
                  onTap: () => _openNotification(notification),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _cardColor,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: notification.isRead ? _outlineVariant.withOpacity(0.5) : _primary.withOpacity(0.5),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (!notification.isRead)
                          Padding(
                            padding: const EdgeInsets.only(top: 6, right: 10),
                            child: Container(width: 8, height: 8, decoration: const BoxDecoration(color: _primary, shape: BoxShape.circle)),
                          ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(notification.title,
                                  style: GoogleFonts.playfairDisplay(color: _onSurface, fontSize: 15, fontWeight: FontWeight.w600)),
                              const SizedBox(height: 4),
                              Text(notification.body, style: GoogleFonts.openSans(color: _onSurfaceVariant, fontSize: 13, height: 1.4)),
                              const SizedBox(height: 6),
                              Text(_formatDate(notification.createdAt),
                                  style: GoogleFonts.openSans(color: _onSurfaceVariant.withOpacity(0.7), fontSize: 11)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
