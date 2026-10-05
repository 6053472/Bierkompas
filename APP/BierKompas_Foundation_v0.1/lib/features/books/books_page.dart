import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../shared/share_sheet.dart';
import 'books.dart';

const _background = Color(0xFF1E1712);
const _cardColor = Color(0xFF2C221C);
const _primary = Color(0xFFD4B28C);
const _onPrimary = Color(0xFF1E1712);
const _onSurface = Color(0xFFEFE6DD);
const _onSurfaceVariant = Color(0xFF9E8A7D);
const _outline = Color(0xFF3E312A);

enum _Filter { all, reading, toRead, finished }

/// "Mijn Leeslijst": de boeken uit de Bierkompas-bibliotheek met per boek een
/// leesstatus (design: bierkompas paginas/boeken/mijn_persoonlijke_leeslijst).
class BooksPage extends StatefulWidget {
  const BooksPage({super.key});

  @override
  State<BooksPage> createState() => _BooksPageState();
}

class _BooksPageState extends State<BooksPage> {
  final _store = BookStatusStore();
  Map<String, BookStatus> _statuses = {};
  _Filter _filter = _Filter.all;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final statuses = await _store.load();
    if (!mounted) return;
    setState(() => _statuses = statuses);
  }

  BookStatus _statusOf(Book book) => _statuses[book.id] ?? BookStatus.toRead;

  Future<void> _setStatus(Book book, BookStatus status) async {
    setState(() => _statuses = {..._statuses, book.id: status});
    await _store.save(book.id, status);
  }

  List<Book> get _visibleBooks {
    switch (_filter) {
      case _Filter.all:
        return books;
      case _Filter.reading:
        return books.where((b) => _statusOf(b) == BookStatus.reading).toList();
      case _Filter.toRead:
        return books.where((b) => _statusOf(b) == BookStatus.toRead).toList();
      case _Filter.finished:
        return books.where((b) => _statusOf(b) == BookStatus.finished).toList();
    }
  }

  Future<void> _openBook(Book book) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: _cardColor,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetContext) => _BookSheet(
        book: book,
        status: _statusOf(book),
        onStatusChanged: (status) => _setStatus(book, status),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final reading = books.where((b) => _statusOf(b) == BookStatus.reading).toList();
    final finishedCount = books.where((b) => _statusOf(b) == BookStatus.finished).length;
    final visible = _visibleBooks;

    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: _cardColor,
        elevation: 0,
        iconTheme: const IconThemeData(color: _onSurface),
        title: Text('Boeken', style: GoogleFonts.playfairDisplay(color: _onSurface, fontSize: 20, fontWeight: FontWeight.bold)),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
          children: [
            Text(
              'COLLECTIE',
              style: GoogleFonts.openSans(color: _primary, fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: 2.6),
            ),
            const SizedBox(height: 8),
            Text(
              'Mijn Leeslijst',
              style: GoogleFonts.playfairDisplay(color: _onSurface, fontSize: 32, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 20),
            _buildFilters(),
            const SizedBox(height: 20),
            if (reading.isNotEmpty && _filter == _Filter.all) ...[
              for (final book in reading) ...[
                _buildReadingCard(book),
                const SizedBox(height: 16),
              ],
            ],
            _buildStatsCard(finishedCount),
            const SizedBox(height: 28),
            Row(
              children: [
                const Icon(Icons.bookmark_outline, color: _primary),
                const SizedBox(width: 8),
                Text('Boeken', style: GoogleFonts.playfairDisplay(color: _onSurface, fontSize: 20, fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 16),
            if (visible.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  'Geen boeken in deze lijst.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.openSans(color: _onSurfaceVariant, fontSize: 14),
                ),
              )
            else
              GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 20,
                childAspectRatio: 0.52,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: [for (final book in visible) _buildBookTile(book)],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilters() {
    const labels = {
      _Filter.all: 'Alle Boeken',
      _Filter.reading: 'Aan het lezen',
      _Filter.toRead: 'Nog te lezen',
      _Filter.finished: 'Voltooid',
    };
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final filter in _Filter.values) ...[
            GestureDetector(
              onTap: () => setState(() => _filter = filter),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                decoration: BoxDecoration(
                  color: _filter == filter ? _primary.withOpacity(0.18) : _cardColor,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: _filter == filter ? _primary.withOpacity(0.5) : _outline),
                ),
                child: Text(
                  labels[filter]!,
                  style: GoogleFonts.openSans(
                    color: _filter == filter ? _primary : _onSurfaceVariant,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
          ],
        ],
      ),
    );
  }

  Widget _buildReadingCard(Book book) {
    return GestureDetector(
      onTap: () => _openBook(book),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _primary.withOpacity(0.25)),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset(book.coverAsset, width: 84, height: 112, fit: BoxFit.cover, cacheWidth: 300),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: _primary.withOpacity(0.18), borderRadius: BorderRadius.circular(999)),
                    child: Text('Nu aan het lezen', style: GoogleFonts.openSans(color: _primary, fontSize: 11, fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(height: 10),
                  Text(book.title, style: GoogleFonts.playfairDisplay(color: _onSurface, fontSize: 18, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text('Door ${book.author}', style: GoogleFonts.openSans(color: _onSurfaceVariant, fontSize: 13)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsCard(int finishedCount) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _primary.withOpacity(0.15)),
      ),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(color: _primary.withOpacity(0.12), shape: BoxShape.circle),
            child: const Icon(Icons.menu_book_outlined, color: _primary, size: 28),
          ),
          const SizedBox(height: 12),
          Text('Je Bibliotheek', style: GoogleFonts.playfairDisplay(color: _onSurface, fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _statBox('${books.length}', 'Boeken')),
              const SizedBox(width: 12),
              Expanded(child: _statBox('$finishedCount', 'Gelezen')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statBox(String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(color: _background, borderRadius: BorderRadius.circular(12), border: Border.all(color: _outline)),
      child: Column(
        children: [
          Text(value, style: GoogleFonts.openSans(color: _primary, fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text(label, style: GoogleFonts.openSans(color: _onSurfaceVariant, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildBookTile(Book book) {
    final status = _statusOf(book);
    return GestureDetector(
      onTap: () => _openBook(book),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _outline),
                boxShadow: [BoxShadow(color: _primary.withOpacity(0.08), blurRadius: 16)],
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(book.coverAsset, fit: BoxFit.cover, cacheWidth: 500),
                  Positioned(
                    left: 8,
                    bottom: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: status == BookStatus.finished ? _onSurfaceVariant : _cardColor.withOpacity(0.92),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        status.label.toUpperCase(),
                        style: GoogleFonts.openSans(
                          color: status == BookStatus.finished ? _onPrimary : _primary,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(book.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: GoogleFonts.openSans(color: _onSurface, fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(book.author, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.openSans(color: _onSurfaceVariant, fontSize: 12)),
        ],
      ),
    );
  }
}

/// Detail van een boek met de leesstatus (design: boeken/boek_gedeeld_melding).
class _BookSheet extends StatefulWidget {
  const _BookSheet({required this.book, required this.status, required this.onStatusChanged});

  final Book book;
  final BookStatus status;
  final ValueChanged<BookStatus> onStatusChanged;

  @override
  State<_BookSheet> createState() => _BookSheetState();
}

class _BookSheetState extends State<_BookSheet> {
  late BookStatus _status = widget.status;

  void _select(BookStatus status) {
    setState(() => _status = status);
    widget.onStatusChanged(status);
  }

  @override
  Widget build(BuildContext context) {
    final book = widget.book;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.asset(book.coverAsset, height: 260, fit: BoxFit.cover, cacheHeight: 800),
              ),
            ),
            const SizedBox(height: 20),
            Text(book.title, style: GoogleFonts.playfairDisplay(color: _onSurface, fontSize: 22, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text('Door ${book.author}', style: GoogleFonts.openSans(color: _onSurfaceVariant, fontSize: 14)),
            if (book.subtitle != null) ...[
              const SizedBox(height: 12),
              Text(book.subtitle!, style: GoogleFonts.openSans(color: _onSurface, fontSize: 14, height: 1.5)),
            ],
            const SizedBox(height: 20),
            Text('LEESSTATUS', style: GoogleFonts.openSans(color: _primary, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 2)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final status in BookStatus.values)
                  GestureDetector(
                    onTap: () => _select(status),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                      decoration: BoxDecoration(
                        color: _status == status ? _primary : _background,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: _status == status ? _primary : _outline),
                      ),
                      child: Text(
                        status.label,
                        style: GoogleFonts.openSans(
                          color: _status == status ? _onPrimary : _onSurfaceVariant,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => showAppShareSheet(
                  context,
                  shareText: '${book.title} van ${book.author}\n\nBekijk het in Bierkompas! \u{1F37B}',
                  subject: book.title,
                  title: 'Boek delen',
                  onShared: recordBadgeShareAction,
                ),
                icon: const Icon(Icons.ios_share, color: _primary, size: 18),
                label: Text('Delen', style: GoogleFonts.openSans(color: _primary, fontWeight: FontWeight.bold)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: _primary),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
