import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../auth/auth_service.dart';

class EditProfilePage extends StatefulWidget {
  final AppUser user;

  const EditProfilePage({super.key, required this.user});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _authService = AuthService();
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late AppUser _user;
  Uint8List? _pendingAvatarBytes;
  String? _pendingAvatarExt;
  bool _isSaving = false;
  bool _isPickingImage = false;
  String? _error;

  static const _bg = Color(0xFF1E1712);
  static const _card = Color(0xFF2C221C);
  static const _gold = Color(0xFFD4B28C);
  static const _cream = Color(0xFFEFE6DD);
  static const _muted = Color(0xFF9E8A7D);
  static const _field = Color(0xFF241B16);

  @override
  void initState() {
    super.initState();
    _user = widget.user;
    _nameController = TextEditingController(text: _user.name);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    setState(() => _isPickingImage = true);
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      final ext = picked.name.contains('.') ? picked.name.split('.').last.toLowerCase() : 'jpg';
      setState(() {
        _pendingAvatarBytes = bytes;
        _pendingAvatarExt = ext == 'jpeg' ? 'jpg' : ext;
      });
    } finally {
      if (mounted) setState(() => _isPickingImage = false);
    }
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _isSaving = true;
      _error = null;
    });
    try {
      String? newAvatarUrl;
      if (_pendingAvatarBytes != null) {
        newAvatarUrl = await _authService.uploadAvatar(
          userId: _user.id,
          bytes: _pendingAvatarBytes!,
          fileExt: _pendingAvatarExt!,
        );
      }
      await _authService.updateProfile(userId: _user.id, name: _nameController.text.trim());
      if (!mounted) return;
      Navigator.of(context).pop(
        _user.copyWith(name: _nameController.text.trim(), avatarUrl: newAvatarUrl),
      );
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_back, color: _cream),
                ),
                Text(
                  'Profiel bewerken',
                  style: GoogleFonts.playfairDisplay(
                    color: _cream,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Form(
              key: _formKey,
              child: Column(
                children: [
                  Center(
                    child: GestureDetector(
                      onTap: _isPickingImage ? null : _pickImage,
                      child: Stack(
                        children: [
                          Container(
                            width: 110,
                            height: 110,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: const Color(0xFF3C3028),
                              border: Border.all(color: _gold.withOpacity(0.5), width: 2),
                              image: _pendingAvatarBytes != null
                                  ? DecorationImage(
                                      image: MemoryImage(_pendingAvatarBytes!),
                                      fit: BoxFit.cover,
                                    )
                                  : (_user.avatarUrl != null
                                      ? DecorationImage(
                                          image: NetworkImage(_user.avatarUrl!),
                                          fit: BoxFit.cover,
                                        )
                                      : null),
                            ),
                            child: (_pendingAvatarBytes == null && _user.avatarUrl == null)
                                ? const Center(
                                    child: Icon(Icons.person, color: _muted, size: 56),
                                  )
                                : null,
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: const BoxDecoration(
                                color: _gold,
                                shape: BoxShape.circle,
                              ),
                              child: _isPickingImage
                                  ? const SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: _bg,
                                      ),
                                    )
                                  : const Icon(Icons.camera_alt, color: _bg, size: 16),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: Text(
                      'Tik op de foto om te wijzigen',
                      style: GoogleFonts.inter(color: _muted, fontSize: 12),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _card,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _nameController,
                          style: GoogleFonts.inter(color: _cream),
                          validator: (v) =>
                              (v == null || v.trim().isEmpty) ? 'Vul je naam in.' : null,
                          decoration: InputDecoration(
                            labelText: 'Naam',
                            prefixIcon: const Icon(Icons.person_outline, color: _muted, size: 20),
                            labelStyle: GoogleFonts.inter(color: _muted),
                            filled: true,
                            fillColor: _field,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            errorStyle: GoogleFonts.inter(color: Colors.redAccent, fontSize: 11),
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          initialValue: _user.email,
                          enabled: false,
                          style: GoogleFonts.inter(color: _muted),
                          decoration: InputDecoration(
                            labelText: 'E-mail',
                            prefixIcon: const Icon(Icons.mail_outline, color: _muted, size: 20),
                            labelStyle: GoogleFonts.inter(color: _muted),
                            filled: true,
                            fillColor: _field.withOpacity(0.6),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 14),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(color: Colors.redAccent, fontSize: 13),
                    ),
                  ],
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _gold,
                        foregroundColor: _bg,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: _bg),
                            )
                          : Text(
                              'Opslaan',
                              style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
