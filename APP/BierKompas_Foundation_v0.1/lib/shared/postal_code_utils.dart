/// Zet een Nederlandse postcode om naar het formaat dat Nominatim
/// (OpenStreetMap-geocoding) verwacht: "1234 AB", met een spatie.
///
/// Zonder die spatie ("1234ab") vindt Nominatim vaak niets, ook al is de rest
/// van het adres correct -- dit werd ontdekt doordat een goedgekeurd
/// evenement met postcode "2734bg" nooit op de kaart verscheen, terwijl
/// "2734 BG" wel een geldig resultaat gaf.
///
/// Een Belgische postcode (vier cijfers, geen letters) blijft ongewijzigd.
final _postalCodePattern = RegExp(r'^\s*(\d{4})\s*([A-Za-z]{2})\s*$');

final _dutchPostalCodePattern = RegExp(r'^[1-9][0-9]{3}\s?[a-zA-Z]{2}$');
final _belgianPostalCodePattern = RegExp(r'^[1-9][0-9]{3}$');

String normalizeDutchPostalCode(String postalCode) {
  final match = _postalCodePattern.firstMatch(postalCode);
  if (match == null) return postalCode;
  return '${match.group(1)} ${match.group(2)!.toUpperCase()}';
}

/// Nederlandse postcode, bijv. "1234 AB" of "1234ab".
bool isDutchPostalCode(String postalCode) => _dutchPostalCodePattern.hasMatch(postalCode.trim());

/// Belgische postcode: vier cijfers, bijv. "2000".
bool isBelgianPostalCode(String postalCode) => _belgianPostalCodePattern.hasMatch(postalCode.trim());

/// Geldige Nederlandse of Belgische postcode.
bool isValidPostalCode(String postalCode) => isDutchPostalCode(postalCode) || isBelgianPostalCode(postalCode);

/// Land om aan een adres te plakken voor de geocoding: "België" bij een
/// 4-cijferige postcode zonder letters, anders "Nederland".
String countryForPostalCode(String postalCode) => isBelgianPostalCode(postalCode) ? 'België' : 'Nederland';
