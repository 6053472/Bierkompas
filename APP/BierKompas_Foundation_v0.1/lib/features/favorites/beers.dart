/// Waarde van `item_type` in de Supabase-tabel `favorites` voor bieren.
const beerItemType = 'beer';

/// Vaste bieren uit het Assortiment op de favorietenpagina, zolang er nog geen
/// bier-tabel in Supabase is. Het [id] wordt als `item_id` opgeslagen in `favorites`.
class Beer {
  final int id;
  final String name;
  final String style;
  final String abv;
  final String imageUrl;
  final String brewery;

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
    required this.imageUrl,
    required this.brewery,
    required this.description,
    required this.howMade,
    required this.styleInfo,
  });
}

const beers = [
  Beer(
    id: 1,
    name: 'Zatte',
    style: 'Tripel',
    abv: '8.0% ABV',
    imageUrl:
        'https://lh3.googleusercontent.com/aida-public/AB6AXuDQSCqvGkWdWMlwfupGl91szQSrCWrALjA9GRwWJXueax7jPuXpUlp25nyvBU6aZQLdZQK5GhMLDXnTASCYfTSpxzSWfs5ZnG1v7yJFqfPBgBMF3byFTXnc6GDzJV0AO0mAzsSX0O1NpZC-ZYV27Q2Jy3XqpGQjtHUjTEkom4_rAo8XiHpVqNlwdiuoHSJ3hgFq1-tXA9QFVF_Z-ZwFSwOnyst4SymKwKdUzushskZBmAVcW34NMIXi',
    brewery: "Brouwerij 't IJ, Amsterdam",
    description:
        "Een blonde tripel van Brouwerij 't IJ uit Amsterdam. Zatte was het allereerste bier dat 't IJ brouwde.",
    howMade:
        'Gebrouwen met lichte mout en vaak extra suiker, zodat het bier sterk wordt maar licht van kleur blijft. Bovengistende gist geeft fruitige en kruidige tonen, en veel tripels krijgen nog een nagisting op de fles.',
    styleInfo:
        'Tripel: een blond, sterk bier (meestal 7 tot 10%), kruidig en vrij droog. Een klassieke stijl uit de Belgische kloostertraditie.',
  ),
  Beer(
    id: 2,
    name: 'Natte',
    style: 'Dubbel',
    abv: '6.5% ABV',
    imageUrl:
        'https://lh3.googleusercontent.com/aida-public/AB6AXuDgFbx2LA5zvRWdpgP1NJAVi-gWgJuS9Abp2lD1nq9d1jqWL_qD0QFFDrQ3LcgcqLbamUf_TrZuVNOaXEAQTx44PSpeHaMDeINiUJjC8cvtsasKzuX1qM-eO8g0Ppl5QIIS5vJttLYewcC_GmmhzgTsNbS7mBXcBSPwIbnxgHcV7VnrgB6UuIs1a1tWirbuGOeE7XvAbZlVQI9p2450I0jaLRoAyCaWnFNmw9Pj4J4OnHLNfEWPXCtV',
    brewery: "Brouwerij 't IJ, Amsterdam",
    description: "Een donkere dubbel van Brouwerij 't IJ uit Amsterdam, met 6,5% alcohol.",
    howMade:
        'Gebrouwen met donkere, gekaramelliseerde mouten en soms kandijsuiker, en vergist met bovengistende gist. Dat geeft tonen van karamel, rozijnen en toffee.',
    styleInfo:
        'Dubbel: donkerbruin, moutig en licht zoet (meestal 6 tot 8%). Net als de tripel een klassieke Belgische kloosterbierstijl.',
  ),
  Beer(
    id: 3,
    name: 'IJwit',
    style: 'Witbier',
    abv: '6.5% ABV',
    imageUrl:
        'https://lh3.googleusercontent.com/aida-public/AB6AXuDQhKscA00YiHmLOCdFOnKCDnUdAW9kZbBWb69ou6CZYBeHe2q_KbKtwlHDL0lQkAPAzsuvqmU8pVUmGHnRg0EWpY5Ik6FPaApETd4GFJ8GNjNmCAwJ6UFY300bVAFedalKlJ4kScOIAVCDoLzrV9zFMfi2_qs893DP-Tb2j9J-xeHYZerm49wZU1lpqFBiWmJnNAe65PEpi4vsS5PdJhcm0R7KwgjTuk-DTrYbqCMr6frfIMKx7qQK',
    brewery: "Brouwerij 't IJ, Amsterdam",
    description: "Een troebel witbier van Brouwerij 't IJ uit Amsterdam, met 6,5% alcohol.",
    howMade:
        'Witbier wordt gebrouwen met een flink deel tarwe naast gerstemout en traditioneel gekruid met koriander en sinaasappelschil. Het wordt niet gefilterd, daarom is het troebel.',
    styleInfo:
        'Witbier: licht, fris en citrusachtig. De stijl komt oorspronkelijk uit de streek rond Hoegaarden; met 6,5% is deze iets steviger dan gemiddeld.',
  ),
  Beer(
    id: 4,
    name: 'Columbus',
    style: 'Amber Ale',
    abv: '9.0% ABV',
    imageUrl:
        'https://lh3.googleusercontent.com/aida-public/AB6AXuDzhnMA6a-cCYnZ4dSjHCbGFUCvVBqXUZ9Mjk381yzhl0FoUiVgLmBWOKSPR3dEAVnnWVP1ViPRMKTviMaubvedPJI8ZXYMKr2bHJp9kjDRoEAO6A3vh371Km-kVjS9517tTWX1sD4_SpqLSWD2-RUMkSVP5qWL233CRvFNvB207EKaTmWkQClVLTqYIyOY1ub3PvqQO7wKkKnn-D4nvwFWeRXl3ZPDG8Oz-xe3t4BW9-cK5h3r3pSO',
    brewery: "Brouwerij 't IJ, Amsterdam",
    description: "Een sterk, amberkleurig bier van Brouwerij 't IJ uit Amsterdam, met 9,0% alcohol.",
    howMade:
        'Gebrouwen met karamelmout, die het bier zijn koperen kleur en zachte moutzoetheid geeft, en vergist met bovengistende gist. De hop zorgt voor een bittere tegenhanger.',
    styleInfo:
        'Amber: koperkleurig en moutig met een lichte bitterheid. Met 9% hoort deze bij de zware bieren.',
  ),
];
