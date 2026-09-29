/// Een biernummer uit "Brouwers Beats" (covers: assets/music/). Geen
/// Spotify-koppeling (vereist Premium voor zowel app als luisteraar) -- in
/// plaats daarvan een link om het nummer elders te beluisteren.
class Song {
  final String id;
  final String title;
  final String artist;
  final String coverAsset;
  final bool featured;

  const Song({
    required this.id,
    required this.title,
    required this.artist,
    required this.coverAsset,
    this.featured = false,
  });

  /// Zoeklink om het nummer te beluisteren (YouTube), zodat iedereen het kan
  /// afspelen zonder abonnement of app-koppeling.
  String get listenUrl => 'https://www.youtube.com/results?search_query=${Uri.encodeComponent('$artist $title')}';
}

const songs = <Song>[
  Song(
    id: 'bzn_mexican_divorce',
    title: 'Mexican Divorce',
    artist: 'BZN',
    coverAsset: 'assets/music/bzn_mexican_divorce.png',
    featured: true,
  ),
  Song(
    id: 'katastroof_wijven',
    title: 'Met De Wijven Niks Als Last',
    artist: 'Katastroof',
    coverAsset: 'assets/music/katastroof_wijven.png',
  ),
  Song(
    id: 'henk_wijngaard_vlam',
    title: 'Met De Vlam In De Pijp',
    artist: 'Henk Wijngaard',
    coverAsset: 'assets/music/henk_wijngaard_vlam.png',
  ),
  Song(
    id: 'rowwen_heze_bestel_mar',
    title: 'Bestel Mar',
    artist: 'Rowwen Hèze',
    coverAsset: 'assets/music/rowwen_heze_bestel_mar.png',
  ),
  Song(
    id: 'luke_combs_beer',
    title: 'Beer Never Broke My Heart',
    artist: 'Luke Combs',
    coverAsset: 'assets/music/luke_combs_beer.png',
  ),
  Song(
    id: 'mickie_krause_bier',
    title: 'Geh Mal Bier Holen',
    artist: 'Mickie Krause',
    coverAsset: 'assets/music/mickie_krause_bier.png',
  ),
  Song(
    id: 'toby_keith_redcup',
    title: 'Red Solo Cup',
    artist: 'Toby Keith',
    coverAsset: 'assets/music/toby_keith_redcup.png',
  ),
  Song(
    id: 'zztop_beerdrinkers',
    title: 'Beer Drinkers & Hell Raisers',
    artist: 'ZZ Top',
    coverAsset: 'assets/music/zztop_beerdrinkers.png',
  ),
];
