import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'stats_service.dart';

/// Volledig overzicht van alle badges, geopend via "Bekijk alles" op het
/// profiel. Layout gebaseerd op template/code.html (Mijn Prestaties),
/// gegroepeerd per categorie.
class AllBadgesPage extends StatelessWidget {
  const AllBadgesPage({super.key, required this.badges});

  final List<ProfileBadge> badges;

  static const _categoryOrder = ['evenement', 'cultureel', 'algemeen'];
  static const _categoryTitles = {
    'evenement': 'Evenement Badges',
    'cultureel': 'Culturele Verkenning',
    'algemeen': 'Algemene Prestaties',
  };

  @override
  Widget build(BuildContext context) {
    final byCategory = <String, List<ProfileBadge>>{};
    for (final badge in badges) {
      byCategory.putIfAbsent(badge.category, () => []).add(badge);
    }
    final categories = [
      ..._categoryOrder.where(byCategory.containsKey),
      ...byCategory.keys.where((c) => !_categoryOrder.contains(c)),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFF1E1712),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2C221C),
        foregroundColor: const Color(0xFFEFE6DD),
        elevation: 0,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          children: [
            Text(
              'Mijn Prestaties',
              style: GoogleFonts.playfairDisplay(
                color: const Color(0xFFEFE6DD),
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Verzamel unieke badges door bieren te ontdekken en locaties te bezoeken. '
              'Elke prestatie vertelt een verhaal van jouw zintuiglijke reis.',
              style: GoogleFonts.inter(
                color: const Color(0xFF9E8A7D),
                fontSize: 13,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            for (final category in categories) ...[
              _CategorySection(
                title: _categoryTitles[category] ?? category,
                badges: byCategory[category]!,
              ),
              const SizedBox(height: 24),
            ],
          ],
        ),
      ),
    );
  }
}

class _CategorySection extends StatelessWidget {
  const _CategorySection({required this.title, required this.badges});

  final String title;
  final List<ProfileBadge> badges;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.only(bottom: 8),
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(color: Color(0x4D51443A), width: 1),
            ),
          ),
          child: Text(
            title,
            style: GoogleFonts.playfairDisplay(
              color: const Color(0xFFD4B28C),
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: badges.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.72,
          ),
          itemBuilder: (context, index) => _BadgeCard(badge: badges[index]),
        ),
      ],
    );
  }
}

class _BadgeCard extends StatelessWidget {
  const _BadgeCard({required this.badge});

  final ProfileBadge badge;

  @override
  Widget build(BuildContext context) {
    final earned = badge.earned;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF2C221C),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: earned
              ? const Color(0xFFD4B28C).withOpacity(0.25)
              : Colors.transparent,
        ),
      ),
      child: Column(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              ClipOval(
                child: badge.imageAsset != null
                    ? (earned
                        ? Image.asset(
                            'assets/badges/${badge.imageAsset}.png',
                            width: 72,
                            height: 72,
                            fit: BoxFit.cover,
                          )
                        : ColorFiltered(
                            colorFilter: const ColorFilter.matrix(<double>[
                              0.2126, 0.7152, 0.0722, 0, 0,
                              0.2126, 0.7152, 0.0722, 0, 0,
                              0.2126, 0.7152, 0.0722, 0, 0,
                              0, 0, 0, 1, 0,
                            ]),
                            child: Opacity(
                              opacity: 0.5,
                              child: Image.asset(
                                'assets/badges/${badge.imageAsset}.png',
                                width: 72,
                                height: 72,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ))
                    : Container(
                        width: 72,
                        height: 72,
                        color: const Color(0xFF3C3028),
                        child: Icon(
                          earned ? badge.icon : Icons.lock_outline,
                          color: earned
                              ? const Color(0xFFD4B28C)
                              : const Color(0xFF6B5D50),
                          size: 28,
                        ),
                      ),
              ),
              if (!earned)
                Container(
                  width: 72,
                  height: 72,
                  decoration: const BoxDecoration(
                    color: Colors.black26,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.lock_outline, color: Color(0xFFEFE6DD), size: 22),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            badge.title,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.playfairDisplay(
              color: earned ? const Color(0xFFD4B28C) : const Color(0xFFEFE6DD),
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: Text(
              badge.description,
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                color: const Color(0xFF9E8A7D),
                fontSize: 11,
                height: 1.3,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                earned ? Icons.verified : Icons.lock_clock,
                size: 14,
                color: earned ? const Color(0xFFD4B28C) : const Color(0xFF6B5D50),
              ),
              const SizedBox(width: 4),
              Text(
                earned ? 'BEHAALD' : 'VERGRENDELD',
                style: GoogleFonts.inter(
                  color: earned ? const Color(0xFFD4B28C) : const Color(0xFF6B5D50),
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
