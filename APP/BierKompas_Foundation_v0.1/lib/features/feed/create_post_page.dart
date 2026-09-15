import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../../shared/image_utils.dart';
import 'feed_service.dart';

const _background = Color(0xFF1E1712);
const _cardColor = Color(0xFF2C221C);
const _primary = Color(0xFFD4B28C);
const _onPrimary = Color(0xFF1E1712);
const _onSurface = Color(0xFFEFE6DD);
const _onSurfaceVariant = Color(0xFF9E8A7D);
const _outlineVariant = Color(0xFF3E312A);

/// Scherm om zelf een post te plaatsen in de Ontdek-feed.
class CreatePostPage extends StatefulWidget {
  const CreatePostPage({super.key});

  @override
  State<CreatePostPage> createState() => _CreatePostPageState();
}

class _CreatePostPageState extends State<CreatePostPage> {
  final _feedService = FeedService();
  final _bodyController = TextEditingController();

  Uint8List? _imageBytes;
  String? _imageExt;
  bool _posting = false;
  bool _pickingImage = false;

  @override
  void dispose() {
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    setState(() => _pickingImage = true);
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 85,
      );
      if (picked == null) return;
      final rawBytes = await picked.readAsBytes();
      // Altijd naar JPEG omzetten: sommige galerij-apps leveren WebP met een
      // kleurprofiel dat Flutter niet kan tekenen, wat een lege/zwarte foto oplevert.
      final bytes = normalizeToJpeg(rawBytes);
      if (!mounted) return;
      setState(() {
        _imageBytes = bytes;
        _imageExt = 'jpg';
      });
    } finally {
      if (mounted) setState(() => _pickingImage = false);
    }
  }

  void _removeImage() => setState(() {
        _imageBytes = null;
        _imageExt = null;
      });

  Future<void> _submit() async {
    final body = _bodyController.text.trim();
    if (body.isEmpty || _posting) return;
    setState(() => _posting = true);
    try {
      String? imageUrl;
      final bytes = _imageBytes;
      if (bytes != null) {
        imageUrl = await _feedService.uploadImage(bytes: bytes, fileExt: _imageExt ?? 'jpg');
      }
      final post = await _feedService.createPost(body: body, imageUrl: imageUrl);
      if (!mounted) return;
      Navigator.of(context).pop(post);
    } on FeedException catch (e) {
      if (!mounted) return;
      setState(() => _posting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Posten mislukt: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final canPost = _bodyController.text.trim().isNotEmpty && !_posting;
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: _cardColor,
        foregroundColor: _onSurface,
        iconTheme: const IconThemeData(color: _onSurface),
        elevation: 0,
        title: Text('Nieuwe post', style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.bold)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: TextButton(
                onPressed: canPost ? _submit : null,
                style: TextButton.styleFrom(
                  backgroundColor: canPost ? _primary : _outlineVariant,
                  foregroundColor: canPost ? _onPrimary : _onSurfaceVariant,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
                child: _posting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: _onPrimary),
                      )
                    : Text('Plaatsen', style: GoogleFonts.openSans(fontWeight: FontWeight.bold, fontSize: 13)),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Deel iets met de BierKompas-gemeenschap: een biertip, een ervaring of gewoon een gedachte.',
                style: GoogleFonts.openSans(color: _onSurfaceVariant, fontSize: 13),
              ),
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  color: _cardColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _outlineVariant.withOpacity(0.6)),
                ),
                padding: const EdgeInsets.all(14),
                child: TextField(
                  controller: _bodyController,
                  maxLines: 6,
                  minLines: 4,
                  maxLength: 500,
                  onChanged: (_) => setState(() {}),
                  style: GoogleFonts.openSans(color: _onSurface, fontSize: 15),
                  cursorColor: _primary,
                  decoration: InputDecoration(
                    hintText: 'Wat wil je delen?',
                    hintStyle: GoogleFonts.openSans(color: _onSurfaceVariant),
                    border: InputBorder.none,
                    counterStyle: GoogleFonts.openSans(color: _onSurfaceVariant, fontSize: 11),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (_imageBytes != null)
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.memory(_imageBytes!, width: double.infinity, height: 180, fit: BoxFit.cover),
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: GestureDetector(
                        onTap: _removeImage,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                          child: const Icon(Icons.close, color: Colors.white, size: 18),
                        ),
                      ),
                    ),
                  ],
                )
              else
                OutlinedButton.icon(
                  onPressed: _pickingImage ? null : _pickImage,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _primary,
                    side: const BorderSide(color: _primary),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  icon: _pickingImage
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: _primary),
                        )
                      : const Icon(Icons.image_outlined),
                  label: Text('Foto toevoegen', style: GoogleFonts.openSans(fontWeight: FontWeight.w600)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
