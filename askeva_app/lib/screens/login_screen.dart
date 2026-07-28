import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/app_scope.dart';
import '../api/global_notification_poller.dart';
import '../api/totp_helper.dart';
import '../shell/app_shell.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../widgets/dashboard_sheets.dart' show appToast;
import '../widgets/eva_brand.dart';

enum AuthView { signIn, resetPassword, signUp }

class LoginScreen extends StatefulWidget {
  final AuthView initialView;
  const LoginScreen({super.key, this.initialView = AuthView.signIn});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  late AuthView _currentView;

  // Sign in controllers
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _rememberMe = true;
  bool _obscure = true;
  bool _otpMode = false;
  bool _otpSent = false;
  final _otpControllers = List.generate(6, (_) => TextEditingController());
  final _otpNodes = List.generate(6, (_) => FocusNode());

  // Reset password controllers
  final _resetEmail = TextEditingController();
  int _resetStep = 0; // 0: enter email, 1: enter OTP & new password
  final _resetOtpControllers = List.generate(6, (_) => TextEditingController());
  final _resetOtpNodes = List.generate(6, (_) => FocusNode());
  final _newPassword = TextEditingController();
  bool _newPasswordObscure = true;

  // Sign up controllers
  final _companyName = TextEditingController();
  final _primaryContactName = TextEditingController();
  final _phone = TextEditingController();
  final _signupEmail = TextEditingController();
  final _signupPassword = TextEditingController();
  final _signupConfirmPassword = TextEditingController();
  bool _signupObscure = true;
  bool _signupConfirmObscure = true;
  final String _selectedCountryCode = '+91 India';

  bool _loading = false;
  String? _error;

