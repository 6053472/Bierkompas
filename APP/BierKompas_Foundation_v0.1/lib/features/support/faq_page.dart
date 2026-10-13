import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'faq_service.dart';

const _background = Color(0xFF1E1712);
const _cardColor = Color(0xFF2C221C);
const _primary = Color(0xFFD4B28C);
const _onSurface = Color(0xFFEFE6DD);
const _onSurfaceVariant = Color(0xFF9E8A7D);
const _outlineVariant = Color(0xFF3E312A);

/// Bierkompas Support: veelgestelde vragen per rubriek, doorzoekbaar.
/// Zie bierkompas paginas/veelgestelde_vragen_met_antwoorden_nl voor het ontwerp.
class FaqPage extends StatefulWidget {
  const FaqPage({super.key});

  @override
  State<FaqPage> createState() => _FaqPageState();
}

class _FaqPageState extends State<FaqPage> {
  final _service = FaqService();
  final _searchController = TextEditingController();
  late Future<List<FaqItem>> _future;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _future = _service.fetchAll();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _matches(FaqItem item) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return item.question.toLowerCase().contains(q) || item.answer.toLowerCase().contains(q);
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
        title: Text('Bierkompas Support', style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.bold)),
      ),
      body: SafeArea(
        child: FutureBuilder<List<FaqItem>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator(color: _primary));
            }
            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(
                    'Kon de veelgestelde vragen niet laden: ${snapshot.error}',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.openSans(color: _onSurfaceVariant),
                  ),
                ),
              );
            }

            final all = snapshot.data ?? const [];
            final visible = all.where(_matches).toList();

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                Text('Hoe kunnen we helpen?',
                    style: GoogleFonts.playfairDisplay(color: _onSurface, fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: _cardColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _outlineVariant),
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (v) => setState(() => _query = v),
                    style: GoogleFonts.openSans(color: _onSurface, fontSize: 15),
                    cursorColor: _primary,
                    decoration: InputDecoration(
                      hintText: 'Zoek op trefwoord...',
                      hintStyle: GoogleFonts.openSans(color: _onSurfaceVariant),
                      border: InputBorder.none,
                      icon: const Icon(Icons.search, color: _onSurfaceVariant),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                if (all.isEmpty)
                  _emptyMessage('Er zijn nog geen veelgestelde vragen toegevoegd.')
                else if (visible.isEmpty)
                  _emptyMessage('Geen vragen gevonden voor "$_query".')
                else
                  for (final (key, label) in faqCategories)
                    if (visible.any((i) => i.category == key))
                      _CategoryCard(
                        label: label,
                        items: visible.where((i) => i.category == key).toList(),
                        initiallyExpanded: _query.trim().isNotEmpty,
                      ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _emptyMessage(String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Text(text, textAlign: TextAlign.center, style: GoogleFonts.openSans(color: _onSurfaceVariant)),
      );
}

class _CategoryCard extends StatelessWidget {
  final String label;
  final List<FaqItem> items;
  final bool initiallyExpanded;

  const _CategoryCard({required this.label, required this.items, required this.initiallyExpanded});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _outlineVariant.withOpacity(0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
            child: Text(label,
                style: GoogleFonts.playfairDisplay(color: _primary, fontSize: 18, fontWeight: FontWeight.w600)),
          ),
          for (final item in items)
            Theme(
              data: Theme.of(context).copyWith(dividerColor: _outlineVariant.withOpacity(0.5)),
              child: ExpansionTile(
                // De sleutel zorgt dat de open/dicht-status opnieuw wordt
                // ingesteld zodra een zoekopdracht begint of stopt.
                key: ValueKey('${item.id}-$initiallyExpanded'),
                initiallyExpanded: initiallyExpanded,
                iconColor: _primary,
                collapsedIconColor: _primary,
                tilePadding: const EdgeInsets.symmetric(horizontal: 18),
                childrenPadding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
                expandedCrossAxisAlignment: CrossAxisAlignment.start,
                title: Text(item.question, style: GoogleFonts.openSans(color: _onSurface, fontSize: 14, fontWeight: FontWeight.w600)),
                children: [
                  Text(item.answer, style: GoogleFonts.openSans(color: _onSurfaceVariant, fontSize: 13, height: 1.5)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
