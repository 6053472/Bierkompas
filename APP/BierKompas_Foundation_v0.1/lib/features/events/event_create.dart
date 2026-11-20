
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../shared/geocoding_service.dart';
import '../../shared/postal_code_utils.dart';
import '../../shared/postcode_lookup.dart';
import '../../shared/supabase_insert.dart';
import '../../shared/website_url.dart';

/// Formulier om een evenement aan te melden. Met [existingEvent] wordt
/// hetzelfde formulier gebruikt om een bestaand evenement te bewerken (alleen
/// voor beheerders: de database staat bijwerken alleen voor hen toe). Status,
/// organisator en overige velden blijven dan ongewijzigd. Bij opslaan sluit
/// de pagina met `true`.
class EventCreatePage extends StatefulWidget {
  const EventCreatePage({super.key, this.existingEvent});

  final Map<String, dynamic>? existingEvent;

  @override
  State<EventCreatePage> createState() => _EventCreatePageState();
}

class _EventCreatePageState extends State<EventCreatePage> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _streetController = TextEditingController();
  final TextEditingController _houseNumberController =
      TextEditingController();
  final TextEditingController _postalCodeController =
      TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _provinceController = TextEditingController();
  final TextEditingController _websiteController = TextEditingController();
  final TextEditingController _locationNameController =
      TextEditingController();
  final TextEditingController _descriptionController =
      TextEditingController();

  String _selectedEventType = 'Festival';

  DateTime? _selectedDate;
  TimeOfDay? _selectedStartTime;
  TimeOfDay? _selectedEndTime;

  bool _isRegularChecked = false;
  bool _isBierTicketChecked = false;
  bool _isVipChecked = false;
  bool _isLoading = false;

  Uint8List? _imageBytes;

  /// Bij bewerken: de huidige foto van het evenement (blijft staan zolang er
  /// geen nieuwe gekozen wordt).
  String? _existingImageUrl;

  bool get _isEditing => widget.existingEvent != null;

  static const Color backgroundColor = Color(0xFF1E1712);
  static const Color cardColor = Color(0xFF2C221C);
  static const Color inputColor = Color(0xFF17110D);
  static const Color borderColor = Color(0xFF46372D);
  static const Color beigeColor = Color(0xFFD4B28C);
  static const Color textColor = Color(0xFFEFE6DD);
  static const Color secondaryTextColor = Color(0xFF9E8A7D);

  static const List<String> _eventTypeOptions = [
    'Festival',
    'Proeverij',
    'Brouwersmarkt',
    'Lezing',
    'Bokbiertocht',
    'Bierwandeltocht',
  ];

  /// Soorten in de keuzelijst. Een bewerkt evenement met een soort die niet
  /// in de vaste lijst staat (bijv. uit een import) houdt die soort.
  List<String> get _typeOptions => _eventTypeOptions.contains(_selectedEventType)
      ? _eventTypeOptions
      : [..._eventTypeOptions, _selectedEventType];

  @override
  void initState() {
    super.initState();
    final event = widget.existingEvent;
    if (event != null) _fillFromEvent(event);
  }

  void _fillFromEvent(Map<String, dynamic> event) {
    String text(String key) {
      final value = event[key]?.toString().trim() ?? '';
      return value == 'null' ? '' : value;
    }

    _nameController.text = text('name');
    _streetController.text = text('street');
    _houseNumberController.text = text('house_number');
    _postalCodeController.text = text('postal_code');
    _cityController.text = text('city');
    _provinceController.text = text('province');
    _websiteController.text = text('website');
    _locationNameController.text = text('location_name');
    _descriptionController.text = text('description');
    if (text('event_type').isNotEmpty) _selectedEventType = text('event_type');

    final start = DateTime.tryParse(text('start_date'))?.toLocal();
    final end = DateTime.tryParse(text('end_date'))?.toLocal();
    if (start != null) {
      _selectedDate = DateTime(start.year, start.month, start.day);
      _selectedStartTime = TimeOfDay.fromDateTime(start);
    }
    if (end != null) _selectedEndTime = TimeOfDay.fromDateTime(end);

    _isRegularChecked = event['ticket_regular'] == true;
    _isBierTicketChecked = event['ticket_beer'] == true;
    _isVipChecked = event['ticket_vip'] == true;

    final image = text('image_asset');
    _existingImageUrl = image.isEmpty ? null : image;
  }

  /// Is het adres gewijzigd ten opzichte van het bewerkte evenement? Alleen
  /// dan hoeft het opnieuw opgezocht te worden.
  bool get _addressChanged {
    final event = widget.existingEvent;
    if (event == null) return true;
    String norm(Object? v) => (v?.toString() ?? '').trim().toLowerCase();
    return norm(event['street']) != norm(_streetController.text) ||
        norm(event['house_number']) != norm(_houseNumberController.text) ||
        norm(event['postal_code']) != norm(_postalCodeController.text) ||
        norm(event['city']) != norm(_cityController.text) ||
        event['latitude'] == null ||
        event['longitude'] == null;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _streetController.dispose();
    _houseNumberController.dispose();
    _postalCodeController.dispose();
    _cityController.dispose();
    _provinceController.dispose();
    _websiteController.dispose();
    _locationNameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _lookupPostcode(String value) async {
    final postcode = value.replaceAll(' ', '').toUpperCase();
    final belgianProvince = belgianProvinceForPostcode(postcode);
    if (belgianProvince != null) {
      setState(() => _provinceController.text = belgianProvince);
      return;
    }
    // Tijdens het typen van een NL-postcode is "1234" kort een geldige
    // BE-postcode geweest; die automatisch ingevulde provincie weer wissen.
    if (postcode.length >= 4 && _provinceController.text == belgianProvinceForPostcode(postcode.substring(0, 4))) {
      _provinceController.text = '';
    }
    final address = await lookupDutchPostcode(postcode);
    if (address == null || !mounted) return;
    // Intussen een andere postcode getypt: dit resultaat negeren.
    if (_postalCodeController.text.replaceAll(' ', '').toUpperCase() != postcode) return;

    setState(() {
      if (address.city.isNotEmpty) _cityController.text = address.city;
      if (address.province.isNotEmpty) _provinceController.text = address.province;
      if (_streetController.text.trim().isEmpty && address.street.isNotEmpty) {
        _streetController.text = address.street;
      }
    });
  }

  Future<void> _pickImage() async {
    try {
      final ImagePicker picker = ImagePicker();

      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 90,
      );

      if (image == null) return;

      final Uint8List bytes = await image.readAsBytes();

      if (!mounted) return;

      setState(() {
        _imageBytes = bytes;
      });
    } catch (e) {
      debugPrint('Fout bij kiezen afbeelding: $e');

      if (!mounted) return;

      _showMessage(
        'Kon afbeelding niet kiezen.',
        isError: true,
      );
    }
  }

  Future<String?> _uploadImageToSupabase() async {
    if (_imageBytes == null) {
      return null;
    }

    try {
      final supabase = Supabase.instance.client;

      final String fileName =
          'event_${DateTime.now().millisecondsSinceEpoch}.jpg';

      final String filePath = 'events/$fileName';

      await supabase.storage.from('event-images').uploadBinary(
            filePath,
            _imageBytes!,
            fileOptions: const FileOptions(
              upsert: true,
              contentType: 'image/jpeg',
            ),
          );

      return supabase.storage
          .from('event-images')
          .getPublicUrl(filePath);
    } catch (e) {
      debugPrint('Fout bij afbeelding uploaden: $e');
      return null;
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);
    // Een bewerkt evenement kan al voorbij zijn; die datum moet kiesbaar blijven.
    final DateTime firstDate = _selectedDate != null && _selectedDate!.isBefore(today)
        ? _selectedDate!
        : today;

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? today,
      firstDate: firstDate,
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            scaffoldBackgroundColor: backgroundColor,
            dialogBackgroundColor: cardColor,
            colorScheme: const ColorScheme.dark(
              primary: beigeColor,
              onPrimary: backgroundColor,
              secondary: beigeColor,
              onSecondary: backgroundColor,
              surface: cardColor,
              onSurface: textColor,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && mounted) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _selectStartTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedStartTime ?? TimeOfDay.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            scaffoldBackgroundColor: backgroundColor,
            dialogBackgroundColor: cardColor,
            colorScheme: const ColorScheme.dark(
              primary: beigeColor,
              onPrimary: backgroundColor,
              secondary: beigeColor,
              onSecondary: backgroundColor,
              surface: cardColor,
              onSurface: textColor,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && mounted) {
      setState(() {
        _selectedStartTime = picked;
      });
    }
  }

  Future<void> _selectEndTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedEndTime ??
          (_selectedStartTime != null
              ? TimeOfDay(
                  hour: (_selectedStartTime!.hour + 2) % 24,
                  minute: _selectedStartTime!.minute,
                )
              : const TimeOfDay(hour: 18, minute: 0)),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            scaffoldBackgroundColor: backgroundColor,
            dialogBackgroundColor: cardColor,
            colorScheme: const ColorScheme.dark(
              primary: beigeColor,
              onPrimary: backgroundColor,
              secondary: beigeColor,
              onSecondary: backgroundColor,
              surface: cardColor,
              onSurface: textColor,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && mounted) {
      setState(() {
        _selectedEndTime = picked;
      });
    }
  }

  Future<void> _saveEventToSupabase() async {
    if (!_formKey.currentState!.validate()) {
      _showMessage(
        'Vul alle verplichte velden correct in.',
        isError: true,
      );
      return;
    }

    if (_selectedDate == null ||
        _selectedStartTime == null ||
        _selectedEndTime == null) {
      _showMessage(
        'Selecteer een datum, starttijd en eindtijd.',
        isError: true,
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    // Adres moet écht bestaan, anders verschijnt het evenement straks nooit
    // als pin op de kaart -- controleer dit vóórdat we iets opslaan. Bij
    // bewerken alleen als het adres veranderd is; anders blijft de bekende
    // positie staan.
    final GeocodeResult? geocode = _addressChanged
        ? await geocodeAddress(
            street: _streetController.text.trim(),
            houseNumber: _houseNumberController.text.trim(),
            postalCode: _postalCodeController.text.trim(),
            city: _cityController.text.trim(),
          )
        : null;

    if (geocode?.outcome == GeocodeOutcome.notFound) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showMessage(
        'Dit adres kon niet gevonden worden. Controleer straat, huisnummer, postcode en plaats.',
        isError: true,
      );
      return;
    }

    if (geocode?.outcome == GeocodeOutcome.serviceUnavailable) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showMessage(
        'Kon het adres niet controleren (geen verbinding). Probeer het opnieuw.',
        isError: true,
      );
      return;
    }

    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;

      if (user == null) {
        throw Exception(
          'Je moet ingelogd zijn om een evenement toe te voegen.',
        );
      }

      String? imageUrl;

      if (_imageBytes != null) {
        imageUrl = await _uploadImageToSupabase();

        if (imageUrl == null) {
          throw Exception(
            'De afbeelding kon niet worden geüpload.',
          );
        }
      }

      final DateTime startDateTime = DateTime(
        _selectedDate!.year,
        _selectedDate!.month,
        _selectedDate!.day,
        _selectedStartTime!.hour,
        _selectedStartTime!.minute,
      );

      DateTime endDateTime = DateTime(
        _selectedDate!.year,
        _selectedDate!.month,
        _selectedDate!.day,
        _selectedEndTime!.hour,
        _selectedEndTime!.minute,
      );
      // Een eindtijd vóór de starttijd (bijv. 20:00 - 01:00) loopt door tot
      // na middernacht: dan eindigt het evenement de volgende dag.
      if (endDateTime.isBefore(startDateTime)) {
        endDateTime = endDateTime.add(const Duration(days: 1));
      }

      if (!endDateTime.isAfter(startDateTime)) {
        if (mounted) {
          setState(() => _isLoading = false);
          _showMessage(
            'De eindtijd moet na de starttijd liggen.',
            isError: true,
          );
        }
        return;
      }

      final String formattedStartTime =
          '${_selectedStartTime!.hour.toString().padLeft(2, '0')}:'
          '${_selectedStartTime!.minute.toString().padLeft(2, '0')}';
      final String formattedEndTime =
          '${_selectedEndTime!.hour.toString().padLeft(2, '0')}:'
          '${_selectedEndTime!.minute.toString().padLeft(2, '0')}';

      if (_isEditing) {
        // Alleen de bewerkbare velden; status, organisator, prijs en
        // goedkeuringsgegevens blijven zoals ze waren.
        await updateWithOptionalColumns(
          'events',
          widget.existingEvent!['id'],
          {
            'name': _nameController.text.trim(),
            'event_type': _selectedEventType,
            'start_date': startDateTime.toUtc().toIso8601String(),
            'end_date': endDateTime.toUtc().toIso8601String(),
            'opening_hours': '$formattedStartTime - $formattedEndTime',
            'street': _streetController.text.trim(),
            'house_number': _houseNumberController.text.trim(),
            'postal_code': _postalCodeController.text.trim(),
            if (geocode != null) 'latitude': geocode.latitude,
            if (geocode != null) 'longitude': geocode.longitude,
            'city': _cityController.text.trim(),
            'province': _provinceController.text.trim().isEmpty ? null : _provinceController.text.trim(),
            'website': normalizeEventWebsite(_websiteController.text),
            'location_name': _locationNameController.text.trim(),
            'description': _descriptionController.text.trim(),
            if (imageUrl != null) 'image_asset': imageUrl,
            'ticket_regular': _isRegularChecked,
            'ticket_beer': _isBierTicketChecked,
            'ticket_vip': _isVipChecked,
          },
          optionalColumns: const ['province', 'website'],
        );

        if (!mounted) return;
        _showMessage('Wijzigingen opgeslagen.');
        Navigator.pop(context, true);
        return;
      }

      await insertWithOptionalColumns('events', {
        'user_id': user.id,
        'name': _nameController.text.trim(),
        'event_type': _selectedEventType,
        // Als UTC opslaan: zonder tijdzone leest de database het als UTC en
        // staat het evenement 1-2 uur verschoven in de agenda.
        'start_date': startDateTime.toUtc().toIso8601String(),
        'end_date': endDateTime.toUtc().toIso8601String(),
        'opening_hours': '$formattedStartTime - $formattedEndTime',
        'street': _streetController.text.trim(),
        'house_number': _houseNumberController.text.trim(),
        'postal_code': _postalCodeController.text.trim(),
        // Opgezochte positie bewaren, zodat de kaart het adres niet telkens
        // opnieuw hoeft op te zoeken.
        'latitude': geocode!.latitude,
        'longitude': geocode.longitude,
        'city': _cityController.text.trim(),
        'province': _provinceController.text.trim().isEmpty ? null : _provinceController.text.trim(),
        'website': normalizeEventWebsite(_websiteController.text),
        'location_name': _locationNameController.text.trim(),
        'description': _descriptionController.text.trim(),
        'image_asset': imageUrl,
        'ticket_regular': _isRegularChecked,
        'ticket_beer': _isBierTicketChecked,
        'ticket_vip': _isVipChecked,
        'price': 0.00,
        'price_incl_btw': true,
        'price_excl_btw': false,
        'status': 'pending',
      }, optionalColumns: const ['province', 'website']);

      if (!mounted) return;

      _showMessage(
        'Evenement ingediend. Het wacht nu op goedkeuring.',
      );

      Navigator.pop(context);
    } catch (error) {
      debugPrint('Fout bij opslaan evenement: $error');

      if (!mounted) return;

      _showMessage(
        'Fout bij opslaan: $error',
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showMessage(
    String message, {
    bool isError = false,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor:
            isError ? Colors.redAccent : const Color(0xFF4E7655),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    );
  }

  bool get _hasImage => _imageBytes != null || _existingImageUrl != null;

  String get _selectedDateText {
    if (_selectedDate == null) {
      return 'Selecteer datum';
    }

    return '${_selectedDate!.day.toString().padLeft(2, '0')}-'
        '${_selectedDate!.month.toString().padLeft(2, '0')}-'
        '${_selectedDate!.year}';
  }

  String get _selectedStartTimeText {
    if (_selectedStartTime == null) {
      return 'Selecteer tijd';
    }

    return _selectedStartTime!.format(context);
  }

  String get _selectedEndTimeText {
    if (_selectedEndTime == null) {
      return 'Selecteer tijd';
    }

    return _selectedEndTime!.format(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: _buildAppBar(),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
              16,
              18,
              16,
              40,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildIntro(),
                const SizedBox(height: 24),

                _buildSection(
                  icon: Icons.info_outline_rounded,
                  title: 'Basisinformatie',
                  subtitle: 'Vertel iets over je evenement.',
                  child: Column(
                    children: [
                      _buildLabel('Naam van het evenement'),
                      const SizedBox(height: 7),
                      _buildTextField(
                        controller: _nameController,
                        hintText: 'Bijv. Herfst Bokbier Festival',
                        icon: Icons.celebration_outlined,
                      ),
                      const SizedBox(height: 18),
                      _buildLabel('Type evenement'),
                      const SizedBox(height: 7),
                      _buildDropdownField(),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                _buildSection(
                  icon: Icons.event_outlined,
                  title: 'Datum & tijd',
                  subtitle: 'Wanneer vindt het evenement plaats?',
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _buildSelectionCard(
                              icon: Icons.calendar_month_outlined,
                              title: 'Datum',
                              value: _selectedDateText,
                              selected: _selectedDate != null,
                              onTap: () => _selectDate(context),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildSelectionCard(
                              icon: Icons.schedule_outlined,
                              title: 'Starttijd',
                              value: _selectedStartTimeText,
                              selected: _selectedStartTime != null,
                              onTap: () => _selectStartTime(context),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildSelectionCard(
                              icon: Icons.schedule_rounded,
                              title: 'Eindtijd',
                              value: _selectedEndTimeText,
                              selected: _selectedEndTime != null,
                              onTap: () => _selectEndTime(context),
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(child: SizedBox()),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                _buildSection(
                  icon: Icons.photo_camera_outlined,
                  title: 'Afbeelding',
                  subtitle:
                      'Een goede afbeelding maakt je evenement aantrekkelijker.',
                  child: _buildImagePicker(),
                ),

                const SizedBox(height: 16),

                _buildSection(
                  icon: Icons.location_on_outlined,
                  title: 'Locatie',
                  subtitle:
                      'Waar kunnen bezoekers je evenement vinden?',
                  child: Column(
                    children: [
                      _buildLabel('Locatienaam'),
                      const SizedBox(height: 7),
                      _buildTextField(
                        controller: _locationNameController,
                        hintText: 'Bijv. De Oude Brouwerij',
                        icon: Icons.storefront_outlined,
                      ),
                      const SizedBox(height: 18),
                      _buildLabel('Straatnaam'),
                      const SizedBox(height: 7),
                      _buildTextField(
                        controller: _streetController,
                        hintText: 'Bijv. Dorpsstraat',
                        icon: Icons.signpost_outlined,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r"[a-zA-ZÀ-ÿ0-9 '\- .]"),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                _buildLabel('Huisnummer'),
                                const SizedBox(height: 7),
                                _buildTextField(
                                  controller: _houseNumberController,
                                  hintText: '42',
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 3,
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                _buildLabel('Postcode'),
                                const SizedBox(height: 7),
                                _buildTextField(
                                  controller:
                                      _postalCodeController,
                                  hintText: '1234 AB / 2000',
                                  validator: (value) => isValidPostalCode(value ?? '')
                                      ? null
                                      : 'Ongeldige postcode',
                                  inputFormatters: [
                                    FilteringTextInputFormatter.allow(
                                      RegExp(r'[a-zA-Z0-9 ]'),
                                    ),
                                    LengthLimitingTextInputFormatter(7),
                                    TextInputFormatter.withFunction(
                                      (oldValue, newValue) => newValue.copyWith(
                                        text: newValue.text.toUpperCase(),
                                        selection: newValue.selection,
                                      ),
                                    ),
                                  ],
                                  onChanged: (value) {
                                    final length = value.replaceAll(' ', '').length;
                                    if (length == 4 || length == 6) {
                                      _lookupPostcode(value);
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      _buildLabel('Stad / plaats'),
                      const SizedBox(height: 7),
                      _buildTextField(
                        controller: _cityController,
                        hintText: 'Bijv. Utrecht',
                        icon: Icons.location_city_outlined,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r"[a-zA-ZÀ-ÿ '\-]"),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      _buildLabel('Provincie (optioneel)'),
                      const SizedBox(height: 7),
                      _buildTextField(
                        controller: _provinceController,
                        hintText: 'Wordt ingevuld via de postcode',
                        icon: Icons.map_outlined,
                        required: false,
                      ),
                      const SizedBox(height: 18),
                      _buildLabel('Website (optioneel)'),
                      const SizedBox(height: 7),
                      _buildTextField(
                        controller: _websiteController,
                        hintText: 'https://www.bierfestival.nl',
                        icon: Icons.link,
                        required: false,
                        validator: (value) => normalizeEventWebsite(value ?? '') == null
                            ? 'Geen geldige website, bijv. https://www.bierfestival.nl'
                            : null,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                _buildSection(
                  icon: Icons.description_outlined,
                  title: 'Beschrijving',
                  subtitle:
                      'Geef bezoekers wat meer informatie over het evenement.',
                  child: _buildTextArea(),
                ),

                const SizedBox(height: 16),

                _buildSection(
                  icon: Icons.confirmation_number_outlined,
                  title: 'Tickets',
                  subtitle:
                      'Welke soorten tickets zijn beschikbaar?',
                  child: Column(
                    children: [
                      _buildTicketOption(
                        icon: Icons.confirmation_num_outlined,
                        title: 'Regulier',
                        description: 'Standaard toegang',
                        value: _isRegularChecked,
                        onChanged: (value) {
                          setState(() {
                            _isRegularChecked = value;
                          });
                        },
                      ),
                      const SizedBox(height: 10),
                      _buildTicketOption(
                        icon: Icons.local_drink_outlined,
                        title: 'Bier-ticket',
                        description: 'Toegang inclusief bier',
                        value: _isBierTicketChecked,
                        onChanged: (value) {
                          setState(() {
                            _isBierTicketChecked = value;
                          });
                        },
                      ),
                      const SizedBox(height: 10),
                      _buildTicketOption(
                        icon: Icons.workspace_premium_outlined,
                        title: 'VIP-arrangement',
                        description: 'Extra speciale ervaring',
                        value: _isVipChecked,
                        onChanged: (value) {
                          setState(() {
                            _isVipChecked = value;
                          });
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                if (!_isEditing) ...[
                  _buildApprovalNotice(),
                  const SizedBox(height: 18),
                ],

                _buildPublishButton(),

                const SizedBox(height: 12),

                if (_isEditing)
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: OutlinedButton(
                      onPressed: _isLoading ? null : () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: textColor,
                        side: const BorderSide(color: borderColor),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        'Annuleren',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  )
                else
                  Center(
                    child: Text(
                      'Je evenement wordt eerst gecontroleerd door een beheerder.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        color: secondaryTextColor,
                        fontSize: 11,
                        height: 1.4,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return PreferredSize(
      preferredSize: const Size.fromHeight(95),
      child: Container(
        decoration: const BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(28),
            bottomRight: Radius.circular(28),
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 10,
            ),
            child: Row(
              children: [
                Material(
                  color: backgroundColor,
                  borderRadius: BorderRadius.circular(14),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => Navigator.pop(context),
                    child: const SizedBox(
                      width: 48,
                      height: 48,
                      child: Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: textColor,
                        size: 19,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    _isEditing ? 'Evenement bewerken' : 'Evenement toevoegen',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.playfairDisplay(
                      color: textColor,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 48),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIntro() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF3A2B21),
            Color(0xFF292019),
          ],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: borderColor,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: beigeColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Icon(
              Icons.sports_bar_outlined,
              color: beigeColor,
              size: 26,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isEditing ? 'Gegevens aanpassen' : 'Organiseer je evenement',
                  style: GoogleFonts.playfairDisplay(
                    color: textColor,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  _isEditing
                      ? 'Pas het evenement aan. Status en organisator blijven ongewijzigd.'
                      : 'Voeg een bierfestival, proeverij of ander evenement toe aan BierKompas.',
                  style: GoogleFonts.inter(
                    color: secondaryTextColor,
                    fontSize: 12,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: borderColor,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: backgroundColor,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(
                  icon,
                  color: beigeColor,
                  size: 19,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.inter(
                        color: textColor,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: GoogleFonts.inter(
                        color: secondaryTextColor,
                        fontSize: 10.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }

  Widget _buildLabel(String label) {
    return Text(
      label,
      style: GoogleFonts.inter(
        color: secondaryTextColor,
        fontSize: 10.5,
        fontWeight: FontWeight.bold,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    IconData? icon,
    ValueChanged<String>? onChanged,
    List<TextInputFormatter>? inputFormatters,
    FormFieldValidator<String>? validator,
    bool required = true,
  }) {
    return TextFormField(
      controller: controller,
      onChanged: onChanged,
      inputFormatters: inputFormatters,
      validator: (value) {
        if (!required) {
          // Optioneel veld: leeg mag, ingevuld wordt wel gecontroleerd.
          if (value == null || value.trim().isEmpty) return null;
          return validator?.call(value);
        }
        if (value == null || value.trim().isEmpty) {
          return 'Dit veld is verplicht';
        }

        return validator?.call(value);
      },
      style: GoogleFonts.inter(
        color: textColor,
        fontSize: 13.5,
      ),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: GoogleFonts.inter(
          color: secondaryTextColor.withOpacity(0.55),
          fontSize: 13,
        ),
        prefixIcon: icon != null
            ? Icon(
                icon,
                color: secondaryTextColor,
                size: 19,
              )
            : null,
        filled: true,
        fillColor: inputColor,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 15,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: const BorderSide(
            color: borderColor,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: const BorderSide(
            color: borderColor,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: const BorderSide(
            color: beigeColor,
            width: 1.3,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: const BorderSide(
            color: Colors.redAccent,
          ),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: const BorderSide(
            color: Colors.redAccent,
          ),
        ),
        errorStyle: GoogleFonts.inter(
          color: Colors.redAccent,
          fontSize: 10,
        ),
      ),
    );
  }

  Widget _buildDropdownField() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13),
      decoration: BoxDecoration(
        color: inputColor,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: borderColor,
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedEventType,
          isExpanded: true,
          dropdownColor: cardColor,
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            color: beigeColor,
          ),
          style: GoogleFonts.inter(
            color: textColor,
            fontSize: 13.5,
          ),
          items: _typeOptions.map(
            (value) {
              return DropdownMenuItem<String>(
                value: value,
                child: Row(
                  children: [
                    const Icon(
                      Icons.local_bar_outlined,
                      color: beigeColor,
                      size: 18,
                    ),
                    const SizedBox(width: 10),
                    Text(value),
                  ],
                ),
              );
            },
          ).toList(),
          onChanged: (value) {
            if (value == null) return;

            setState(() {
              _selectedEventType = value;
            });
          },
        ),
      ),
    );
  }

  Widget _buildSelectionCard({
    required IconData icon,
    required String title,
    required String value,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(15),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: inputColor,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: selected ? beigeColor : borderColor,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    icon,
                    color: beigeColor,
                    size: 19,
                  ),
                  const Spacer(),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: secondaryTextColor,
                    size: 18,
                  ),
                ],
              ),
              const SizedBox(height: 11),
              Text(
                title,
                style: GoogleFonts.inter(
                  color: secondaryTextColor,
                  fontSize: 10,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  color: selected ? textColor : secondaryTextColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImagePicker() {
    return GestureDetector(
      onTap: _pickImage,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 205,
        width: double.infinity,
        decoration: BoxDecoration(
          color: inputColor,
          borderRadius: BorderRadius.circular(17),
          border: Border.all(
            color: _hasImage ? beigeColor : borderColor,
          ),
        ),
        child: _hasImage
            ? Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: _imageBytes != null
                        ? Image.memory(
                            _imageBytes!,
                            fit: BoxFit.cover,
                          )
                        : Image.network(
                            _existingImageUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Center(
                              child: Icon(
                                Icons.broken_image_outlined,
                                color: secondaryTextColor,
                                size: 32,
                              ),
                            ),
                          ),
                  ),
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withOpacity(0.05),
                            Colors.black.withOpacity(0.7),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 14,
                    bottom: 13,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: backgroundColor.withOpacity(0.85),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.check_circle,
                            color: beigeColor,
                            size: 15,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _imageBytes != null
                                ? 'Afbeelding geselecteerd'
                                : 'Huidige afbeelding, tik om te vervangen',
                            style: GoogleFonts.inter(
                              color: textColor,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    right: 12,
                    top: 12,
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: backgroundColor.withOpacity(0.88),
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: const Icon(
                        Icons.edit_outlined,
                        color: beigeColor,
                        size: 18,
                      ),
                    ),
                  ),
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: beigeColor.withOpacity(0.10),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.add_photo_alternate_outlined,
                      color: beigeColor,
                      size: 27,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Voeg een evenementfoto toe',
                    style: GoogleFonts.inter(
                      color: textColor,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Tik om een afbeelding uit je galerij te kiezen',
                    style: GoogleFonts.inter(
                      color: secondaryTextColor,
                      fontSize: 10.5,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildTextArea() {
    return TextFormField(
      controller: _descriptionController,
      maxLines: 6,
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Dit veld is verplicht';
        }

        return null;
      },
      style: GoogleFonts.inter(
        color: textColor,
        fontSize: 13.5,
        height: 1.5,
      ),
      decoration: InputDecoration(
        hintText:
            'Vertel bezoekers wat ze kunnen verwachten...',
        hintStyle: GoogleFonts.inter(
          color: secondaryTextColor.withOpacity(0.55),
          fontSize: 13,
        ),
        filled: true,
        fillColor: inputColor,
        contentPadding: const EdgeInsets.all(15),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: const BorderSide(
            color: borderColor,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: const BorderSide(
            color: borderColor,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: const BorderSide(
            color: beigeColor,
            width: 1.3,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: const BorderSide(
            color: Colors.redAccent,
          ),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: const BorderSide(
            color: Colors.redAccent,
          ),
        ),
        errorStyle: GoogleFonts.inter(
          color: Colors.redAccent,
          fontSize: 10,
        ),
      ),
    );
  }

  Widget _buildTicketOption({
    required IconData icon,
    required String title,
    required String description,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => onChanged(!value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: value
                ? beigeColor.withOpacity(0.09)
                : inputColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: value ? beigeColor : borderColor,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: backgroundColor,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(
                  icon,
                  color: value
                      ? beigeColor
                      : secondaryTextColor,
                  size: 19,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.inter(
                        color: textColor,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      description,
                      style: GoogleFonts.inter(
                        color: secondaryTextColor,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              Checkbox(
                value: value,
                onChanged: (newValue) {
                  onChanged(newValue ?? false);
                },
                activeColor: beigeColor,
                checkColor: backgroundColor,
                side: const BorderSide(
                  color: secondaryTextColor,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildApprovalNotice() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: beigeColor.withOpacity(0.07),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: beigeColor.withOpacity(0.22),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline_rounded,
            color: beigeColor,
            size: 20,
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Goedkeuring',
                  style: GoogleFonts.inter(
                    color: textColor,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Na het indienen wordt je evenement gecontroleerd. Daarna kan het openbaar in de agenda verschijnen.',
                  style: GoogleFonts.inter(
                    color: secondaryTextColor,
                    fontSize: 10.5,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPublishButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _saveEventToSupabase,
        style: ElevatedButton.styleFrom(
          backgroundColor: beigeColor,
          foregroundColor: backgroundColor,
          disabledBackgroundColor: beigeColor.withOpacity(0.5),
          disabledForegroundColor: backgroundColor.withOpacity(0.6),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: _isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  color: backgroundColor,
                  strokeWidth: 2.3,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _isEditing ? Icons.save_outlined : Icons.send_rounded,
                    size: 19,
                  ),
                  const SizedBox(width: 9),
                  Text(
                    _isEditing ? 'Wijzigingen opslaan' : 'Evenement indienen',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
