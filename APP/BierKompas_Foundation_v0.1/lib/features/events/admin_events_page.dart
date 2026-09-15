import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _bg = Color(0xFF1E1712);
const _card = Color(0xFF2C221C);
const _gold = Color(0xFFD4B28C);
const _cream = Color(0xFFEFE6DD);
const _muted = Color(0xFF9E8A7D);

/// Simpel beheerscherm: toont nog niet goedgekeurde evenementen en laat een
/// beheerder ze goedkeuren of afwijzen. Alleen bereikbaar als de ingelogde
/// gebruiker `is_admin = true` heeft (zowel hier als in de RLS/RPC's op de
/// database gecontroleerd — deze pagina is puur UI-gemak, geen beveiliging).
class AdminEventsPage extends StatefulWidget {
  const AdminEventsPage({super.key});

  @override
  State<AdminEventsPage> createState() => _AdminEventsPageState();
}

class _AdminEventsPageState extends State<AdminEventsPage> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>>? _pendingEvents;
  final Set<int> _busyIds = {};

  @override
  void initState() {
    super.initState();
    _loadPending();
  }

  Future<void> _loadPending() async {
    try {
      final rows = await _supabase
          .from('events')
          .select()
          .eq('status', 'pending')
          .order('created_at');
      if (!mounted) return;
      setState(() => _pendingEvents = List<Map<String, dynamic>>.from(rows));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ophalen mislukt: $e')),
      );
    }
  }

  Future<void> _approve(int id) async {
    setState(() => _busyIds.add(id));
    try {
      await _supabase.rpc('approve_event', params: {'p_event_id': id});
      if (!mounted) return;
      setState(() => _pendingEvents?.removeWhere((e) => e['id'] == id));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Evenement goedgekeurd.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Goedkeuren mislukt: $e')),
      );
    } finally {
      if (mounted) setState(() => _busyIds.remove(id));
    }
  }

  Future<void> _reject(int id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: _card,
        title: Text('Evenement afwijzen?', style: GoogleFonts.playfairDisplay(color: _cream, fontWeight: FontWeight.bold)),
        content: Text(
          'Het evenement wordt permanent verwijderd (het is nog nooit gepubliceerd geweest).',
          style: GoogleFonts.inter(color: _cream, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text('Annuleren', style: GoogleFonts.inter(color: _muted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text('Afwijzen', style: GoogleFonts.inter(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _busyIds.add(id));
    try {
      await _supabase.rpc('reject_event', params: {'p_event_id': id});
      if (!mounted) return;
      setState(() => _pendingEvents?.removeWhere((e) => e['id'] == id));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Afwijzen mislukt: $e')),
      );
    } finally {
      if (mounted) setState(() => _busyIds.remove(id));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _card,
        elevation: 0,
        iconTheme: const IconThemeData(color: _cream),
        title: Text(
          'Evenementen goedkeuren',
          style: GoogleFonts.playfairDisplay(color: _cream, fontSize: 20, fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: _pendingEvents == null
            ? const Center(child: CircularProgressIndicator(color: _gold))
            : _pendingEvents!.isEmpty
                ? Center(
                    child: Text(
                      'Geen evenementen die wachten op goedkeuring.',
                      style: GoogleFonts.inter(color: _muted, fontSize: 13),
                    ),
                  )
                : RefreshIndicator(
                    color: _gold,
                    backgroundColor: _card,
                    onRefresh: _loadPending,
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _pendingEvents!.length,
                      itemBuilder: (context, index) {
                        final event = _pendingEvents![index];
                        final id = event['id'] as int;
                        final busy = _busyIds.contains(id);
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: _card,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFF3C3028)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                event['name']?.toString() ?? 'Naamloos',
                                style: GoogleFonts.playfairDisplay(color: _cream, fontSize: 17, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${event['event_type'] ?? ''} • ${event['city'] ?? ''}',
                                style: GoogleFonts.inter(color: _gold, fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                event['description']?.toString() ?? '',
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(color: _muted, fontSize: 13, height: 1.4),
                              ),
                              const SizedBox(height: 14),
                              Row(
                                children: [
                                  Expanded(
                                    child: SizedBox(
                                      height: 38,
                                      child: ElevatedButton.icon(
                                        onPressed: busy ? null : () => _approve(id),
                                        icon: busy
                                            ? const SizedBox(
                                                width: 14,
                                                height: 14,
                                                child: CircularProgressIndicator(strokeWidth: 2, color: _bg),
                                              )
                                            : const Icon(Icons.check, size: 16),
                                        label: Text('Goedkeuren', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold)),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: _gold,
                                          foregroundColor: _bg,
                                          elevation: 0,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: SizedBox(
                                      height: 38,
                                      child: OutlinedButton.icon(
                                        onPressed: busy ? null : () => _reject(id),
                                        icon: const Icon(Icons.close, size: 16, color: Colors.redAccent),
                                        label: Text(
                                          'Afwijzen',
                                          style: GoogleFonts.inter(color: Colors.redAccent, fontSize: 13, fontWeight: FontWeight.bold),
                                        ),
                                        style: OutlinedButton.styleFrom(
                                          side: const BorderSide(color: Colors.redAccent),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
      ),
    );
  }
}
