import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:memories_through_lenses/services/auth.dart';

/// Signature for the function that performs the actual password-reset request.
///
/// Returns `null` when the request was accepted, otherwise a user-facing error
/// message. This indirection lets the dialog be unit-tested without Firebase.
typedef PasswordResetSender = Future<String?> Function(String email);

/// Shows the "Reset Password" dialog.
///
/// [onSubmit] defaults to [Auth.forgotPassword]; tests inject a fake sender.
Future<void> showForgotPasswordDialog(
  BuildContext context, {
  PasswordResetSender? onSubmit,
}) {
  final sender = onSubmit ?? (String email) => Auth().forgotPassword(email);
  return showDialog<void>(
    context: context,
    builder: (_) => ForgotPasswordDialog(onSubmit: sender),
  );
}

/// A self-contained "Reset Password" dialog that can never leave the user on a
/// black or non-interactive screen.
///
/// While a request is in flight the dialog is locked down: the buttons are
/// disabled, the barrier/back gesture is blocked via [PopScope], and the dialog
/// route is popped **exactly once** (only on success). This makes it impossible
/// for a stray extra `Navigator.pop()` to remove the page underneath the
/// dialog, which was the cause of the black-screen bug.
class ForgotPasswordDialog extends StatefulWidget {
  const ForgotPasswordDialog({super.key, required this.onSubmit});

  final PasswordResetSender onSubmit;

  @override
  State<ForgotPasswordDialog> createState() => _ForgotPasswordDialogState();
}

class _ForgotPasswordDialogState extends State<ForgotPasswordDialog> {
  final TextEditingController _emailController = TextEditingController();
  bool _isSending = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  SnackBar _snack(String message, {bool isError = false}) {
    return SnackBar(
      content: Text(message, style: GoogleFonts.poppins()),
      backgroundColor: isError ? Colors.red : Colors.green,
    );
  }

  Future<void> _submit() async {
    // Guard against re-entrancy (defence in depth; the button is also disabled).
    if (_isSending) return;

    // Dismiss the keyboard before doing anything else.
    FocusScope.of(context).unfocus();

    // Capture context-dependent objects before the async gap so we never touch
    // a stale/disposed context after awaiting.
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    final email = _emailController.text.trim();
    if (email.isEmpty) {
      messenger.showSnackBar(
        _snack('Please enter your email address', isError: true),
      );
      return;
    }

    setState(() => _isSending = true);

    String? errorMessage;
    try {
      errorMessage = await widget.onSubmit(email);
    } catch (e) {
      // The sender is expected to translate errors into messages, but we never
      // let an unexpected throw leave the button stuck in the sending state.
      errorMessage = 'An unexpected error occurred. Please try again.';
    }

    // If the dialog was disposed while the request was running, do nothing:
    // no pop (which could over-pop the page underneath) and no snackbar on a
    // dead context.
    if (!mounted) return;

    if (errorMessage == null) {
      // Success: close the dialog exactly once, then confirm. The message does
      // not guarantee delivery and does not reveal whether the account exists.
      navigator.pop();
      messenger.showSnackBar(
        _snack(
          'If an account exists for that email, a password reset link has been '
          'requested. Please check your inbox and spam folders.',
        ),
      );
    } else {
      // Failure: keep the dialog open and restore the button so the user can
      // retry without re-entering their email.
      setState(() => _isSending = false);
      messenger.showSnackBar(_snack(errorMessage, isError: true));
    }
  }

  @override
  Widget build(BuildContext context) {
    // Block the barrier tap / system back gesture while a request is in flight
    // so the route cannot be popped out from under us mid-request.
    return PopScope(
      canPop: !_isSending,
      child: AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text(
          'Reset Password',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: 20,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Enter your email address and we\'ll send you a link to reset '
              'your password.',
              style: GoogleFonts.poppins(fontSize: 14),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _emailController,
              enabled: !_isSending,
              autofillHints: const [AutofillHints.email],
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                hintText: 'Email',
                hintStyle: GoogleFonts.poppins(),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.0),
                ),
                prefixIcon: const Icon(Icons.email, color: Colors.blue),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: _isSending ? null : () => Navigator.of(context).pop(),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(color: Colors.grey),
            ),
          ),
          ElevatedButton(
            onPressed: _isSending ? null : _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              disabledBackgroundColor: Colors.blue.shade200,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: _isSending
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.5,
                    ),
                  )
                : Text(
                    'Send Reset Link',
                    style: GoogleFonts.poppins(),
                  ),
          ),
        ],
      ),
    );
  }
}
