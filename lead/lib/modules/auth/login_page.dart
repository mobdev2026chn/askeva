import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../services/fcm_service.dart';
import '../../theme/app_colors.dart';
import '../dashboard/dashboard_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _loading = false;
  bool _obscure = true;
  bool _rememberMe = false;
  bool _fieldsUnlocked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _fieldsUnlocked = true);
    });
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final resp = await AuthService.login(
        _emailCtrl.text.trim(),
        _passwordCtrl.text,
      );
      if (!mounted) return;
      final token = resp['token'] as String?;
      final user = resp['user'] as Map<String, dynamic>?;

      if (token != null) {
        await AuthService.saveToken(token);
        final roomId = resp['roomId'] as String?;
        if (roomId != null) {
          await AuthService.saveRoomId(roomId);
        }
        final username = user?['username'] as String? ?? user?['name'] as String?;
        final email = user?['email'] as String?;
        final role = user?['role'] as String? ?? 'agent';
        if (username != null && email != null) {
          await AuthService.saveUserData(username, email, role);
        }
        await FCMService.updateToken();
      }
      if (!mounted) return;
      final name = user?['name'] as String? ?? user?['email'] as String? ?? 'User';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Welcome back, $name!')),
      );
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => DashboardPage(email: user?['email'], name: name),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      var msg = e.toString();
      if (msg.startsWith('Exception:')) {
        msg = msg.replaceFirst('Exception:', '').trim();
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isPortrait = MediaQuery.of(context).orientation == Orientation.portrait;

    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      body: SafeArea(
        child: isPortrait ? _buildPortrait(context, cs) : _buildLandscape(context, cs),
      ),
    );
  }

  Widget _buildPortrait(BuildContext context, ColorScheme cs) {
    return SingleChildScrollView(
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: AppColors.signatureGradient,
                stops: const [0.0, 0.5, 1.0],
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'ASK',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                ),
                Text(
                  'EVA',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Welcome',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Colors.white70,
                        fontSize: 16,
                      ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Form(
                key: _formKey,
                child: AutofillGroup(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Sign in',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              color: AppColors.lightOnSurface,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 24),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Email',
                            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.lightOnSurface,
                                ),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _emailCtrl,
                            readOnly: !_fieldsUnlocked,
                            keyboardType: TextInputType.emailAddress,
                            autofillHints: const [AutofillHints.email],
                            decoration: InputDecoration(
                              hintText: 'eshan@tunepath.com',
                              prefixIcon: Icon(Icons.email, color: AppColors.primary.withOpacity(0.6)),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: Colors.grey.shade300),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: AppColors.primary, width: 2),
                              ),
                            ),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) return 'Enter email';
                              if (!v.contains('@')) return 'Enter valid email';
                              return null;
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Password',
                            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.lightOnSurface,
                                ),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _passwordCtrl,
                            readOnly: !_fieldsUnlocked,
                            autofillHints: const [AutofillHints.password],
                            enableSuggestions: false,
                            autocorrect: false,
                            decoration: InputDecoration(
                              hintText: '••••••••',
                              prefixIcon: Icon(Icons.lock, color: AppColors.primary.withOpacity(0.6)),
                              suffixIcon: IconButton(
                                icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off, color: AppColors.primary),
                                onPressed: () => setState(() => _obscure = !_obscure),
                              ),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: Colors.grey.shade300),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: AppColors.primary, width: 2),
                              ),
                            ),
                            obscureText: _obscure,
                            validator: (v) {
                              if (v == null || v.isEmpty) return 'Enter password';
                              if (v.length < 6) return 'Password too short';
                              return null;
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(children: [
                            SizedBox(width: 24, height: 24,
                              child: Checkbox(value: _rememberMe, onChanged: (value) => setState(() => _rememberMe = value ?? false), activeColor: AppColors.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4))),
                            ),
                            const SizedBox(width: 8),
                            Text('Remember Me', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.lightOnSurface, fontWeight: FontWeight.w500)),
                          ]),
                          TextButton(onPressed: () {}, style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 0)), child: Text('Forgot Password?', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.primary, fontWeight: FontWeight.w600))),
                        ],
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(onPressed: _loading ? null : _submit, style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, disabledBackgroundColor: AppColors.primary.withOpacity(0.6), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0),
                          child: _loading ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2.5, valueColor: AlwaysStoppedAnimation<Color>(Colors.white))) : Text('Login', style: Theme.of(context).textTheme.labelLarge?.copyWith(color: Colors.white)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: OutlinedButton(onPressed: _showLoginWithOtpDialog, style: OutlinedButton.styleFrom(foregroundColor: AppColors.primary, side: const BorderSide(color: AppColors.primary, width: 1.5), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                          child: Text('Login with OTP', style: Theme.of(context).textTheme.labelLarge?.copyWith(color: AppColors.primary)),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Center(child: RichText(text: TextSpan(text: "Don't have an Account? ", style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.lightOnSurface), children: [TextSpan(text: 'Sign up', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold))]))),
                      const SizedBox(height: 24),
                      Center(child: Text('Powered by askeva', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey, letterSpacing: 0.5))),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLandscape(BuildContext context, ColorScheme cs) {
    return Row(
      children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: AppColors.signatureGradient,
                stops: const [0.0, 0.5, 1.0],
              ),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('ASK EVA', style: Theme.of(context).textTheme.displaySmall?.copyWith(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 2)),
                  const SizedBox(height: 16),
                  Text('Welcome Back', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white70)),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Form(
                key: _formKey,
                child: AutofillGroup(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Sign in', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 24),
                      TextFormField(controller: _emailCtrl, readOnly: !_fieldsUnlocked, keyboardType: TextInputType.emailAddress, autofillHints: const [AutofillHints.email], decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.email)), validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Enter email';
                        if (!v.contains('@')) return 'Enter valid email';
                        return null;
                      }),
                      const SizedBox(height: 16),
                      TextFormField(controller: _passwordCtrl, readOnly: !_fieldsUnlocked, autofillHints: const [AutofillHints.password], enableSuggestions: false, autocorrect: false, decoration: InputDecoration(labelText: 'Password', prefixIcon: const Icon(Icons.lock), suffixIcon: IconButton(icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off, color: AppColors.primary), onPressed: () => setState(() => _obscure = !_obscure))), obscureText: _obscure, validator: (v) {
                        if (v == null || v.isEmpty) return 'Enter password';
                        if (v.length < 6) return 'Password too short';
                        return null;
                      }),
                      const SizedBox(height: 12),
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        Row(children: [Checkbox(value: _rememberMe, onChanged: (value) => setState(() => _rememberMe = value ?? false)), Text('Remember Me', style: Theme.of(context).textTheme.bodySmall)]),
                        TextButton(onPressed: () {}, child: Text('Forgot Password?', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold))),
                      ]),
                      const SizedBox(height: 24),
                      SizedBox(width: double.infinity, child: ElevatedButton(onPressed: _loading ? null : _submit, child: _loading ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Login'))),
                      const SizedBox(height: 12),
                      SizedBox(width: double.infinity, child: OutlinedButton(onPressed: _showLoginWithOtpDialog, child: const Text('Login with OTP'))),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showLoginWithOtpDialog() {
    showDialog(
      context: context,
      builder: (ctx) {
        return _OtpLoginDialog(parentContext: context);
      },
    );
  }
}

class _OtpLoginDialog extends StatefulWidget {
  final BuildContext parentContext;
  const _OtpLoginDialog({required this.parentContext});

  @override
  State<_OtpLoginDialog> createState() => _OtpLoginDialogState();
}

class _OtpLoginDialogState extends State<_OtpLoginDialog> {
  String email = '';
  String otp = '';
  bool otpSent = false;
  bool loading = false;
  final formKey = GlobalKey<FormState>();

  Future<void> _sendOtp() async {
    if (formKey.currentState!.validate()) {
      setState(() => loading = true);
      try {
        // TODO: Implement OTP sending via AuthService
        setState(() => otpSent = true);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error sending OTP: $e')),
          );
        }
      } finally {
        if (mounted) setState(() => loading = false);
      }
    }
  }

  Future<void> _verifyOtp() async {
    if (formKey.currentState!.validate()) {
      setState(() => loading = true);
      try {
        // TODO: Implement OTP verification via AuthService
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(widget.parentContext).showSnackBar(
            const SnackBar(content: Text('OTP verified successfully')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error verifying OTP: $e')),
          );
        }
      } finally {
        if (mounted) setState(() => loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(otpSent ? 'Enter OTP' : 'Login with OTP'),
      content: SizedBox(
        width: 400,
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!otpSent)
                TextFormField(
                  decoration: const InputDecoration(labelText: 'Enter Email'),
                  keyboardType: TextInputType.emailAddress,
                  onChanged: (v) => email = v,
                  validator: (v) => v != null && v.contains('@') ? null : 'Invalid email',
                ),
              if (otpSent) ...[
                const Text('OTP sent to your email'),
                const SizedBox(height: 12),
                TextFormField(
                  decoration: const InputDecoration(labelText: 'OTP'),
                  keyboardType: TextInputType.number,
                  onChanged: (v) => otp = v,
                  validator: (v) => v != null && v.isNotEmpty ? null : 'Enter OTP',
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: loading ? null : (otpSent ? _verifyOtp : _sendOtp),
          child: Text(otpSent ? 'Verify' : 'Send OTP'),
        ),
      ],
    );
  }
}
