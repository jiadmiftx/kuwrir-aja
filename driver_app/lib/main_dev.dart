// Dev-flavor entrypoint — run with `--flavor dev`. Delegates to main.dart's
// bootstrapApp() so dev and prod (lib/main.dart) never diverge in logic.
import 'main.dart' show bootstrapApp;

void main() => bootstrapApp();
