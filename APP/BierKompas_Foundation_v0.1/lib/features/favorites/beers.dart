/// Waarde van `item_type` in de Supabase-tabel `favorites` voor bieren.
const beerItemType = 'beer';

/// Vaste bieren zolang er nog geen bier-tabel in Supabase is. Het [id] wordt als
/// `item_id` opgeslagen in `favorites`; reviews in de feed verwijzen ernaar via `beer_id`.
class Beer {
  final int id;
  final String name;
  final String style;
  final String abv;
  final String? imageUrl;

  /// Naam en plaats van de brouwerij, of null als die niet bekend is.
  final String? brewery;

  /// Wat het bier is.
  final String description;

  /// Hoe dit soort bier gemaakt wordt.
  final String howMade;

  /// Wat voor soort bier het is.
  final String styleInfo;

  const Beer({
    required this.id,
    required this.name,
    required this.style,
    required this.abv,
    required this.description,
    required this.howMade,
    required this.styleInfo,
    this.imageUrl,
    this.brewery,
  });
}

// Uitleg per bierstijl, gedeeld door bieren van dezelfde stijl.
const _tripelHowMade =
    'Gebrouwen met lichte mout en vaak extra suiker, zodat het bier sterk wordt maar licht van kleur blijft. Bovengistende gist geeft fruitige en kruidige tonen, en veel tripels krijgen nog een nagisting op de fles.';
const _tripelStyle =
    'Tripel: een blond, sterk bier (meestal 7 tot 10%), kruidig en vrij droog. Een klassieke stijl uit de Belgische kloostertraditie.';
const _dubbelHowMade =
    'Gebrouwen met donkere, gekaramelliseerde mouten en soms kandijsuiker, en vergist met bovengistende gist. Dat geeft tonen van karamel, rozijnen en toffee.';
const _dubbelStyle =
    'Dubbel: donkerbruin, moutig en licht zoet (meestal 6 tot 8%). Net als de tripel een klassieke Belgische kloosterbierstijl.';
const _witbierHowMade =
    'Witbier wordt gebrouwen met een flink deel tarwe naast gerstemout en traditioneel gekruid met koriander en sinaasappelschil. Het wordt niet gefilterd, daarom is het troebel.';
const _witbierStyle =
    'Witbier: licht, fris en citrusachtig, meestal 4,5 tot 5,5%. De stijl komt oorspronkelijk uit de streek rond Hoegaarden.';

const _tIJ = "Brouwerij 't IJ, Amsterdam";
const _tripelImage =
    'https://lh3.googleusercontent.com/aida-public/AB6AXuANIbUEodWyxyWEqbHFoWd_APYDtoiXgTOVbAJ5TIOp9PKG4baeF5XYwf34634GW-PHvDpk4FhxpB1XlsZEFAl3BsWVxT8Gq-KlOZ01ggozbCfeF3fRoufrH8N5tDetdyMY9uKUxDAadw9wON36RlMvSHNjV30Ol5XjZ06tnPRARXfPUGTEFIa5xw_1m7rvTyggDsC2HvYxMuo3GNidOYo-3ypVQq14WiAoZWsApQQMn_T-2VSeoFN7';
const _witbierImage =
    'https://lh3.googleusercontent.com/aida-public/AB6AXuDQhKscA00YiHmLOCdFOnKCDnUdAW9kZbBWb69ou6CZYBeHe2q_KbKtwlHDL0lQkAPAzsuvqmU8pVUmGHnRg0EWpY5Ik6FPaApETd4GFJ8GNjNmCAwJ6UFY300bVAFedalKlJ4kScOIAVCDoLzrV9zFMfi2_qs893DP-Tb2j9J-xeHYZerm49wZU1lpqFBiWmJnNAe65PEpi4vsS5PdJhcm0R7KwgjTuk-DTrYbqCMr6frfIMKx7qQK';
const _amberImage =
    'https://lh3.googleusercontent.com/aida-public/AB6AXuDzhnMA6a-cCYnZ4dSjHCbGFUCvVBqXUZ9Mjk381yzhl0FoUiVgLmBWOKSPR3dEAVnnWVP1ViPRMKTviMaubvedPJI8ZXYMKr2bHJp9kjDRoEAO6A3vh371Km-kVjS9517tTWX1sD4_SpqLSWD2-RUMkSVP5qWL233CRvFNvB207EKaTmWkQClVLTqYIyOY1ub3PvqQO7wKkKnn-D4nvwFWeRXl3ZPDG8Oz-xe3t4BW9-cK5h3r3pSO';

