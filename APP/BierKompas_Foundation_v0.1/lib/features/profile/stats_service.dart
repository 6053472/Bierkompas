import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileBadge {
  final String id;
  final String title;
  final String description;
  final IconData icon;
  final String? imageAsset;
  final int requirementValue;
  final bool earned;
  final String category;

  /// Hoever de gebruiker al is richting [requirementValue], voor de
  /// voortgangsbalk. Null als dit (nog) niet te meten is (bv. badges die op
  /// een deelfunctie of beoordeling wachten die nog niet bestaat) -- dan
  /// toont de UI geen balk, alleen behaald/vergrendeld.
  final int? currentValue;

  const ProfileBadge({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    this.imageAsset,
    required this.requirementValue,
    required this.earned,
    this.category = 'algemeen',
    this.currentValue,
  });

  /// Voortgang tussen 0.0 en 1.0, of null als er geen meetbare voortgang is.
  double? get progress {
    if (earned) return 1.0;
    final current = currentValue;
    if (current == null || requirementValue <= 0) return null;
    return (current / requirementValue).clamp(0.0, 1.0);
  }
}

class ProfileStats {
  final int beersTasted;
  final int breweriesExplored;
  final int currentStreak;
  final int longestStreak;
  final List<ProfileBadge> badges;

  const ProfileStats({
    required this.beersTasted,
    required this.breweriesExplored,
    required this.currentStreak,
    required this.longestStreak,
    required this.badges,
  });

  int get earnedBadgeCount => badges.where((b) => b.earned).length;
}

const _iconsByName = {
  'local_fire_department': Icons.local_fire_department,
  'whatshot': Icons.whatshot,
  'military_tech': Icons.military_tech,
  'shield': Icons.shield,
  'local_florist': Icons.local_florist,
  'sports_bar': Icons.sports_bar,
  'bookmark': Icons.bookmark,
};

/// Resultaat van [StatsService.recordDailyActivity]: de bijgewerkte streak en
/// eventuele badges die net ontgrendeld zijn (leeg als er geen nieuwe zijn).
class DailyActivityResult {
  final int currentStreak;
  final int longestStreak;
  final List<String> newlyEarnedBadgeTitles;

  const DailyActivityResult({
    required this.currentStreak,
    required this.longestStreak,
    required this.newlyEarnedBadgeTitles,
  });
}

/// Praat met de Supabase-tabellen `badges`/`user_badges` en de
/// `record_daily_activity`-functie die de Bier Streak bijhoudt.
class StatsService {
  SupabaseClient get _client => Supabase.instance.client;

  /// Moet aangeroepen worden bij een relevante gebruikersactie (een bier
  /// beoordelen, een post plaatsen, een bier/brouwerij favorieten...). Werkt
  /// de streak bij en kent automatisch nieuwe streak-badges toe (7/30/100
  /// dagen), zie supabase/add_stats_and_badges.sql.
  Future<DailyActivityResult> recordDailyActivity(String userId) async {
    final rows = await _client.rpc('record_daily_activity', params: {'p_user_id': userId}) as List;
    final row = rows.first as Map<String, dynamic>;
    final newlyEarnedIds = (row['newly_earned_badges'] as List).cast<String>();

    var newlyEarnedTitles = <String>[];
    if (newlyEarnedIds.isNotEmpty) {
      final badgeRows = await _client.from('badges').select('title').inFilter('id', newlyEarnedIds);
      newlyEarnedTitles = (badgeRows as List).map((r) => r['title'] as String).toList();
    }

    return DailyActivityResult(
      currentStreak: row['current_streak'] as int,
      longestStreak: row['longest_streak'] as int,
      newlyEarnedBadgeTitles: newlyEarnedTitles,
    );
  }

  Future<int> fetchCurrentStreak(String userId) async {
    final profile = await _client.from('profiles').select('current_streak').eq('id', userId).maybeSingle();
    return profile?['current_streak'] as int? ?? 0;
  }

  Future<ProfileStats> fetchStats(String userId) async {
    final profile = await _client
        .from('profiles')
        .select('beers_tasted, breweries_explored, current_streak, longest_streak')
        .eq('id', userId)
        .maybeSingle();

    final beersTasted = profile?['beers_tasted'] as int? ?? 0;
    final currentStreak = profile?['current_streak'] as int? ?? 0;

    // Voor 'style'- en 'taster_flight'-voortgang: welke bierstijlen heeft
    // deze gebruiker al gelogd, en hoeveel daarvan zijn van vandaag.
    // Als de tabellen nog niet bestaan (migratie niet gedraaid) simpelweg
    // geen voortgang tonen voor die badges i.p.v. de pagina te laten crashen.
    var tastedStyles = <String>{};
    var stylesToday = <String>{};
    try {
      final logs = await _client.from('user_beer_logs').select('logged_at, bieren(stijl)').eq('user_id', userId);
      final today = DateTime.now();
      for (final row in (logs as List)) {
        final stijl = (row['bieren'] as Map<String, dynamic>?)?['stijl'] as String?;
        if (stijl == null) continue;
        tastedStyles.add(stijl);
        final loggedAt = DateTime.tryParse(row['logged_at'] as String? ?? '')?.toLocal();
        if (loggedAt != null && loggedAt.year == today.year && loggedAt.month == today.month && loggedAt.day == today.day) {
          stylesToday.add(stijl);
        }
      }
    } catch (_) {
      // Migratie (add_bieren_tabel.sql) nog niet gedraaid -- geen voortgang tonen.
    }

    final allBadges = await _client.from('badges').select().order('requirement_value');
    final earnedRows = await _client.from('user_badges').select('badge_id').eq('user_id', userId);
    final earnedIds = (earnedRows as List).map((r) => r['badge_id'] as String).toSet();

    final badges = (allBadges as List).map((row) {
      final requirementType = row['requirement_type'] as String?;
      final targetStyle = row['target_style'] as String?;
      int? currentValue;
      switch (requirementType) {
        case 'streak':
          currentValue = currentStreak;
          break;
        case 'checkins':
          currentValue = beersTasted;
          break;
        case 'style':
          if (targetStyle != null) currentValue = tastedStyles.contains(targetStyle) ? 1 : 0;
          break;
        case 'taster_flight':
          currentValue = stylesToday.length;
          break;
      }
      return ProfileBadge(
        id: row['id'] as String,
        title: row['title'] as String,
        description: row['description'] as String,
        icon: _iconsByName[row['icon_name'] as String] ?? Icons.emoji_events,
        imageAsset: row['image_asset'] as String?,
        requirementValue: row['requirement_value'] as int,
        earned: earnedIds.contains(row['id'] as String),
        category: row['category'] as String? ?? 'algemeen',
        currentValue: currentValue,
      );
    }).toList();

    return ProfileStats(
      beersTasted: beersTasted,
      breweriesExplored: profile?['breweries_explored'] as int? ?? 0,
      currentStreak: currentStreak,
      longestStreak: profile?['longest_streak'] as int? ?? 0,
      badges: badges,
    );
  }
}
