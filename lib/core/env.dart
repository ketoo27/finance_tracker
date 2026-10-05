/// Supabase project configuration.
///
/// Fill these in from your Supabase project dashboard:
/// Project Settings -> API -> Project URL / anon public key.
///
/// Do NOT commit real secrets to a public repo. Inject these via
/// --dart-define at build time instead of hardcoding:
///
///   flutter build apk \
///     --dart-define=SUPABASE_URL=https://xxxx.supabase.co \
///     --dart-define=SUPABASE_ANON_KEY=xxxx
///
/// In CI (GitHub Actions), these come from repo Secrets — see
/// .github/workflows/build-apk.yml.
class Env {
  static const supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://YOUR-PROJECT-REF.supabase.co',
  );

  static const supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'YOUR-SUPABASE-ANON-KEY',
  );
}
