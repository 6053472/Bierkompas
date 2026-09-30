/// Een horecagelegenheid (café, proeflokaal, bierbar) die via "Horeca
/// toevoegen" is aangemeld en door een beheerder is goedgekeurd
/// (zie horeca_submission_service.dart en supabase/add_horeca_submissions.sql).
class HorecaVenue {
  final int id;
  final String title;
  final String location;
  final String about;
  final double latitude;
  final double longitude;
  final String? imageUrl;

  const HorecaVenue({
    required this.id,
    required this.title,
    required this.location,
    required this.about,
    required this.latitude,
    required this.longitude,
    this.imageUrl,
  });
}
