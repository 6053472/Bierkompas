import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EventCreatePage extends StatefulWidget {
  const EventCreatePage({super.key});

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
  final TextEditingController _locationNameController =
      TextEditingController();
  final TextEditingController _descriptionController =
      TextEditingController();

  String _selectedEventType = 'Festival';

  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;

  bool _isRegularChecked = false;
  bool _isBierTicketChecked = false;
  bool _isVipChecked = false;
  bool _isLoading = false;

  File? _imageFile;
  Uint8List? _webImageBytes;

  static const Color backgroundColor = Color(0xFF1E1712);
  static const Color cardColor = Color(0xFF2C221C);
  static const Color inputColor = Color(0xFF1E1712);
  static const Color borderColor = Color(0xFF3C3028);
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

  @override
  void dispose() {
    _nameController.dispose();
    _streetController.dispose();
    _houseNumberController.dispose();
    _postalCodeController.dispose();
    _cityController.dispose();
    _locationNameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final ImagePicker picker = ImagePicker();

      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 90,
      );

      if (image == null) return;

      if (kIsWeb) {
        final bytes = await image.readAsBytes();

        setState(() {
          _webImageBytes = bytes;
          _imageFile = null;
        });
      } else {
        setState(() {
          _imageFile = File(image.path);
          _webImageBytes = null;
        });
      }
    } catch (e) {
      debugPrint('Fout bij kiezen afbeelding: $e');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Kon afbeelding niet kiezen: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<String?> _uploadImageToSupabase() async {
    try {
      final supabase = Supabase.instance.client;

      final fileName =
          'event_${DateTime.now().millisecondsSinceEpoch}.jpg';

      final filePath = 'events/$fileName';

      debugPrint(
        'Afbeelding uploaden naar event-images/$filePath',
      );

      if (kIsWeb && _webImageBytes != null) {
        await supabase.storage.from('event-images').uploadBinary(
          filePath,
          _webImageBytes!,
          fileOptions: const FileOptions(
            upsert: true,
            contentType: 'image/jpeg',
          ),
        );
      } else if (_imageFile != null) {
        await supabase.storage.from('event-images').upload(
          filePath,
          _imageFile!,
          fileOptions: const FileOptions(
            upsert: true,
            contentType: 'image/jpeg',
          ),
        );
      } else {
        debugPrint('Geen afbeelding geselecteerd.');
        return null;
      }

      final String publicUrl = supabase.storage
          .from('event-images')
          .getPublicUrl(filePath);

      debugPrint('Afbeelding URL: $publicUrl');

      return publicUrl;
    } catch (e) {
      debugPrint('FOUT BIJ AFBEELDING UPLOAD: $e');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Afbeelding kon niet worden geüpload: $e',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }

      return null;
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: beigeColor,
              onPrimary: backgroundColor,
              surface: cardColor,
              onSurface: textColor,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: beigeColor,
              onPrimary: backgroundColor,
              surface: cardColor,
              onSurface: textColor,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  Future<void> _saveEventToSupabase() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Vul alle verplichte velden correct in.',
          ),
          backgroundColor: Colors.orange,
        ),
      );

      return;
    }

    if (_selectedDate == null || _selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Selecteer alstublieft een datum en tijd.',
          ),
          backgroundColor: Colors.orange,
        ),
      );

      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final supabase = Supabase.instance.client;

      final user = supabase.auth.currentUser;

      if (user == null) {
        throw 'Je moet ingelogd zijn om een evenement toe te voegen.';
      }

      String? imageUrl;

      if (_imageFile != null || _webImageBytes != null) {
        imageUrl = await _uploadImageToSupabase();

        if (imageUrl == null) {
          throw 'De afbeelding kon niet worden geüpload.';
        }
      }

      final DateTime startDateTime = DateTime(
        _selectedDate!.year,
        _selectedDate!.month,
        _selectedDate!.day,
        _selectedTime!.hour,
        _selectedTime!.minute,
      );

      final DateTime endDateTime =
          startDateTime.add(const Duration(hours: 4));

      final String formattedTime =
          '${_selectedTime!.hour.toString().padLeft(2, '0')}:'
          '${_selectedTime!.minute.toString().padLeft(2, '0')}';

      debugPrint('Evenement opslaan...');
      debugPrint('Afbeelding: $imageUrl');

      await supabase.from('events').insert({
        'user_id': user.id,
        'name': _nameController.text.trim(),
        'event_type': _selectedEventType,
        'start_date': startDateTime.toIso8601String(),
        'end_date': endDateTime.toIso8601String(),
        'opening_hours': formattedTime,
        'street': _streetController.text.trim(),
        'house_number': _houseNumberController.text.trim(),
        'postal_code': _postalCodeController.text.trim(),
        'city': _cityController.text.trim(),
        'location_name': _locationNameController.text.trim(),
        'description': _descriptionController.text.trim(),

        // URL van de geüploade foto
        'image_asset': imageUrl,

        'ticket_regular': _isRegularChecked,
        'ticket_beer': _isBierTicketChecked,
        'ticket_vip': _isVipChecked,
        'price': 0.00,
        'price_incl_btw': true,
        'price_excl_btw': false,
      });

      debugPrint('Evenement succesvol opgeslagen.');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Evenement succesvol opgeslagen!',
            ),
            backgroundColor: Colors.green,
          ),
        );

        Navigator.pop(context);
      }
    } catch (error) {
      debugPrint(
        'Fout bij opslaan evenement: $error',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Fout bij opslaan: $error',
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(
          kToolbarHeight,
        ),
        child: Container(
          decoration: const BoxDecoration(
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(24),
              bottomRight: Radius.circular(24),
            ),
            color: cardColor,
          ),
          child: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            centerTitle: true,
            leading: IconButton(
              icon: const Icon(
                Icons.close,
                color: textColor,
              ),
              onPressed: () {
                Navigator.pop(context);
              },
            ),
            title: Text(
              'Evenement Toevoegen',
              style: GoogleFonts.playfairDisplay(
                color: textColor,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  'Evenement Toevoegen',
                  style: GoogleFonts.playfairDisplay(
                    color: beigeColor,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 8),

                Text(
                  'Deel een smaakvolle proeverij of festival met de community van ambachtelijke liefhebbers.',
                  style: GoogleFonts.inter(
                    color: secondaryTextColor,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),

                const SizedBox(height: 24),

                _buildSectionHeader(
                  Icons.info_outline,
                  'BASIS INFORMATIE',
                ),

                const SizedBox(height: 12),

                _buildTextFieldLabel(
                  'NAAM VAN HET EVENEMENT',
                ),

                const SizedBox(height: 6),

                _buildCustomTextField(
                  controller: _nameController,
                  hintText:
                      'Bijv. Herfst Bokbier Festival 2026',
                ),

                const SizedBox(height: 16),

                _buildTextFieldLabel(
                  'TYPE EVENEMENT',
                ),

                const SizedBox(height: 6),

                _buildDropdownField(),

                const SizedBox(height: 24),

                _buildSectionHeader(
                  Icons.calendar_today_outlined,
                  'DATUM & TIJD',
                ),

                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          _buildTextFieldLabel(
                            'DATUM',
                          ),

                          const SizedBox(height: 6),

                          InkWell(
                            onTap: () =>
                                _selectDate(context),
                            child: Container(
                              padding:
                                  const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 14,
                              ),
                              decoration: BoxDecoration(
                                color: inputColor,
                                borderRadius:
                                    BorderRadius.circular(8),
                                border: Border.all(
                                  color: borderColor,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment
                                        .spaceBetween,
                                children: [
                                  Text(
                                    _selectedDate == null
                                        ? 'Kies datum'
                                        : '${_selectedDate!.day}-'
                                            '${_selectedDate!.month}-'
                                            '${_selectedDate!.year}',
                                    style:
                                        GoogleFonts.inter(
                                      color:
                                          _selectedDate ==
                                                  null
                                              ? secondaryTextColor
                                                  .withOpacity(
                                                  0.6,
                                                )
                                              : textColor,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const Icon(
                                    Icons.calendar_month,
                                    color: beigeColor,
                                    size: 20,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(width: 16),

                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          _buildTextFieldLabel(
                            'TIJD',
                          ),

                          const SizedBox(height: 6),

                          InkWell(
                            onTap: () =>
                                _selectTime(context),
                            child: Container(
                              padding:
                                  const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 14,
                              ),
                              decoration: BoxDecoration(
                                color: inputColor,
                                borderRadius:
                                    BorderRadius.circular(8),
                                border: Border.all(
                                  color: borderColor,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment
                                        .spaceBetween,
                                children: [
                                  Text(
                                    _selectedTime == null
                                        ? 'Kies tijd'
                                        : _selectedTime!
                                            .format(context),
                                    style:
                                        GoogleFonts.inter(
                                      color:
                                          _selectedTime ==
                                                  null
                                              ? secondaryTextColor
                                                  .withOpacity(
                                                  0.6,
                                                )
                                              : textColor,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const Icon(
                                    Icons.access_time,
                                    color: beigeColor,
                                    size: 20,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                _buildSectionHeader(
                  Icons.image_outlined,
                  'AFBEELDING & FLYER',
                ),

                const SizedBox(height: 12),

                _buildTextFieldLabel(
                  'KIES AFBEELDING (ACHTERGROND)',
                ),

                const SizedBox(height: 6),

                GestureDetector(
                  onTap: _pickImage,
                  child: Container(
                    height: 160,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: inputColor,
                      borderRadius:
                          BorderRadius.circular(8),
                      border: Border.all(
                        color: borderColor,
                      ),
                    ),
                    child: _imageFile != null
                        ? ClipRRect(
                            borderRadius:
                                BorderRadius.circular(8),
                            child: Image.file(
                              _imageFile!,
                              fit: BoxFit.cover,
                              width: double.infinity,
                            ),
                          )
                        : _webImageBytes != null
                            ? ClipRRect(
                                borderRadius:
                                    BorderRadius.circular(8),
                                child: Image.memory(
                                  _webImageBytes!,
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                ),
                              )
                            : Column(
                                mainAxisAlignment:
                                    MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.add_a_photo,
                                    color: beigeColor,
                                    size: 32,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Klik om een achtergrondfoto te selecteren',
                                    style:
                                        GoogleFonts.inter(
                                      color:
                                          secondaryTextColor,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                  ),
                ),

                const SizedBox(height: 24),

                _buildSectionHeader(
                  Icons.location_on_outlined,
                  'LOCATIE & GEGEVENS',
                ),

                const SizedBox(height: 12),

                _buildTextFieldLabel(
                  'STRAATNAAM',
                ),

                const SizedBox(height: 6),

                _buildCustomTextField(
                  controller: _streetController,
                  hintText: 'Dorpsstraat',
                ),

                const SizedBox(height: 16),

                _buildTextFieldLabel(
                  'HUISNUMMER',
                ),

                const SizedBox(height: 6),

                _buildCustomTextField(
                  controller: _houseNumberController,
                  hintText: '42 A',
                ),

                const SizedBox(height: 16),

                _buildTextFieldLabel(
                  'POSTCODE',
                ),

                const SizedBox(height: 6),

                _buildCustomTextField(
                  controller: _postalCodeController,
                  hintText: '1234 AB',
                ),

                const SizedBox(height: 16),

                _buildTextFieldLabel(
                  'STAD',
                ),

                const SizedBox(height: 6),

                _buildCustomTextField(
                  controller: _cityController,
                  hintText: 'Utrecht',
                ),

                const SizedBox(height: 16),

                _buildTextFieldLabel(
                  'ZAAL / LOCATIE NAAM',
                ),

                const SizedBox(height: 6),

                _buildCustomTextField(
                  controller: _locationNameController,
                  hintText: 'De Oude Brouwerij',
                ),

                const SizedBox(height: 24),

                _buildSectionHeader(
                  Icons.description_outlined,
                  'OMSCHRIJVING & PROGRAMMA',
                ),

                const SizedBox(height: 12),

                _buildTextArea(
                  controller: _descriptionController,
                  hintText:
                      'Licht hier de smaakvolle brouwerij en speciaalbieren toe...',
                ),

                const SizedBox(height: 24),

                _buildSectionHeader(
                  Icons.confirmation_number_outlined,
                  'TICKETS & PRIJZEN',
                ),

                const SizedBox(height: 12),

                _buildTextFieldLabel(
                  'TICKET TYPE',
                ),

                const SizedBox(height: 8),

                _buildCheckboxOption(
                  'Regulier',
                  _isRegularChecked,
                  (value) {
                    setState(() {
                      _isRegularChecked =
                          value ?? false;
                    });
                  },
                ),

                _buildCheckboxOption(
                  'Bier-ticket',
                  _isBierTicketChecked,
                  (value) {
                    setState(() {
                      _isBierTicketChecked =
                          value ?? false;
                    });
                  },
                ),

                _buildCheckboxOption(
                  'VIP-arrangement',
                  _isVipChecked,
                  (value) {
                    setState(() {
                      _isVipChecked =
                          value ?? false;
                    });
                  },
                ),

                const SizedBox(height: 32),

                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: beigeColor,
                      foregroundColor: backgroundColor,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: _isLoading
                        ? null
                        : _saveEventToSupabase,
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child:
                                CircularProgressIndicator(
                              color: backgroundColor,
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            'Evenement publiceren',
                            style: GoogleFonts.inter(
                              fontWeight:
                                  FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                  ),
                ),

                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(
    IconData icon,
    String title,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: beigeColor,
            size: 18,
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: GoogleFonts.inter(
              color: beigeColor,
              fontWeight: FontWeight.bold,
              fontSize: 11,
              letterSpacing: 1.0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextFieldLabel(String label) {
    return Text(
      label,
      style: GoogleFonts.inter(
        color: secondaryTextColor,
        fontSize: 11,
        fontWeight: FontWeight.bold,
        letterSpacing: 0.8,
      ),
    );
  }

  Widget _buildCustomTextField({
    TextEditingController? controller,
    required String hintText,
    IconData? suffixIcon,
    String? prefixText,
  }) {
    return TextFormField(
      controller: controller,
      validator: (value) {
        if (value == null ||
            value.trim().isEmpty) {
          return 'Dit veld is verplicht';
        }

        return null;
      },
      style: GoogleFonts.inter(
        color: textColor,
        fontSize: 14,
      ),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: GoogleFonts.inter(
          color: secondaryTextColor.withOpacity(0.6),
          fontSize: 13,
        ),
        prefixText: prefixText,
        prefixStyle: GoogleFonts.inter(
          color: beigeColor,
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
        suffixIcon: suffixIcon != null
            ? Icon(
                suffixIcon,
                color: beigeColor,
                size: 20,
              )
            : null,
        filled: true,
        fillColor: inputColor,
        contentPadding:
            const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(8),
          borderSide:
              const BorderSide(
            color: borderColor,
          ),
        ),
        enabledBorder:
            OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(8),
          borderSide:
              const BorderSide(
            color: borderColor,
          ),
        ),
        focusedBorder:
            OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(8),
          borderSide:
              const BorderSide(
            color: beigeColor,
          ),
        ),
      ),
    );
  }

  Widget _buildDropdownField() {
    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 12,
      ),
      decoration: BoxDecoration(
        color: inputColor,
        borderRadius:
            BorderRadius.circular(8),
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
            Icons.arrow_drop_down,
            color: beigeColor,
          ),
          style: GoogleFonts.inter(
            color: textColor,
            fontSize: 14,
          ),
          items: _eventTypeOptions
              .map<DropdownMenuItem<String>>(
            (String value) {
              return DropdownMenuItem<String>(
                value: value,
                child: Text(value),
              );
            },
          ).toList(),
          onChanged: (String? newValue) {
            if (newValue == null) return;

            setState(() {
              _selectedEventType = newValue;
            });
          },
        ),
      ),
    );
  }

  Widget _buildTextArea({
    TextEditingController? controller,
    required String hintText,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: 4,
      validator: (value) {
        if (value == null ||
            value.trim().isEmpty) {
          return 'Dit veld is verplicht';
        }

        return null;
      },
      style: GoogleFonts.inter(
        color: textColor,
        fontSize: 14,
      ),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: GoogleFonts.inter(
          color:
              secondaryTextColor.withOpacity(0.6),
          fontSize: 13,
        ),
        filled: true,
        fillColor: inputColor,
        contentPadding:
            const EdgeInsets.all(12),
        border: OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(8),
          borderSide:
              const BorderSide(
            color: borderColor,
          ),
        ),
        enabledBorder:
            OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(8),
          borderSide:
              const BorderSide(
            color: borderColor,
          ),
        ),
        focusedBorder:
            OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(8),
          borderSide:
              const BorderSide(
            color: beigeColor,
          ),
        ),
      ),
    );
  }

  Widget _buildCheckboxOption(
    String title,
    bool value,
    ValueChanged<bool?> onChanged,
  ) {
    return Row(
      children: [
        SizedBox(
          height: 24,
          width: 24,
          child: Checkbox(
            value: value,
            onChanged: onChanged,
            activeColor: beigeColor,
            checkColor: backgroundColor,
            side: const BorderSide(
              color: secondaryTextColor,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: GoogleFonts.inter(
            color: textColor,
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}