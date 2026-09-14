import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileBadge {
  final String id;
  final String title;
  final String description;
  final IconData icon;
  final int requirementValue;
  final bool earned;

  const ProfileBadge({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.requirementValue,
    required this.earned,
  });
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

/// Praat met de Supabase-tabellen `badges`/`user_badges` en de
/// `record_daily_activity`-functie die de Bier Streak bijhoudt.
class StatsService {
  SupabaseClient get _client => Supabase.instance.client;

  /// Moet 1x per relevante gebruikersactie (o.a. bij het openen van de app)
  /// aangeroepen worden. Werkt de streak bij en kent nieuwe badges toe.
  Future<void> recordDailyActivity(String userId) async {
    await _client.rpc('record_daily_activity', params: {'p_user_id': userId});
  }

  Future<ProfileStats> fetchStats(String userId) async {
    final profile = await _client
        .from('profiles')
        .select('beers_tasted, breweries_explored, current_streak, longest_streak')
        .eq('id', userId)
        .maybeSingle();

    final allBadges = await _client.from('badges').select().order('requirement_value');
    final earnedRows = await _client.from('user_badges').select('badge_id').eq('user_id', userId);
    final earnedIds = (earnedRows as List).map((r) => r['badge_id'] as String).toSet();

    final badges = (allBadges as List)
        .map((row) => ProfileBadge(
              id: row['id'] as String,
              title: row['title'] as String,
              description: row['description'] as String,
              icon: _iconsByName[row['icon_name'] as String] ?? Icons.emoji_events,
              requirementValue: row['requirement_value'] as int,
              earned: earnedIds.contains(row['id'] as String),
            ))
        .toList();

    return ProfileStats(
      beersTasted: profile?['beers_tasted'] as int? ?? 0,
      breweriesExplored: profile?['breweries_explored'] as int? ?? 0,
      currentStreak: profile?['current_streak'] as int? ?? 0,
      longestStreak: profile?['longest_streak'] as int? ?? 0,
      badges: badges,
    );
  }
}
