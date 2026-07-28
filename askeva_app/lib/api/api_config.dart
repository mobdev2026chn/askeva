/// Backend configuration for AskEva, switchable between environments.
///
/// "Same credentials" => the user signs in with their real AskEva
/// email/password against whichever environment is active below.
enum AppEnv { development, production }

class ApiConfig {
  ApiConfig._();

  /// The active environment. Production = the same backend my.askeva.io uses
  /// (apiv2.askeva.io); development = staging (api.askeva.net).
  ///
  /// Both hosts below mirror my.askeva.io's own build config exactly
  /// (askeva-react .env.production / .env.staging) and were verified live
  /// (200 OK on POST /v1/users/login). Default to production so the app talks
  /// to the same backend you sign in to on my.askeva.io.
  static const AppEnv env = AppEnv.production; // Production — same backend as my.askeva.io (apiv2.askeva.io)
  static bool get isDev => env == AppEnv.development;


  // ---------------- Per-environment hosts ----------------
  static const Map<AppEnv, _Env> _envs = {
    // Hosted staging/dev server (.env.staging in the web app).
    AppEnv.development: _Env(
      base: 'https://apiv2.askeva.io',
      socket: 'https://socket.askeva.io',
      webhook: 'https://webhook.askeva.io/v1',
    ), 
    // Production (.env.production in the web app).
    AppEnv.production: _Env(
      base: 'https://apiv2.askeva.io',
      socket: 'https://socket.askeva.io',
      webhook: 'https://webhook.askeva.io/v1',
    ),
  };
  

  static _Env get _active => _envs[env]!;

  static String get baseUrl => _active.base;
  static String get apiV1 => '${_active.base}/v1';
  static String get socketUrl => _active.socket;
  static String get webhookUrl => _active.webhook;

  /// Tenant domain expected by the login + OTP endpoints (same across envs).
  static const String domain = 'app.askeva.io';
}

class _Env {
  final String base;
  final String socket;
  final String webhook;
  const _Env({required this.base, required this.socket, required this.webhook});
}
