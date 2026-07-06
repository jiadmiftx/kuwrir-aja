import 'package:flutter/material.dart';
import 'package:kuwrir_shared/kuwrir_shared.dart';

/// Guard for actions that require a logged-in session (orders, chat,
/// checkout, profile). Guests get to browse everything else freely; this is
/// only called at the specific point a login-required action is attempted.
/// Returns true if already authenticated. Otherwise routes to the login
/// screen (clearing the stack, mirroring the existing logout flow) and
/// returns false so the caller can bail out of the action.
Future<bool> ensureLoggedIn(BuildContext context) async {
  final isLoggedIn = await ApiClient().isAuthenticated();
  if (isLoggedIn) return true;
  if (context.mounted) {
    Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
  }
  return false;
}
