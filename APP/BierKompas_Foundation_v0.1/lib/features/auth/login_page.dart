import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../home/home_page.dart';
import 'auth_service.dart';
import 'auth_storage.dart';
import 'consent_page.dart';
import 'register_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage>
    with WidgetsBindingObserver {
  final _formKey = GlobalKey<FormState>();
  final _authService = AuthService();

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

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
    _emailController.dispose();
    _passwordController.dispose();
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
      final user = await _authService.login(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      final hasConsent = await AuthStorage.hasCurrentConsent();

      if (!mounted) return;

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => hasConsent
              ? const HomePage()
              : ConsentPage(user: user),
        ),
        (route) => false,
      );
    } on Exception catch (e) {
      if (!mounted) return;

      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _googleLogin() async {
    if (_isGoogleLoading || _isOutlookLoading || _isLoading) {
      return;
    }

    setState(() {
      _isGoogleLoading = true;
      _error = null;
    });

    try {
      await _authService.loginWithGoogle();
    } on Exception catch (e) {
      if (!mounted) return;

      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isGoogleLoading = false;
        });
      }
    }
  }

  Future<void> _outlookLogin() async {
    if (_isGoogleLoading || _isOutlookLoading || _isLoading) {
      return;
    }

    setState(() {
      _isOutlookLoading = true;
      _error = null;
    });

    try {
      await _authService.loginWithOutlook();
    } on Exception catch (e) {
      if (!mounted) return;

      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isOutlookLoading = false;
        });
      }
    }
  }

  bool get _socialLoading => _isGoogleLoading || _isOutlookLoading;

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
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: 24,
              vertical: 32,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: 400,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      color: card,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: gold.withOpacity(0.18),
                          blurRadius: 16,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.sports_bar,
                      color: gold,
                      size: 34,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Bierkompas',
                    style: GoogleFonts.playfairDisplay(
                      color: cream,
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Welkom terug. Log in om verder te ontdekken.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      color: muted,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 28),
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
                          _buildEmailField(
                            field,
                            cream,
                            muted,
                          ),
                          const SizedBox(height: 14),
                          _buildPasswordField(
                            field,
                            cream,
                            muted,
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
                                      'Inloggen',
                                      style: GoogleFonts.inter(
                                        fontWeight: FontWeight.bold,
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
                  const SizedBox(height: 20),
                  TextButton(
                    onPressed: _isLoading || _socialLoading
                        ? null
                        : () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) =>
                                    const RegisterPage(),
                              ),
                            );
                          },
                    child: Text(
                      'Nog geen account? Registreren',
                      style: GoogleFonts.inter(
                        color: gold,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
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
            : _googleLogin,
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
                    'Doorgaan met Google',
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
            : _outlookLogin,
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
                    'Doorgaan met Outlook',
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
          padding: const EdgeInsets.symmetric(horizontal: 12),
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

  Widget _buildEmailField(
    Color field,
    Color cream,
    Color muted,
  ) {
    return TextFormField(
      controller: _emailController,
      keyboardType: TextInputType.emailAddress,
      textInputAction: TextInputAction.next,
      style: GoogleFonts.inter(
        color: cream,
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Vul je e-mailadres in.';
        }

        return null;
      },
      decoration: InputDecoration(
        labelText: 'E-mail',
        prefixIcon: Icon(
          Icons.mail_outline,
          color: muted,
          size: 20,
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

  Widget _buildPasswordField(
    Color field,
    Color cream,
    Color muted,
  ) {
    return TextFormField(
      controller: _passwordController,
      obscureText: _obscurePassword,
      textInputAction: TextInputAction.done,
      onFieldSubmitted: (_) => _submit(),
      style: GoogleFonts.inter(
        color: cream,
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Vul je wachtwoord in.';
        }

        return null;
      },
      decoration: InputDecoration(
        labelText: 'Wachtwoord',
        prefixIcon: Icon(
          Icons.lock_outline,
          color: muted,
          size: 20,
        ),
        suffixIcon: IconButton(
          icon: Icon(
            _obscurePassword
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
            color: muted,
            size: 20,
          ),
          onPressed: () {
            setState(() {
              _obscurePassword = !_obscurePassword;
            });
          },
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