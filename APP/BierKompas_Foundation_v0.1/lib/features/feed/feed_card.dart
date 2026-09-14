import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'feed_service.dart';

// Kleuren uit het "Artisanal Draught" design system (DESIGN.md).
const _primary = Color(0xFFFBB97B);
const _surfaceContainerLow = Color(0xFF251911);
const _surfaceContainer = Color(0xFF291D15);
const _onSurface = Color(0xFFF6DED1);
const _onSurfaceVariant = Color(0xFFD6C3B5);

const _months = ['jan', 'feb', 'mrt', 'apr', 'mei', 'jun', 'jul', 'aug', 'sep', 'okt', 'nov', 'dec'];

/// Het basistemplate voor elk feed-item. Label, icoon en de voetregel hangen af van
/// [FeedItem.type]; de rest van de kaart is voor alle soorten content gelijk.
class FeedCard extends StatelessWidget {
  final FeedItem item;
  final VoidCallback? onTap;
  final bool isFavorite;

  /// Toont een hartje rechtsboven als deze is meegegeven.
  final VoidCallback? onFavoriteTap;

  const FeedCard({
    super.key,
    required this.item,
    this.onTap,
    this.isFavorite = false,
    this.onFavoriteTap,
  });

  @override
  Widget build(BuildContext context) {
    final (label, icon) = switch (item.type) {
      FeedItemType.review => ('MINI-REVIEW', Icons.rate_review_outlined),
      FeedItemType.tip => ('BIERTIP', Icons.lightbulb_outline),
      FeedItemType.weetje => ('WEETJE', Icons.auto_stories_outlined),
      FeedItemType.brouwerij => ('BROUWERIJ', Icons.factory_outlined),
      FeedItemType.evenement => ('EVENEMENT', Icons.event_outlined),
    };
    final imageUrl = item.imageUrl;
    final footer = _buildFooter();

    final card = Container(
      decoration: BoxDecoration(
        color: _surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _primary.withOpacity(0.1)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (imageUrl != null)
            AspectRatio(
              aspectRatio: 16 / 9,
              child: CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.cover,
                fadeInDuration: const Duration(milliseconds: 200),
                placeholder: (context, url) => Container(color: _surfaceContainer),
                errorWidget: (context, url, error) => Container(
                  color: _surfaceContainer,
                  child: Icon(Icons.image_outlined, color: _onSurfaceVariant.withOpacity(0.4), size: 40),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _buildLabel(label, icon),
                    const Spacer(),
                    if (onFavoriteTap != null)
                      GestureDetector(
                        onTap: onFavoriteTap,
                        behavior: HitTestBehavior.opaque,
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: Icon(
                            isFavorite ? Icons.favorite : Icons.favorite_border,
                            color: isFavorite ? _primary : _onSurfaceVariant,
                            size: 22,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  item.title,
                  style: GoogleFonts.playfairDisplay(
                    color: _onSurface,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  item.body,
                  style: GoogleFonts.openSans(color: _onSurfaceVariant, fontSize: 14, height: 1.5),
                ),
                if (footer != null) ...[
                  const SizedBox(height: 12),
                  footer,
                ],
              ],
            ),
          ),
        ],
      ),
    );

    return onTap == null ? card : GestureDetector(onTap: onTap, child: card);
  }

  Widget _buildLabel(String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: _primary, size: 14),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.openSans(
              color: _primary,
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget? _buildFooter() {
    final metaStyle = GoogleFonts.openSans(color: _onSurfaceVariant, fontSize: 12);
    switch (item.type) {
      case FeedItemType.review:
        final rating = item.rating ?? 0;
        final author = item.author;
        return Row(
          children: [
            for (var i = 1; i <= 5; i++)
              Icon(
                i <= rating ? Icons.star : (i - 0.5 <= rating ? Icons.star_half : Icons.star_border),
                color: _primary,
                size: 16,
              ),
            if (author != null) ...[
              const SizedBox(width: 8),
              Flexible(child: Text(author, style: metaStyle, overflow: TextOverflow.ellipsis)),
            ],
          ],
        );
      case FeedItemType.evenement:
        final parts = [
          if (item.eventStart != null) _formatDate(item.eventStart!),
          if (item.eventLocation != null) item.eventLocation!,
        ];
        if (parts.isEmpty) return null;
        return Row(
          children: [
            const Icon(Icons.calendar_today_outlined, color: _primary, size: 14),
            const SizedBox(width: 8),
            Expanded(child: Text(parts.join(' • '), style: metaStyle)),
          ],
        );
      case FeedItemType.tip:
      case FeedItemType.weetje:
      case FeedItemType.brouwerij:
        final author = item.author;
        return author == null ? null : Text(author, style: metaStyle);
    }
  }

  static String _formatDate(DateTime date) {
    final local = date.toLocal();
    return '${local.day} ${_months[local.month - 1]} ${local.year}';
  }
}