  // 2FA Gate
  bool _show2faGate = false;
  bool _use2faBackup = false;
  String _twofaSecret = '';
  List<String> _twofaBackups = [];
  final _twofaCodeControllers = List.generate(6, (_) => TextEditingController());
  final _twofaCodeNodes = List.generate(6, (_) => FocusNode());
  final _twofaBackupController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _currentView = widget.initialView;
    _loadRememberedCredentials();
  }

  Future<void> _loadRememberedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    final remember = prefs.getBool('remember_me') ?? true;
    final savedEmail = prefs.getString('remember_email') ?? '';
    final savedPassword = prefs.getString('remember_password') ?? '';
    if (mounted) {
      setState(() {
        _rememberMe = remember;
        if (remember) {
          if (savedEmail.isNotEmpty) _email.text = savedEmail;
          if (savedPassword.isNotEmpty) _password.text = savedPassword;
        }
      });
    }
  }

  Future<void> _saveRememberedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('remember_me', _rememberMe);
    if (_rememberMe) {
      if (_email.text.trim().isNotEmpty) {
        await prefs.setString('remember_email', _email.text.trim());
      }
      if (_password.text.isNotEmpty) {
        await prefs.setString('remember_password', _password.text);
      }
    } else {
      await prefs.remove('remember_email');
      await prefs.remove('remember_password');
    }
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _resetEmail.dispose();
    _newPassword.dispose();
    _companyName.dispose();
    _primaryContactName.dispose();
    _phone.dispose();
    _signupEmail.dispose();
    _signupPassword.dispose();
    _signupConfirmPassword.dispose();
    for (final c in _otpControllers) {
      c.dispose();
    }
    for (final n in _otpNodes) {
      n.dispose();
    }
    for (final c in _resetOtpControllers) {
      c.dispose();
    }
    for (final n in _resetOtpNodes) {
      n.dispose();
    }
    for (final c in _twofaCodeControllers) {
      c.dispose();
    }
    for (final n in _twofaCodeNodes) {
      n.dispose();
    }
    _twofaBackupController.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await action();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _enterApp() {
    GlobalNotificationPoller.start(AppScope.of(context));
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const AppShell()));
  }

  Future<void> _check2faOrEnter(String email) async {
    final prefs = await SharedPreferences.getInstance();
    final has2fa = prefs.getBool('twofa_enabled_$email') ?? false;
    if (has2fa) {
      final secret = prefs.getString('twofa_secret_$email') ?? '';
      final backups = prefs.getStringList('twofa_backups_$email') ?? [];
      setState(() {
        _twofaSecret = secret;
        _twofaBackups = backups;
        _show2faGate = true;
        _use2faBackup = false;
        _error = null;
        for (final c in _twofaCodeControllers) {
          c.clear();
        }
        _twofaBackupController.clear();
      });
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted && _twofaCodeNodes[0].canRequestFocus) {
          _twofaCodeNodes[0].requestFocus();
        }
      });
    } else {
      _enterApp();
    }
  }

  Future<void> _passwordSignIn() async {
    final email = _email.text.trim();
    if (!RegExp(r'\S+@\S+\.\S+').hasMatch(email)) {
      setState(() => _error = 'Enter a valid email address');
      return;
    }
    if (_password.text.trim().length < 4) {
      setState(() => _error = 'Password must be at least 4 characters');
      return;
    }
    await _run(() async {
      final scope = AppScope.of(context);
      await scope.session.clear();
      await scope.auth.login(email, _password.text);
      await _saveRememberedCredentials();
      if (mounted) await _check2faOrEnter(email);
    });
  }

  Future<void> _sendOtp() async {
    final email = _email.text.trim();
    if (!RegExp(r'\S+@\S+\.\S+').hasMatch(email)) {
      setState(() => _error = 'Enter a valid email address');
      return;
    }
    await _run(() async {
      final auth = AppScope.of(context).auth;
      final mobile = await auth.lookupMobile(email);
      await auth.sendOtp(mobile);
      if (mounted) setState(() => _otpSent = true);
    });
  }

  Future<void> _verifyOtp() async {
    final code = _otpControllers.map((c) => c.text).join();
    if (code.length < 6) {
      setState(() => _error = 'Enter all 6 digits');
      return;
    }
    await _run(() async {
      final scope = AppScope.of(context);
      await scope.session.clear();
      await scope.auth.verifyOtp(_email.text.trim(), code);
      await _saveRememberedCredentials();
      if (mounted) await _check2faOrEnter(_email.text.trim());
    });
  }

  Future<void> _handleResetPassword() async {
    if (_resetStep == 0) {
      final email = _resetEmail.text.trim();
      if (!RegExp(r'\S+@\S+\.\S+').hasMatch(email)) {
        setState(() => _error = 'Enter a valid email address');
        return;
      }
      await _run(() async {
        final auth = AppScope.of(context).auth;
        try {
          final mobile = await auth.lookupMobile(email);
          await auth.sendOtp(mobile);
          if (mounted) {
            setState(() {
              _resetStep = 1;
              _error = null;
            });
            appToast(context, 'Reset OTP sent to your registered mobile', isSuccess: true);
          }
        } catch (e) {
          if (mounted) {
            setState(() {
              _error = 'Incorrect registered mail id';
            });
          }
        }
      });
    } else {
      final code = _resetOtpControllers.map((c) => c.text).join();
      if (code.length < 6) {
        setState(() => _error = 'Enter the 6-digit OTP');
        return;
      }
      if (_newPassword.text.length < 6) {
        setState(() => _error = 'Password must be at least 6 characters');
        return;
      }
      await _run(() async {
        final auth = AppScope.of(context).auth;
        await auth.verifyOtp(_resetEmail.text.trim(), code);
        if (mounted) {
          setState(() {
            _currentView = AuthView.signIn;
            _resetStep = 0;
            _error = null;
          });
          appToast(context, 'Password reset successfully! Please log in.', isSuccess: true);
        }
      });
    }
  }

  Future<void> _handleSignUp() async {
    if (_companyName.text.trim().isEmpty) {
      setState(() => _error = 'Please enter company name');
      return;
    }
    if (_primaryContactName.text.trim().isEmpty) {
      setState(() => _error = 'Please enter primary contact name');
      return;
    }
    if (_phone.text.trim().isEmpty) {
      setState(() => _error = 'Please enter WhatsApp number');
      return;
    }
    final email = _signupEmail.text.trim();
    if (!RegExp(r'\S+@\S+\.\S+').hasMatch(email)) {
      setState(() => _error = 'Please enter a valid email address');
      return;
    }
    if (_signupPassword.text.length < 6) {
      setState(() => _error = 'Password must be at least 6 characters');
      return;
    }
    if (_signupPassword.text != _signupConfirmPassword.text) {
      setState(() => _error = 'Passwords do not match');
      return;
    }
    await _run(() async {
      if (mounted) {
        appToast(context, 'Account created successfully! Please log in.', isSuccess: true);
        setState(() {
          _email.text = email;
          _currentView = AuthView.signIn;
          _error = null;
        });
      }
    });
  }

  Future<void> _verify2faCode() async {
    final code = _twofaCodeControllers.map((c) => c.text).join();
    if (code.length < 6) {
      setState(() => _error = 'Enter all 6 digits');
      return;
    }
    
    final isValid = TotpHelper.verifyTotpCode(_twofaSecret, code);
    if (isValid) {
      _enterApp();
    } else {
      setState(() {
        _error = 'Incorrect code. Open your authenticator app and enter the current 6-digit code.';
      });
      for (final c in _twofaCodeControllers) {
        c.clear();
      }
      _twofaCodeNodes[0].requestFocus();
    }
  }

  Future<void> _verify2faBackup() async {
    final code = _twofaBackupController.text.trim();
    if (code.isEmpty) {
      setState(() => _error = 'Enter a backup code');
      return;
    }
    
    final list = List<String>.from(_twofaBackups);
    final isValid = TotpHelper.verifyBackupCode(list, code);
    if (isValid) {
      final email = _email.text.trim();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('twofa_backups_$email', list);
      
      if (mounted) {
        appToast(context, 'Signed in with a backup code', isSuccess: true);
        _enterApp();
      }
    } else {
      setState(() {
        _error = 'Invalid or already-used backup code.';
      });
    }
  }

  void _switchView(AuthView newView) {
    setState(() {
      _currentView = newView;
      _error = null;
      _resetStep = 0;
      _resetEmail.clear();
      for (var c in _resetOtpControllers) {
        c.clear();
      }
      _newPassword.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFF38C82D),
                Color(0xFF7DD52B),
              ],
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Top Header (Ask Eva logo + Welcome)
                        _buildTopHeader(),
                        // Bottom White Card Container
                        _buildCardContainer(),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Center(
            child: EvaLogo(height: 110, onGreen: true),
          ),
          const SizedBox(height: 14),
          Text(
            'Welcome',
            textAlign: TextAlign.center,
            style: AppText.poppins(
              size: 22,
              weight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: 0.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardContainer() {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      padding: const EdgeInsets.fromLTRB(26, 28, 26, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_show2faGate)
            ..._build2faContent()
          else switch (_currentView) {
            AuthView.signIn => _buildSignInContent(),
            AuthView.resetPassword => _buildResetPasswordContent(),
            AuthView.signUp => _buildSignUpContent(),
          },

          if (_error != null) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                const Icon(Icons.error_outline_rounded, size: 17, color: AppColors.danger),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _error!,
                    style: AppText.poppins(size: 13, weight: FontWeight.w600, color: AppColors.danger),
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: 24),
          _buildFooterLinkAndBranding(),
          SizedBox(height: MediaQuery.of(context).viewInsets.bottom + MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }

  // Section Header (Title + Accent Line)
  Widget _buildTitleHeader(String title, double barWidth) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: AppText.poppins(size: 27, weight: FontWeight.w800, color: AppColors.ink),
        ),
        const SizedBox(height: 6),
        Container(
          width: barWidth,
          height: 3.5,
          decoration: BoxDecoration(
            color: const Color(0xFF38C82D),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ],
    );
  }

  // --- SIGN IN VIEW ---
  Widget _buildSignInContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTitleHeader('Sign in', 40),
        const SizedBox(height: 22),
        if (!_otpMode) ...[
          _buildLabel('Email'),
          const SizedBox(height: 6),
          _buildIconUnderlineField(
            controller: _email,
            hint: 'Enter your email address',
            icon: Icons.mail_outline_rounded,
            keyboard: TextInputType.emailAddress,
          ),
          const SizedBox(height: 20),
          _buildLabel('Password'),
          const SizedBox(height: 6),
          _buildIconUnderlineField(
            controller: _password,
            hint: 'Enter your password',
            icon: Icons.lock_outline_rounded,
            obscure: _obscure,
            suffix: GestureDetector(
              onTap: () => setState(() => _obscure = !_obscure),
              child: Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Icon(
                  _obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  size: 20,
                  color: AppColors.ink3,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              GestureDetector(
                onTap: () {
                  setState(() => _rememberMe = !_rememberMe);
                  _saveRememberedCredentials();
                },
                child: Row(
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: Checkbox(
                        value: _rememberMe,
                        onChanged: (v) {
                          setState(() => _rememberMe = v ?? true);
                          _saveRememberedCredentials();
                        },
                        activeColor: const Color(0xFF38C82D),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                        side: const BorderSide(color: AppColors.line, width: 1.5),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text('Remember Me', style: AppText.poppins(size: 13, weight: FontWeight.w700, color: AppColors.ink)),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => _switchView(AuthView.resetPassword),
                child: Text(
                  'Forgot Password?',
                  style: AppText.poppins(size: 13, weight: FontWeight.w800, color: const Color(0xFF1E9C3B)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 26),
          _buildGreenButton('Login', _passwordSignIn, isLoading: _loading),
          const SizedBox(height: 12),
          _buildGreenButton('Login with OTP', () {
            setState(() {
              _otpMode = true;
              _otpSent = false;
              _error = null;
            });
          }),
        ] else ...[
          if (!_otpSent) ...[
            _buildLabel('Registered Email'),
            const SizedBox(height: 6),
            _buildIconUnderlineField(
              controller: _email,
              hint: 'Enter registered email address',
              icon: Icons.mail_outline_rounded,
              keyboard: TextInputType.emailAddress,
              onSubmit: (_) => _sendOtp(),
            ),
            const SizedBox(height: 24),
            _buildGreenButton('Send OTP', _sendOtp, isLoading: _loading),
            const SizedBox(height: 12),
            Center(
              child: TextButton(
                onPressed: () => setState(() => _otpMode = false),
                child: Text('Use password instead', style: AppText.poppins(size: 13.5, weight: FontWeight.w700, color: const Color(0xFF1E9C3B))),
              ),
            ),
          ] else ...[
            Text('Enter 6-digit code', style: AppText.poppins(size: 14, weight: FontWeight.w700, color: AppColors.ink)),
            const SizedBox(height: 4),
            Text('Sent to the mobile number linked to ${_email.text.trim()}',
                style: AppText.poppins(size: 12.5, weight: FontWeight.w500, color: AppColors.ink3)),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(6, (i) {
                return SizedBox(
                  width: 44,
                  height: 52,
                  child: TextField(
                    controller: _otpControllers[i],
                    focusNode: _otpNodes[i],
                    textAlign: TextAlign.center,
                    keyboardType: TextInputType.number,
                    maxLength: 1,
                    style: AppText.poppins(size: 20, weight: FontWeight.w800, color: AppColors.ink),
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      counterText: '',
                      filled: true,
                      fillColor: AppColors.surface2,
                      contentPadding: EdgeInsets.zero,
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.line)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF38C82D), width: 1.6)),
                    ),
                    onChanged: (v) {
                      if (v.isNotEmpty && i < 5) _otpNodes[i + 1].requestFocus();
                      if (v.isEmpty && i > 0) _otpNodes[i - 1].requestFocus();
                    },
                  ),
                );
              }),
            ),
            const SizedBox(height: 24),
            _buildGreenButton('Verify & continue', _verifyOtp, isLoading: _loading),
            const SizedBox(height: 12),
            Center(
              child: TextButton(
                onPressed: () => setState(() => _otpSent = false),
                child: Text('Resend OTP / Change Email', style: AppText.poppins(size: 13, weight: FontWeight.w700, color: AppColors.ink3)),
              ),
            ),
          ],
        ],
      ],
    );
  }

  // --- RESET PASSWORD VIEW ---
  Widget _buildResetPasswordContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTitleHeader('Reset password', 46),
        const SizedBox(height: 14),
        Text(
          'Enter your registered email — we\'ll send an OTP to the mobile number linked to it.',
          style: AppText.poppins(size: 13.5, weight: FontWeight.w500, color: AppColors.ink3, height: 1.45),
        ),
        const SizedBox(height: 22),
        if (_resetStep == 0) ...[
          _buildLabel('Email'),
          const SizedBox(height: 6),
          _buildIconUnderlineField(
            controller: _resetEmail,
            hint: 'Enter your email address',
            icon: Icons.mail_outline_rounded,
            keyboard: TextInputType.emailAddress,
            onSubmit: (_) => _handleResetPassword(),
          ),
          const SizedBox(height: 28),
          _buildGreenButton('Send', _handleResetPassword, isLoading: _loading),
        ] else ...[
          _buildLabel('6-digit OTP Code'),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(6, (i) {
              return SizedBox(
                width: 44,
                height: 52,
                child: TextField(
                  controller: _resetOtpControllers[i],
                  focusNode: _resetOtpNodes[i],
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.number,
                  maxLength: 1,
                  style: AppText.poppins(size: 20, weight: FontWeight.w800, color: AppColors.ink),
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    counterText: '',
                    filled: true,
                    fillColor: AppColors.surface2,
                    contentPadding: EdgeInsets.zero,
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.line)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF38C82D), width: 1.6)),
                  ),
                  onChanged: (v) {
                    if (v.isNotEmpty && i < 5) _resetOtpNodes[i + 1].requestFocus();
                    if (v.isEmpty && i > 0) _resetOtpNodes[i - 1].requestFocus();
                  },
                ),
              );
            }),
          ),
          const SizedBox(height: 20),
          _buildLabel('New Password'),
          const SizedBox(height: 6),
          _buildIconUnderlineField(
            controller: _newPassword,
            hint: 'Enter your new password',
            icon: Icons.lock_outline_rounded,
            obscure: _newPasswordObscure,
            suffix: GestureDetector(
              onTap: () => setState(() => _newPasswordObscure = !_newPasswordObscure),
              child: Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Icon(
                  _newPasswordObscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  size: 20,
                  color: AppColors.ink3,
                ),
              ),
            ),
          ),
          const SizedBox(height: 28),
          _buildGreenButton('Reset Password', _handleResetPassword, isLoading: _loading),
          const SizedBox(height: 12),
          Center(
            child: TextButton(
              onPressed: () => setState(() {
                _resetStep = 0;
                _error = null;
              }),
              child: Text(
                'Resend OTP / Change Email',
                style: AppText.poppins(size: 13, weight: FontWeight.w700, color: AppColors.ink3),
              ),
            ),
          ),
        ],
      ],
    );
  }

  // --- SIGN UP VIEW ---
  Widget _buildSignUpContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTitleHeader('Welcome', 42),
        const SizedBox(height: 20),

        _buildLabel('Company Name'),
        const SizedBox(height: 6),
        _buildStandardUnderlineField(
          controller: _companyName,
          hint: 'Enter company name',
        ),
        const SizedBox(height: 18),

        _buildLabel('Primary Contact Name'),
        const SizedBox(height: 6),
        _buildStandardUnderlineField(
          controller: _primaryContactName,
          hint: 'Enter primary contact name',
        ),
        const SizedBox(height: 18),

        _buildLabel('Phone Number'),
        const SizedBox(height: 6),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.line, width: 1.4),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _selectedCountryCode,
                    style: AppText.poppins(size: 13.5, weight: FontWeight.w700, color: AppColors.ink),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: AppColors.ink3),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                cursorColor: const Color(0xFF38C82D),
                style: AppText.poppins(size: 14.5, weight: FontWeight.w600, color: AppColors.ink),
                decoration: InputDecoration(
                  hintText: 'Enter WhatsApp number',
                  hintStyle: AppText.poppins(size: 14.5, weight: FontWeight.w500, color: AppColors.ink4),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                  enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppColors.line, width: 1.4)),
                  focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF38C82D), width: 1.8)),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),

        _buildLabel('Email'),
        const SizedBox(height: 6),
        _buildIconUnderlineField(
          controller: _signupEmail,
          hint: 'Enter email address',
          icon: Icons.mail_outline_rounded,
          keyboard: TextInputType.emailAddress,
        ),
        const SizedBox(height: 18),

        _buildLabel('Password'),
        const SizedBox(height: 6),
        _buildIconUnderlineField(
          controller: _signupPassword,
          hint: 'Create a password',
          icon: Icons.lock_outline_rounded,
          obscure: _signupObscure,
          suffix: GestureDetector(
            onTap: () => setState(() => _signupObscure = !_signupObscure),
            child: Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Icon(
                _signupObscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                size: 20,
                color: AppColors.ink3,
              ),
            ),
          ),
        ),
        const SizedBox(height: 18),

        _buildLabel('Confirm Password'),
        const SizedBox(height: 6),
        _buildIconUnderlineField(
          controller: _signupConfirmPassword,
          hint: 'Confirm your password',
          icon: Icons.lock_outline_rounded,
          obscure: _signupConfirmObscure,
          suffix: GestureDetector(
            onTap: () => setState(() => _signupConfirmObscure = !_signupConfirmObscure),
            child: Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Icon(
                _signupConfirmObscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                size: 20,
                color: AppColors.ink3,
              ),
            ),
          ),
        ),
        const SizedBox(height: 26),

        _buildGreenButton('Sign up', _handleSignUp, isLoading: _loading),
      ],
    );
  }

  // --- 2FA GATE CONTENT ---
  List<Widget> _build2faContent() {
    return [
      _buildTitleHeader("Verify it's you", 50),
      const SizedBox(height: 14),
      Text(
        _use2faBackup
            ? "Two-factor authentication is enabled. Enter one of your 12-character backup codes."
            : "Two-factor authentication is enabled. Enter the 6-digit code shown in your authenticator app for ${_email.text.trim()}.",
        style: AppText.poppins(size: 13.5, weight: FontWeight.w500, color: AppColors.ink3, height: 1.45),
      ),
      const SizedBox(height: 22),
      if (!_use2faBackup) ...[
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(6, (i) {
            return SizedBox(
              width: 44,
              height: 52,
              child: TextField(
                controller: _twofaCodeControllers[i],
                focusNode: _twofaCodeNodes[i],
                textAlign: TextAlign.center,
                keyboardType: TextInputType.number,
                maxLength: 1,
                style: AppText.poppins(size: 20, weight: FontWeight.w800, color: AppColors.ink),
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  counterText: '',
                  filled: true,
                  fillColor: AppColors.surface2,
                  contentPadding: EdgeInsets.zero,
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.line)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF38C82D), width: 1.6)),
                ),
                onChanged: (v) {
                  if (v.isNotEmpty) {
                    if (i < 5) {
                      _twofaCodeNodes[i + 1].requestFocus();
                    } else {
                      _verify2faCode();
                    }
                  }
                  if (v.isEmpty && i > 0) {
                    _twofaCodeNodes[i - 1].requestFocus();
                  }
                },
              ),
            );
          }),
        ),
      ] else ...[
        _buildStandardUnderlineField(
          controller: _twofaBackupController,
          hint: 'e.g. CA9A-FB74-96BD',
          onSubmit: (_) => _verify2faBackup(),
        ),
      ],
      const SizedBox(height: 26),
      _buildGreenButton('Verify & continue', _use2faBackup ? _verify2faBackup : _verify2faCode, isLoading: _loading),
      const SizedBox(height: 12),
      Center(
        child: TextButton(
          onPressed: _loading
              ? null
              : () => setState(() {
                    _use2faBackup = !_use2faBackup;
                    _error = null;
                    _twofaBackupController.clear();
                    for (var c in _twofaCodeControllers) {
                      c.clear();
                    }
                  }),
          child: Text(
            _use2faBackup ? 'Use authenticator app code' : 'Use backup code instead',
            style: AppText.poppins(size: 13.5, weight: FontWeight.w700, color: const Color(0xFF1E9C3B)),
          ),
        ),
      ),
      Center(
        child: TextButton(
          onPressed: _loading
              ? null
              : () async {
                  setState(() {
                    _show2faGate = false;
                    _error = null;
                  });
                  await AppScope.of(context).session.clear();
                },
          child: Text(
            'Back to sign in',
            style: AppText.poppins(size: 13, weight: FontWeight.w600, color: AppColors.ink3),
          ),
        ),
      ),
    ];
  }

  // --- FOOTER LINK & BRANDING ---
  Widget _buildFooterLinkAndBranding() {
    Widget navigationLink = const SizedBox.shrink();
    if (_show2faGate) {
      navigationLink = const SizedBox.shrink();
    } else {
      switch (_currentView) {
        case AuthView.resetPassword:
          navigationLink = GestureDetector(
            onTap: () => _switchView(AuthView.signIn),
            child: RichText(
              text: TextSpan(
                text: "Remembered it? ",
                style: AppText.poppins(size: 13, weight: FontWeight.w600, color: AppColors.ink3),
                children: [
                  TextSpan(
                    text: 'Back to login',
                    style: AppText.poppins(size: 13, weight: FontWeight.w800, color: const Color(0xFF1E9C3B)),
                  ),
                ],
              ),
            ),
          );
          break;
        default:
          break;
      }
    }

    return Column(
      children: [
        Center(child: navigationLink),
        const SizedBox(height: 16),
        Center(
          child: Text(
            'powered by askeva',
            style: AppText.poppins(size: 11, weight: FontWeight.w700, color: AppColors.ink4, letterSpacing: 0.3),
          ),
        ),
      ],
    );
  }

  // --- REUSABLE FIELD BUILDERS ---
  Widget _buildLabel(String text) {
    return Text(
      text,
      style: AppText.poppins(size: 13.5, weight: FontWeight.w700, color: AppColors.ink),
    );
  }

  Widget _buildIconUnderlineField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool obscure = false,
    Widget? suffix,
    TextInputType? keyboard,
    ValueChanged<String>? onSubmit,
  }) {
    return Container(
      padding: const EdgeInsets.only(bottom: 2),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.line, width: 1.4)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.ink3),
          const SizedBox(width: 10),
          Container(width: 1, height: 16, color: AppColors.line),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              obscureText: obscure,
              keyboardType: keyboard,
              onSubmitted: onSubmit,
              cursorColor: const Color(0xFF38C82D),
              style: AppText.poppins(size: 14.5, weight: FontWeight.w600, color: AppColors.ink),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: AppText.poppins(size: 14.5, weight: FontWeight.w500, color: AppColors.ink4),
                isDense: true,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 6),
              ),
            ),
          ),
          ?suffix,
        ],
      ),
    );
  }

  Widget _buildStandardUnderlineField({
    required TextEditingController controller,
    required String hint,
    TextInputType? keyboard,
    ValueChanged<String>? onSubmit,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboard,
      onSubmitted: onSubmit,
      cursorColor: const Color(0xFF38C82D),
      style: AppText.poppins(size: 14.5, weight: FontWeight.w600, color: AppColors.ink),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: AppText.poppins(size: 14.5, weight: FontWeight.w500, color: AppColors.ink4),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 8),
        enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppColors.line, width: 1.4)),
        focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF38C82D), width: 1.8)),
      ),
    );
  }

  Widget _buildGreenButton(String label, VoidCallback? onTap, {bool isLoading = false}) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: isLoading ? null : onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF38C82D),
          disabledBackgroundColor: const Color(0xFF38C82D).withValues(alpha: 0.5),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: isLoading
            ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
            : Text(label, style: AppText.poppins(size: 15.5, weight: FontWeight.w800, color: Colors.white)),
      ),
    );
  }
}

/// Helper for launching auth modal sheet or view externally.
Future<void> showAuthSheet(BuildContext context, {required bool signup}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => Container(
      height: MediaQuery.of(context).size.height * 0.9,
      clipBehavior: Clip.antiAlias,
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: LoginScreen(initialView: signup ? AuthView.signUp : AuthView.resetPassword),
    ),
  );
}
