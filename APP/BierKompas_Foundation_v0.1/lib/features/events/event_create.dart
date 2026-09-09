import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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
  final TextEditingController _houseNumberController = TextEditingController();
  final TextEditingController _postalCodeController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _locationNameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  String _selectedEventType = 'Festival';
  bool _isRegularChecked = false;
  bool _isBierTicketChecked = false;
  bool _isVipChecked = false;

  bool _isLoading = false;

  static const Color backgroundColor = Color(0xFF1E1712);
  static const Color cardColor = Color(0xFF2C221C);
  static const Color inputColor = Color(0xFF1E1712);
  static const Color borderColor = Color(0xFF3C3028);
  static const Color beigeColor = Color(0xFFD4B28C);
  static const Color textColor = Color(0xFFEFE6DD);
  static const Color secondaryTextColor = Color(0xFF9E8A7D);

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

  Future<void> _saveEventToSupabase() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vul alle verplichte velden correct in.'),
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

      await supabase.from('events').insert({
        'user_id': user.id,
        'name': _nameController.text.trim(),
        'event_type': _selectedEventType,
        'start_date': DateTime.now().toIso8601String(),
        'end_date': DateTime.now().add(const Duration(hours: 4)).toIso8601String(),
        'opening_hours': '10:00 - 22:00',
        'street': _streetController.text.trim(),
        'house_number': _houseNumberController.text.trim(),
        'postal_code': _postalCodeController.text.trim(),
        'city': _cityController.text.trim(),
        'location_name': _locationNameController.text.trim(),
        'description': _descriptionController.text.trim(),
        'ticket_regular': _isRegularChecked,
        'ticket_beer': _isBierTicketChecked,
        'ticket_vip': _isVipChecked,
        'price': 0.00,
        'price_incl_btw': true,
        'price_excl_btw': false,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Evenement succesvol opgeslagen!')),
        );
        Navigator.pop(context);
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fout bij opslaan: $error'),
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
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: Container(
          decoration: const BoxDecoration(
              borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(24),
                  bottomRight: Radius.circular(24),
                ),
            color: Color(0xFF2C221C),
          ),
          child: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            centerTitle: true,
            leading: IconButton(
              icon: const Icon(Icons.close, color: textColor),
              onPressed: () => Navigator.pop(context),
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
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
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
                _buildSectionHeader(Icons.info_outline, 'BASIS INFORMATIE'),
                const SizedBox(height: 12),
                _buildTextFieldLabel('NAAM VAN HET EVENEMENT'),
                const SizedBox(height: 6),
                _buildCustomTextField(
                  controller: _nameController,
                  hintText: 'Bijv. Herfst Bokbier Festival 2026',
                ),
                const SizedBox(height: 16),
                _buildTextFieldLabel('TYPE EVENEMENT'),
                const SizedBox(height: 6),
                _buildDropdownField(),
                const SizedBox(height: 24),
                _buildSectionHeader(Icons.location_on_outlined, 'LOCATIE & GEGEVENS'),
                const SizedBox(height: 12),
                _buildTextFieldLabel('STRAATNAAM'),
                const SizedBox(height: 6),
                _buildCustomTextField(
                  controller: _streetController,
                  hintText: 'Dorpsstraat',
                ),
                const SizedBox(height: 16),
                _buildTextFieldLabel('HUISNUMMER'),
                const SizedBox(height: 6),
                _buildCustomTextField(
                  controller: _houseNumberController,
                  hintText: '42 A',
                ),
                const SizedBox(height: 16),
                _buildTextFieldLabel('POSTCODE'),
                const SizedBox(height: 6),
                _buildCustomTextField(
                  controller: _postalCodeController,
                  hintText: '1234 AB',
                ),
                const SizedBox(height: 16),
                _buildTextFieldLabel('STAD'),
                const SizedBox(height: 6),
                _buildCustomTextField(
                  controller: _cityController,
                  hintText: 'Utrecht',
                ),
                const SizedBox(height: 16),
                _buildTextFieldLabel('ZAAL / LOCATIE NAAM'),
                const SizedBox(height: 6),
                _buildCustomTextField(
                  controller: _locationNameController,
                  hintText: 'De Oude Brouwerij',
                ),
                const SizedBox(height: 24),
                _buildSectionHeader(Icons.description_outlined, 'OMSCHRIJVING & PROGRAMMA'),
                const SizedBox(height: 12),
                _buildTextArea(
                  controller: _descriptionController,
                  hintText: 'Licht hier de smaakvolle brouwerij en speciaalbieren toe...',
                ),
                const SizedBox(height: 24),
                _buildSectionHeader(Icons.confirmation_number_outlined, 'TICKETS & PRIJZEN'),
                const SizedBox(height: 12),
                _buildTextFieldLabel('TICKET TYPE'),
                const SizedBox(height: 8),
                _buildCheckboxOption(
                  'Regulier',
                  _isRegularChecked,
                  (val) => setState(() => _isRegularChecked = val!),
                ),
                _buildCheckboxOption(
                  'Bier-ticket',
                  _isBierTicketChecked,
                  (val) => setState(() => _isBierTicketChecked = val!),
                ),
                _buildCheckboxOption(
                  'VIP-arrangement',
                  _isVipChecked,
                  (val) => setState(() => _isVipChecked = val!),
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
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: _isLoading ? null : _saveEventToSupabase,
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(color: backgroundColor, strokeWidth: 2),
                          )
                        : Text(
                            'Evenement publiceren',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.bold,
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

  Widget _buildSectionHeader(IconData icon, String title) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, color: beigeColor, size: 18),
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
        if (value == null || value.trim().isEmpty) {
          return 'Dit veld is verplicht';
        }
        return null;
      },
      style: GoogleFonts.inter(color: textColor, fontSize: 14),
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
            ? Icon(suffixIcon, color: beigeColor, size: 20)
            : null,
        filled: true,
        fillColor: inputColor,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: beigeColor),
        ),
      ),
    );
  }

  Widget _buildDropdownField() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: inputColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedEventType,
          isExpanded: true,
          dropdownColor: cardColor,
          icon: const Icon(Icons.arrow_drop_down, color: beigeColor),
          style: GoogleFonts.inter(color: textColor, fontSize: 14),
          items: <String>[
            'Festival',
            'Proeverij',
            'Brouwersmarkt',
            'Lezing',
          ].map<DropdownMenuItem<String>>((String value) {
            return DropdownMenuItem<String>(
              value: value,
              child: Text(value),
            );
          }).toList(),
          onChanged: (String? newValue) {
            setState(() {
              _selectedEventType = newValue!;
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
        if (value == null || value.trim().isEmpty) {
          return 'Dit veld is verplicht';
        }
        return null;
      },
      style: GoogleFonts.inter(color: textColor, fontSize: 14),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: GoogleFonts.inter(
          color: secondaryTextColor.withOpacity(0.6),
          fontSize: 13,
        ),
        filled: true,
        fillColor: inputColor,
        contentPadding: const EdgeInsets.all(12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: beigeColor),
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
            side: const BorderSide(color: secondaryTextColor),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: GoogleFonts.inter(color: textColor, fontSize: 13),
        ),
      ],
    );
  }
}