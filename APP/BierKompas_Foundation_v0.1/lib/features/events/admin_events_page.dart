import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'event_create.dart';

const _bg = Color(0xFF1E1712);
const _card = Color(0xFF2C221C);
const _input = Color(0xFF17110D);
const _gold = Color(0xFFD4B28C);
const _cream = Color(0xFFEFE6DD);
const _muted = Color(0xFF9E8A7D);
const _border = Color(0xFF3C3028);

/// Beheerscherm voor evenementen: nog niet goedgekeurde evenementen
/// goedkeuren of afwijzen, en bestaande evenementen bewerken. Alleen
/// bereikbaar als de ingelogde gebruiker `is_admin = true` heeft (zowel hier
/// als in de RLS/RPC's op de database gecontroleerd — deze pagina is puur
/// UI-gemak, geen beveiliging).
class AdminEventsPage extends StatefulWidget {
  const AdminEventsPage({super.key});

  @override
  State<AdminEventsPage> createState() => _AdminEventsPageState();
}

class _AdminEventsPageState extends State<AdminEventsPage> {
  final _supabase = Supabase.instance.client;
  final _searchController = TextEditingController();

  /// 'pending' = wacht op goedkeuring, 'approved' = gepubliceerd.
  String _status = 'pending';
  List<Map<String, dynamic>>? _events;
  final Set<int> _busyIds = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final status = _status;
    try {
      final rows = status == 'pending'
          ? await _supabase.from('events').select().eq('status', 'pending').order('created_at')
          : await _supabase
              .from('events')
              .select()
              .eq('status', 'approved')
              .order('start_date', ascending: false)
              .limit(1000);
      if (!mounted || status != _status) return;
      setState(() => _events = List<Map<String, dynamic>>.from(rows));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ophalen mislukt: $e')),
      );
    }
  }

  void _switchTo(String status) {
    if (status == _status) return;
    setState(() {
      _status = status;
      _events = null;
    });
    _load();
  }

  List<Map<String, dynamic>> get _visibleEvents {
    final query = _searchController.text.trim().toLowerCase();
    final events = _events ?? const [];
    if (query.isEmpty) return events;
    return events.where((e) {
      final haystack = '${e['name'] ?? ''} ${e['city'] ?? ''} ${e['location_name'] ?? ''}'.toLowerCase();
      return haystack.contains(query);
    }).toList();
  }

  Future<void> _edit(Map<String, dynamic> event) async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => EventCreatePage(existingEvent: event)),
    );
    if (saved == true && mounted) _load();
  }

  Future<void> _approve(int id) async {
    setState(() => _busyIds.add(id));
    try {
      await _supabase.rpc('approve_event', params: {'p_event_id': id});
      if (!mounted) return;
      setState(() => _events?.removeWhere((e) => e['id'] == id));
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
    final reasonController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: _card,
        title: Text('Evenement afwijzen?', style: GoogleFonts.playfairDisplay(color: _cream, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'De indiener krijgt een bericht en ziet het evenement als afgewezen onder "Mijn evenementen".',
              style: GoogleFonts.inter(color: _cream, fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              maxLines: 3,
              style: GoogleFonts.inter(color: _cream, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Reden (optioneel)',
                hintStyle: GoogleFonts.inter(color: _muted, fontSize: 13),
              ),
            ),
          ],
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
    final reason = reasonController.text.trim();
    reasonController.dispose();
    if (confirmed != true) return;

    setState(() => _busyIds.add(id));
    try {
      await _supabase.rpc('reject_event', params: {'p_event_id': id, 'p_reason': reason.isEmpty ? null : reason});
      if (!mounted) return;
      setState(() => _events?.removeWhere((e) => e['id'] == id));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Afwijzen mislukt: $e')),
      );
    } finally {
      if (mounted) setState(() => _busyIds.remove(id));
    }
  }

  String _formatDate(Object? value) {
    final date = DateTime.tryParse(value?.toString() ?? '')?.toLocal();
    if (date == null) return '';
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(date.day)}-${two(date.month)}-${date.year} ${two(date.hour)}:${two(date.minute)}';
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
          'Evenementen beheren',
          style: GoogleFonts.playfairDisplay(color: _cream, fontSize: 20, fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Row(
                children: [
                  _tab('pending', 'Wachtend'),
                  const SizedBox(width: 8),
                  _tab('approved', 'Gepubliceerd'),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: TextField(
                controller: _searchController,
                onChanged: (_) => setState(() {}),
                style: GoogleFonts.inter(color: _cream, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Zoek op naam of plaats...',
                  hintStyle: GoogleFonts.inter(color: _muted, fontSize: 13),
                  prefixIcon: const Icon(Icons.search, color: _muted, size: 20),
                  filled: true,
                  fillColor: _input,
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _gold),
                  ),
                ),
              ),
            ),
            Expanded(child: _buildList()),
          ],
        ),
      ),
    );
  }

  Widget _tab(String status, String label) {
    final selected = _status == status;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => _switchTo(status),
      showCheckmark: false,
      backgroundColor: _card,
      selectedColor: _gold,
      side: BorderSide(color: selected ? _gold : _border),
      labelStyle: GoogleFonts.inter(
        color: selected ? _bg : _cream,
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildList() {
    if (_events == null) {
      return const Center(child: CircularProgressIndicator(color: _gold));
    }
    final events = _visibleEvents;
    if (events.isEmpty) {
      final message = _searchController.text.trim().isNotEmpty
          ? 'Geen evenementen gevonden.'
          : _status == 'pending'
              ? 'Geen evenementen die wachten op goedkeuring.'
              : 'Nog geen gepubliceerde evenementen.';
      return Center(
        child: Text(message, style: GoogleFonts.inter(color: _muted, fontSize: 13)),
      );
    }
    return RefreshIndicator(
      color: _gold,
      backgroundColor: _card,
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: events.length,
        itemBuilder: (context, index) => _buildCard(events[index]),
      ),
    );
  }

  Widget _buildCard(Map<String, dynamic> event) {
    final id = event['id'] as int;
    final busy = _busyIds.contains(id);
    final isPending = event['status'] == 'pending';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
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
          const SizedBox(height: 2),
          Text(
            _formatDate(event['start_date']),
            style: GoogleFonts.inter(color: _muted, fontSize: 12),
          ),
          const SizedBox(height: 8),
          Text(
            event['description']?.toString() ?? '',
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(color: _muted, fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 14),
          if (isPending) ...[
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
            const SizedBox(height: 10),
          ],
          SizedBox(
            width: double.infinity,
            height: 38,
            child: OutlinedButton.icon(
              onPressed: busy ? null : () => _edit(event),
              icon: const Icon(Icons.edit_outlined, size: 16, color: _gold),
              label: Text(
                'Bewerken',
                style: GoogleFonts.inter(color: _gold, fontSize: 13, fontWeight: FontWeight.bold),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: _gold),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
