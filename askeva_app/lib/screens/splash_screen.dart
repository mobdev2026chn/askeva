import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../api/app_scope.dart';
import '../shell/app_shell.dart';
import '../widgets/eva_brand.dart';
import 'login_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<double> _float;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2000))..repeat(reverse: true);
    _float = Tween<double>(begin: -6, end: 6).animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut));
    Future.delayed(const Duration(milliseconds: 2600), () {
      if (!mounted) return;
      final authed = AppScope.sessionOf(context).isAuthenticated;
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 500),
          pageBuilder: (_, a, _) => FadeTransition(
            opacity: a,
            child: authed ? const AppShell() : const LoginScreen(),
          ),
        ),
      );
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            color: Color(0xFF3DC838),
          ),
          child: Stack(
            children: [
              Align(
                alignment: const Alignment(0, -0.62),
                child: EvaLogo(height: 120, onGreen: true),
              ),

              // Center Mascot in Glowing White Circle Badge
              Align(
                alignment: const Alignment(0, 0.05),
                child: AnimatedBuilder(
                  animation: _float,
                  builder: (context, child) => Transform.translate(
                    offset: Offset(0, _float.value),
                    child: child,
                  ),
                  child: Container(
                    width: 215,
                    height: 215,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.white.withValues(alpha: 0.25),
                          spreadRadius: 12,
                          blurRadius: 0,
                        ),
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.10),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: EvaMascot(size: 150),
                      ),
                    ),
                  ),
                ),
              ),

              // Bottom 3 Loading Dots
              Align(
                alignment: const Alignment(0, 0.82),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _dot(),
                    const SizedBox(width: 10),
                    _dot(),
                    const SizedBox(width: 10),
                    _dot(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dot() {
    return Container(
      width: 8,
      height: 8,
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
      ),
    );
  }
}

