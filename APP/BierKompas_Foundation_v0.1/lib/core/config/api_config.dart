/// Zet hier de link naar de backend zodra je hosting hebt, bv:
/// 'https://jouwdomein.nl/api'
///
/// Zolang dit leeg is, gebruikt AuthService een lokaal testaccount
/// zodat de app al getest kan worden zonder live backend.
class ApiConfig {
  static const String baseUrl = '';

  static bool get isConfigured => baseUrl.isNotEmpty;
}
