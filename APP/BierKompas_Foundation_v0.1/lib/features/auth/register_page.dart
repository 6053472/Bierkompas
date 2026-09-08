import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'auth_service.dart';
import 'check_email_page.dart';
import 'consent_page.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _authService = AuthService();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final result = await _authService.register(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      if (!mounted) return;
      if (result.needsEmailConfirmation) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => CheckEmailPage(email: result.user.email)),
          (route) => false,
        );
      } else {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => ConsentPage(user: result.user)),
          (route) => false,
        );
      }
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFFD4B28C);
    const cream = Color(0xFFEFE6DD);
    const muted = Color(0xFF9E8A7D);
    const card = Color(0xFF2C221C);
    const field = Color(0xFF241B16);

    return Scaffold(
      backgroundColor: const Color(0xFF1E1712),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: cream),
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Account aanmaken',
                    style: GoogleFonts.playfairDisplay(
                      color: cream,
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Word lid van Bierkompas en ontdek ambachtelijk bier.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(color: muted, fontSize: 13),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: card,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.25),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildTextField(
                            controller: _nameController,
                            label: 'Naam',
                            icon: Icons.person_outline,
                            field: field,
                            cream: cream,
                            muted: muted,
                            validator: (v) =>
                                (v == null || v.trim().isEmpty) ? 'Vul je naam in.' : null,
                          ),
                          const SizedBox(height: 14),
                          _buildTextField(
                            controller: _emailController,
                            label: 'E-mail',
                            icon: Icons.mail_outline,
                            field: field,
                            cream: cream,
                            muted: muted,
                            keyboardType: TextInputType.emailAddress,
                            validator: (v) =>
                                (v == null || v.trim().isEmpty) ? 'Vul je e-mailadres in.' : null,
                          ),
                          const SizedBox(height: 14),
                          _buildTextField(
                            controller: _passwordController,
                            label: 'Wachtwoord',
                            icon: Icons.lock_outline,
                            field: field,
                            cream: cream,
                            muted: muted,
                            obscure: _obscurePassword,
                            toggleObscure: () =>
                                setState(() => _obscurePassword = !_obscurePassword),
                            validator: (v) {
                              if (v == null || v.isEmpty) return 'Vul een wachtwoord in.';
                              if (v.length < 8) return 'Minimaal 8 tekens.';
                              return null;
                            },
                          ),
                          const SizedBox(height: 14),
                          _buildTextField(
                            controller: _confirmController,
                            label: 'Bevestig wachtwoord',
                            icon: Icons.lock_outline,
                            field: field,
                            cream: cream,
                            muted: muted,
                            obscure: _obscurePassword,
                            validator: (v) {
                              if (v != _passwordController.text) return 'Wachtwoorden komen niet overeen.';
                              return null;
                            },
                          ),
                          if (_error != null) ...[
                            const SizedBox(height: 14),
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.redAccent.withOpacity(0.4)),
                              ),
                              child: Text(
                                _error!,
                                style: GoogleFonts.inter(color: Colors.redAccent, fontSize: 13),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                          const SizedBox(height: 20),
                          SizedBox(
                            height: 48,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _submit,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: gold,
                                foregroundColor: const Color(0xFF1E1712),
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Color(0xFF1E1712),
                                      ),
                                    )
                                  : Text(
                                      'Registreren',
                                      style: GoogleFonts.inter(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required Color field,
    required Color cream,
    required Color muted,
    TextInputType? keyboardType,
    bool obscure = false,
    VoidCallback? toggleObscure,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscure,
      style: GoogleFonts.inter(color: cream),
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: muted, size: 20),
        suffixIcon: toggleObscure == null
            ? null
            : IconButton(
                icon: Icon(
                  obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                  color: muted,
                  size: 20,
                ),
                onPressed: toggleObscure,
              ),
        labelStyle: GoogleFonts.inter(color: muted),
        filled: true,
        fillColor: field,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        errorStyle: GoogleFonts.inter(color: Colors.redAccent, fontSize: 11),
      ),
    );
  }
}
