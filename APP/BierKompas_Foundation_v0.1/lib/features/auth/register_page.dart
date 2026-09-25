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

class _RegisterPageState extends State<RegisterPage>
    with WidgetsBindingObserver {
  final _formKey = GlobalKey<FormState>();
  final _authService = AuthService();

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _isLoading = false;
  bool _isGoogleLoading = false;
  bool _isOutlookLoading = false;
  bool _obscurePassword = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (mounted) {
        setState(() {
          _isGoogleLoading = false;
          _isOutlookLoading = false;
        });
      }
    }
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

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
          MaterialPageRoute(
            builder: (_) => CheckEmailPage(
              email: result.user.email,
            ),
          ),
          (route) => false,
        );
      } else {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) => ConsentPage(
              user: result.user,
            ),
          ),
          (route) => false,
        );
      }
    } on AuthException catch (e) {
      if (!mounted) return;

      setState(() {
        _error = e.message;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _googleRegister() async {
    if (_isGoogleLoading || _isOutlookLoading || _isLoading) {
      return;
    }

    setState(() {
      _isGoogleLoading = true;
      _error = null;
    });

    try {
      await _authService.loginWithGoogle();
    } on AuthException catch (e) {
      if (!mounted) return;

      setState(() {
        _error = e.message;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isGoogleLoading = false;
        });
      }
    }
  }

  Future<void> _outlookRegister() async {
    if (_isGoogleLoading || _isOutlookLoading || _isLoading) {
      return;
    }

    setState(() {
      _isOutlookLoading = true;
      _error = null;
    });

    try {
      await _authService.loginWithOutlook();
    } on AuthException catch (e) {
      if (!mounted) return;

      setState(() {
        _error = e.message;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isOutlookLoading = false;
        });
      }
    }
  }

  bool get _socialLoading =>
      _isGoogleLoading || _isOutlookLoading;

  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFFD4B28C);
    const cream = Color(0xFFEFE6DD);
    const muted = Color(0xFF9E8A7D);
    const card = Color(0xFF2C221C);
    const field = Color(0xFF241B16);
    const background = Color(0xFF1E1712);

    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(
          color: cream,
        ),
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: 24,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: 400,
              ),
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
                    style: GoogleFonts.inter(
                      color: muted,
                      fontSize: 13,
                    ),
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
                        crossAxisAlignment:
                            CrossAxisAlignment.stretch,
                        children: [
                          _buildTextField(
                            controller: _nameController,
                            label: 'Naam',
                            icon: Icons.person_outline,
                            field: field,
                            cream: cream,
                            muted: muted,
                            validator: (v) {
                              if (v == null ||
                                  v.trim().isEmpty) {
                                return 'Vul je naam in.';
                              }

                              return null;
                            },
                          ),
                          const SizedBox(height: 14),
                          _buildTextField(
                            controller: _emailController,
                            label: 'E-mail',
                            icon: Icons.mail_outline,
                            field: field,
                            cream: cream,
                            muted: muted,
                            keyboardType:
                                TextInputType.emailAddress,
                            validator: (v) {
                              if (v == null ||
                                  v.trim().isEmpty) {
                                return 'Vul je e-mailadres in.';
                              }

                              return null;
                            },
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
                            toggleObscure: () {
                              setState(() {
                                _obscurePassword =
                                    !_obscurePassword;
                              });
                            },
                            validator: (v) {
                              if (v == null || v.isEmpty) {
                                return 'Vul een wachtwoord in.';
                              }

                              if (v.length < 8) {
                                return 'Minimaal 8 tekens.';
                              }

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
                              if (v !=
                                  _passwordController.text) {
                                return 'Wachtwoorden komen niet overeen.';
                              }

                              return null;
                            },
                          ),
                          if (_error != null) ...[
                            const SizedBox(height: 14),
                            _buildError(_error!),
                          ],
                          const SizedBox(height: 20),
                          SizedBox(
                            height: 48,
                            child: ElevatedButton(
                              onPressed: _isLoading || _socialLoading
                                  ? null
                                  : _submit,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: gold,
                                disabledBackgroundColor:
                                    gold.withOpacity(0.55),
                                foregroundColor: background,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(12),
                                ),
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child:
                                          CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: background,
                                      ),
                                    )
                                  : Text(
                                      'Registreren',
                                      style: GoogleFonts.inter(
                                        fontWeight:
                                            FontWeight.bold,
                                        fontSize: 15,
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          _buildDivider(muted),
                          const SizedBox(height: 20),
                          _buildGoogleButton(),
                          const SizedBox(height: 12),
                          _buildMicrosoftButton(),
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

  Widget _buildGoogleButton() {
    const cream = Color(0xFFEFE6DD);
    const field = Color(0xFF241B16);
    const muted = Color(0xFF9E8A7D);

    return SizedBox(
      height: 50,
      child: OutlinedButton(
        onPressed: _isLoading || _isOutlookLoading
            ? null
            : _googleRegister,
        style: OutlinedButton.styleFrom(
          backgroundColor: field,
          side: BorderSide(
            color: muted.withOpacity(0.3),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(13),
          ),
        ),
        child: _isGoogleLoading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: cream,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _googleLogo(),
                  const SizedBox(width: 12),
                  Text(
                    'Registreren met Google',
                    style: GoogleFonts.inter(
                      color: cream,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildMicrosoftButton() {
    const cream = Color(0xFFEFE6DD);
    const field = Color(0xFF241B16);
    const muted = Color(0xFF9E8A7D);

    return SizedBox(
      height: 50,
      child: OutlinedButton(
        onPressed: _isLoading || _isGoogleLoading
            ? null
            : _outlookRegister,
        style: OutlinedButton.styleFrom(
          backgroundColor: field,
          side: BorderSide(
            color: muted.withOpacity(0.3),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(13),
          ),
        ),
        child: _isOutlookLoading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: cream,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _microsoftLogo(),
                  const SizedBox(width: 12),
                  Text(
                    'Registreren met Outlook',
                    style: GoogleFonts.inter(
                      color: cream,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _googleLogo() {
    return Text(
      'G',
      style: GoogleFonts.inter(
        color: const Color(0xFF4285F4),
        fontSize: 22,
        fontWeight: FontWeight.w800,
      ),
    );
  }

  Widget _microsoftLogo() {
    return SizedBox(
      width: 20,
      height: 20,
      child: GridView.count(
        crossAxisCount: 2,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 2,
        crossAxisSpacing: 2,
        children: const [
          ColoredBox(color: Color(0xFFF25022)),
          ColoredBox(color: Color(0xFF7FBA00)),
          ColoredBox(color: Color(0xFF00A4EF)),
          ColoredBox(color: Color(0xFFFFB900)),
        ],
      ),
    );
  }

  Widget _buildDivider(Color muted) {
    return Row(
      children: [
        Expanded(
          child: Divider(
            color: muted.withOpacity(0.3),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 12,
          ),
          child: Text(
            'OF',
            style: GoogleFonts.inter(
              color: muted,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(
          child: Divider(
            color: muted.withOpacity(0.3),
          ),
        ),
      ],
    );
  }

  Widget _buildError(String error) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: Colors.redAccent.withOpacity(0.4),
        ),
      ),
      child: Text(
        error,
        style: GoogleFonts.inter(
          color: Colors.redAccent,
          fontSize: 13,
        ),
        textAlign: TextAlign.center,
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
      style: GoogleFonts.inter(
        color: cream,
      ),
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(
          icon,
          color: muted,
          size: 20,
        ),
        suffixIcon: toggleObscure == null
            ? null
            : IconButton(
                icon: Icon(
                  obscure
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  color: muted,
                  size: 20,
                ),
                onPressed: toggleObscure,
              ),
        labelStyle: GoogleFonts.inter(
          color: muted,
        ),
        filled: true,
        fillColor: field,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        errorStyle: GoogleFonts.inter(
          color: Colors.redAccent,
          fontSize: 11,
        ),
      ),
    );
  }
}