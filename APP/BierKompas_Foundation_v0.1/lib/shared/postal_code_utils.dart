/// Zet een Nederlandse postcode om naar het formaat dat Nominatim
/// (OpenStreetMap-geocoding) verwacht: "1234 AB", met een spatie.
///
/// Zonder die spatie ("1234ab") vindt Nominatim vaak niets, ook al is de rest
/// van het adres correct -- dit werd ontdekt doordat een goedgekeurd
/// evenement met postcode "2734bg" nooit op de kaart verscheen, terwijl
/// "2734 BG" wel een geldig resultaat gaf.
final _postalCodePattern = RegExp(r'^\s*(\d{4})\s*([A-Za-z]{2})\s*$');

String normalizeDutchPostalCode(String postalCode) {
  final match = _postalCodePattern.firstMatch(postalCode);
  if (match == null) return postalCode;
  return '${match.group(1)} ${match.group(2)!.toUpperCase()}';
}
