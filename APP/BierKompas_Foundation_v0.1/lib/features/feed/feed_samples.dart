import 'feed_service.dart';

/// Terugvalwaarde zolang de Supabase-view `feed` nog niet bestaat (zie
/// supabase/add_feed.sql/add_user_posts.sql). Bevat bewust geen verzonnen
/// content meer -- eerdere voorbeelddata (nep-reviews, nep-brouwerijposts)
/// is verwijderd omdat die als echte gebruikersinhoud oogde. Zonder de
/// echte feed-view toont de Ontdek-pagina dus gewoon een lege feed i.p.v.
/// verzonnen berichten.
final List<FeedItem> sampleFeedItems = <FeedItem>[];