/// Het bier uit "Nu Populair" op Ontdek.
const koperenNachtTripel = Beer(
  id: 5,
  name: 'Koperen Nacht Tripel',
  style: 'Tripel',
  abv: '8.5% ABV',
  imageUrl: _tripelImage,
  description: 'Een goudkoperkleurige tripel met een romige schuimkraag, kruidig met tonen van karamel.',
  howMade: _tripelHowMade,
  styleInfo: _tripelStyle,
);

const beers = [
  Beer(
    id: 1,
    name: 'Zatte',
    style: 'Tripel',
    abv: '8.0% ABV',
    imageUrl:
        'https://lh3.googleusercontent.com/aida-public/AB6AXuDQSCqvGkWdWMlwfupGl91szQSrCWrALjA9GRwWJXueax7jPuXpUlp25nyvBU6aZQLdZQK5GhMLDXnTASCYfTSpxzSWfs5ZnG1v7yJFqfPBgBMF3byFTXnc6GDzJV0AO0mAzsSX0O1NpZC-ZYV27Q2Jy3XqpGQjtHUjTEkom4_rAo8XiHpVqNlwdiuoHSJ3hgFq1-tXA9QFVF_Z-ZwFSwOnyst4SymKwKdUzushskZBmAVcW34NMIXi',
    brewery: _tIJ,
    description:
        "Een blonde tripel van Brouwerij 't IJ uit Amsterdam. Zatte was het allereerste bier dat 't IJ brouwde.",
    howMade: _tripelHowMade,
    styleInfo: _tripelStyle,
  ),
  Beer(
    id: 2,
    name: 'Natte',
    style: 'Dubbel',
    abv: '6.5% ABV',
    imageUrl:
        'https://lh3.googleusercontent.com/aida-public/AB6AXuDgFbx2LA5zvRWdpgP1NJAVi-gWgJuS9Abp2lD1nq9d1jqWL_qD0QFFDrQ3LcgcqLbamUf_TrZuVNOaXEAQTx44PSpeHaMDeINiUJjC8cvtsasKzuX1qM-eO8g0Ppl5QIIS5vJttLYewcC_GmmhzgTsNbS7mBXcBSPwIbnxgHcV7VnrgB6UuIs1a1tWirbuGOeE7XvAbZlVQI9p2450I0jaLRoAyCaWnFNmw9Pj4J4OnHLNfEWPXCtV',
    brewery: _tIJ,
    description: "Een donkere dubbel van Brouwerij 't IJ uit Amsterdam, met 6,5% alcohol.",
    howMade: _dubbelHowMade,
    styleInfo: _dubbelStyle,
  ),
  Beer(
    id: 3,
    name: 'IJwit',
    style: 'Witbier',
    abv: '6.5% ABV',
    imageUrl: _witbierImage,
    brewery: _tIJ,
    description:
        "Een troebel witbier van Brouwerij 't IJ uit Amsterdam. Met 6,5% is het steviger dan de meeste witbieren.",
    howMade: _witbierHowMade,
    styleInfo: _witbierStyle,
  ),
  Beer(
    id: 4,
    name: 'Columbus',
    style: 'Amber Ale',
    abv: '9.0% ABV',
    imageUrl: _amberImage,
    brewery: _tIJ,
    description: "Een sterk, amberkleurig bier van Brouwerij 't IJ uit Amsterdam, met 9,0% alcohol.",
    howMade:
        'Gebrouwen met karamelmout, die het bier zijn koperen kleur en zachte moutzoetheid geeft, en vergist met bovengistende gist. De hop zorgt voor een bittere tegenhanger.',
    styleInfo: 'Amber: koperkleurig en moutig met een lichte bitterheid. Met 9% hoort deze bij de zware bieren.',
  ),
  koperenNachtTripel,
  Beer(
    id: 6,
    name: 'Amber Kompas IPA',
    style: 'IPA',
    abv: '6.5% ABV',
    description: 'Een frisse IPA met grapefruit en dennen op een stevige moutbasis.',
    howMade:
        "Gebrouwen met lichte mout en veel hop, die zowel tijdens het koken als daarna (dry hopping) wordt toegevoegd. Dat geeft bitterheid en aroma's van citrus, dennen of tropisch fruit.",
    styleInfo: 'IPA (India Pale Ale): een hoppig, bitter bier, meestal 5,5 tot 7,5%. Een van de populairste craftbierstijlen.',
  ),
  Beer(
    id: 7,
    name: 'Donkere Molen Stout',
    style: 'Stout',
    abv: '7.0% ABV',
    description: 'Een donkere stout met koffie, pure chocolade en een vleugje vanille.',
    howMade:
        'Gebrouwen met sterk geroosterde mout of gerst, die het bier zijn zwarte kleur en tonen van koffie en chocolade geeft.',
    styleInfo:
        'Stout: donker tot zwart, met een volle, romige mondvulling. Varieert van licht (rond 4%) tot heel zwaar (imperial stout, 8% of meer).',
  ),
  Beer(
    id: 8,
    name: 'Zomerhaven Witbier',
    style: 'Witbier',
    abv: '5.0% ABV',
    imageUrl: _witbierImage,
    description: 'Een troebel witbier met citrus en koriander, op zijn best bij warm weer.',
    howMade: _witbierHowMade,
    styleInfo: _witbierStyle,
  ),
  Beer(
    id: 9,
    name: 'Oude Sluis Dubbel',
    style: 'Dubbel',
    abv: '7.0% ABV',
    description: 'Een klassieke dubbel met rozijnen, bruine suiker en een vleugje drop.',
    howMade: _dubbelHowMade,
    styleInfo: _dubbelStyle,
  ),
  Beer(
    id: 10,
    name: 'Veldkers Saison',
    style: 'Saison',
    abv: '6.0% ABV',
    description: 'Een droge, peperige saison met een licht fruitig karakter.',
    howMade:
        'Vergist met een speciale saisongist die de suikers bijna volledig omzet. Daardoor wordt het bier droog en krijgt het peperige en fruitige tonen.',
    styleInfo: 'Saison: een oorspronkelijk Belgisch boerenbier, droog en dorstlessend, meestal 5 tot 7%.',
  ),
  Beer(
    id: 11,
    name: 'Koperen Nacht Blond',
    style: 'Blond',
    abv: '6.5% ABV',
    description: 'Een toegankelijk blond bier met een honingzoet begin en een licht bittere finish.',
    howMade:
        'Gebrouwen met lichte mout en bovengistende gist, met een bescheiden hoeveelheid hop voor een zachte bitterheid.',
    styleInfo: 'Blond: goudgeel, zacht en toegankelijk, meestal 6 tot 7%.',
  ),
  Beer(
    id: 12,
    name: 'Winterlicht Bock',
    style: 'Bock',
    abv: '7.0% ABV',
    description: 'Een donkere bock met tonen van karamel en geroosterd brood.',
    howMade: 'Gebrouwen met donkere mouten en karamelmout voor een volle, moutige smaak.',
    styleInfo:
        'Bock: een stevig, moutig bier. In Nederland vooral bekend als herfstbok, meestal 6,5 tot 8%.',
  ),
  Beer(
    id: 13,
    name: 'Havenmeester Pale Ale',
    style: 'Pale Ale',
    abv: '5.5% ABV',
    imageUrl: _amberImage,
    description: 'Een heldere pale ale met bloemige hop en een droge afdronk.',
    howMade: 'Gebrouwen met lichte mout en een flinke dosis aromatische hop, en vergist met bovengistende gist.',
    styleInfo: 'Pale ale: goudblond tot amber, fris en hoppig maar minder bitter dan een IPA, meestal 4,5 tot 6%.',
  ),
  Beer(
    id: 14,
    name: 'Kelderzuur Kriek',
    style: 'Kriek',
    abv: '6.0% ABV',
    description: 'Een zure kriek met kersen en een tikje amandel.',
    howMade:
        'Een traditionele kriek ontstaat door zure kersen (krieken) op lambiek te laten nagisten. De spontane vergisting van de lambiek geeft het bier zijn zure karakter.',
    styleInfo: 'Kriek: een fruitbier op basis van lambiek; zuur, fris en kersenrood.',
  ),
];
