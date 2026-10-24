import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:memories_through_lenses/services/database.dart';

/// Reasons offered for both post and comment reports. Stored verbatim in the
/// report document's `reason` field so reviewers see the same wording.
const List<String> kReportReasons = [
  'Spam or misleading',
  'Harassment or bullying',
  'Hate speech or symbols',
  'Nudity or sexual content',
  'Violence or dangerous acts',
  'Inappropriate for school',
  'Other',
];

enum ReportOutcome { reported, blocked }

/// One reason-selection dialog used for posts and comments.
///
/// Reporting and blocking are deliberately separate actions: blocking never
/// files a report (it used to report the post as a side effect).
class ReportDialog extends StatefulWidget {
  const ReportDialog({
    super.key,
    required this.title,
    required this.subject,
    required this.onSubmit,
    this.onBlock,
    this.timeout = const Duration(seconds: 20),
  });

  /// e.g. "Report Post".
  final String title;

  /// "post" or "comment", used in the copy.
  final String subject;
  final Future<void> Function(String reason, String details) onSubmit;

  /// When set, a "Block user" action is offered. It only blocks.
  final Future<void> Function()? onBlock;
  final Duration timeout;

  @override
  State<ReportDialog> createState() => _ReportDialogState();
}

class _ReportDialogState extends State<ReportDialog> {
  final TextEditingController _details = TextEditingController();
  String? _reason;
  bool _busy = false;
  bool _confirmingBlock = false;
  String? _error;

  @override
  void dispose() {
    _details.dispose();
    super.dispose();
  }

  Future<void> _run(
      Future<void> Function() action, ReportOutcome outcome) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action().timeout(widget.timeout);
      if (mounted) Navigator.of(context).pop(outcome);
    } catch (e) {
      debugPrint('Report/block failed: $e');
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e is TimeoutException
            ? 'This is taking too long. Check your connection and try again.'
            : outcome == ReportOutcome.blocked
                ? 'Could not block this user. Please try again.'
                : 'Could not submit your report. Please try again.';
      });
    }
  }

  void _submit() {
    final reason = _reason;
    if (reason == null) {
      setState(() => _error = 'Please choose a reason.');
      return;
    }
    _run(() => widget.onSubmit(reason, _details.text.trim()),
        ReportOutcome.reported);
  }

  Widget _errorText() => Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text(
          _error!,
          style: GoogleFonts.poppins(
              color: Theme.of(context).colorScheme.error, fontSize: 13),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(20));

    if (_confirmingBlock) {
      return PopScope(
        canPop: !_busy,
        child: AlertDialog(
          shape: shape,
          title: Text('Block user?',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "You won't see this person's posts anymore. "
                "Blocking does not report the ${widget.subject}.",
                style: GoogleFonts.poppins(),
              ),
              if (_error != null) _errorText(),
            ],
          ),
          actions: [
            TextButton(
              onPressed: _busy
                  ? null
                  : () => setState(() {
                        _confirmingBlock = false;
                        _error = null;
                      }),
              child: const Text('Back'),
            ),
            ElevatedButton(
              onPressed: _busy
                  ? null
                  : () => _run(widget.onBlock!, ReportOutcome.blocked),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
              child: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Block'),
            ),
          ],
        ),
      );
    }

    return PopScope(
      canPop: !_busy,
      child: AlertDialog(
        shape: shape,
        title: Text(widget.title,
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Why are you reporting this ${widget.subject}?',
                  style: GoogleFonts.poppins(),
                ),
                const SizedBox(height: 4),
                RadioGroup<String>(
                  groupValue: _reason,
                  onChanged: (value) {
                    if (_busy) return;
                    setState(() {
                      _reason = value;
                      _error = null;
                    });
                  },
                  child: Column(
                    children: [
                      for (final reason in kReportReasons)
                        RadioListTile<String>(
                          value: reason,
                          enabled: !_busy,
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text(reason, style: GoogleFonts.poppins()),
                        ),
                    ],
                  ),
                ),
                TextField(
                  controller: _details,
                  enabled: !_busy,
                  maxLength: 300,
                  minLines: 1,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    hintText: 'Additional details (optional)',
                  ),
                ),
                if (_error != null) _errorText(),
              ],
            ),
          ),
        ),
        actionsOverflowButtonSpacing: 4,
        actions: [
          if (widget.onBlock != null)
            TextButton(
              onPressed: _busy
                  ? null
                  : () => setState(() {
                        _confirmingBlock = true;
                        _error = null;
                      }),
              child: const Text('Block user',
                  style: TextStyle(color: Colors.orange)),
            ),
          TextButton(
            onPressed: _busy ? null : () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: _busy ? null : _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Text('Report'),
          ),
        ],
      ),
    );
  }
}

void _confirm(ScaffoldMessengerState messenger, String message) {
  messenger.showSnackBar(
    SnackBar(
      content: Text(message, style: GoogleFonts.poppins()),
      backgroundColor: Colors.green,
    ),
  );
}

/// Report a post (or block its author). Shows the confirmation snackbar and
/// returns what happened (null when cancelled).
Future<ReportOutcome?> showReportPostDialog(
  BuildContext context, {
  required String postId,
  required String postCreator,
  Database? database,
}) async {
  final db = database ?? Database();
  final messenger = ScaffoldMessenger.of(context);
  final outcome = await showDialog<ReportOutcome>(
    context: context,
    builder: (_) => ReportDialog(
      title: 'Report Post',
      subject: 'post',
      onSubmit: (reason, details) => db.reportPost(postId, postCreator,
          reason: reason, details: details),
      onBlock: () => db.blockUser(postCreator),
    ),
  );
  switch (outcome) {
    case ReportOutcome.reported:
      _confirm(messenger,
          'Report submitted. A group admin will review this post.');
    case ReportOutcome.blocked:
      _confirm(messenger, "User blocked. You won't see their posts.");
    case null:
      break;
  }
  return outcome;
}

/// Report a comment. Shows the confirmation snackbar and returns what
/// happened (null when cancelled).
Future<ReportOutcome?> showReportCommentDialog(
  BuildContext context, {
  required String postId,
  required String commentId,
  required String commentText,
  required String commentAuthor,
  Database? database,
}) async {
  final db = database ?? Database();
  final messenger = ScaffoldMessenger.of(context);
  final outcome = await showDialog<ReportOutcome>(
    context: context,
    builder: (_) => ReportDialog(
      title: 'Report Comment',
      subject: 'comment',
      onSubmit: (reason, details) => db.reportComment(postId, commentId,
          reason: reason,
          details: details,
          commentText: commentText,
          commentAuthor: commentAuthor),
    ),
  );
  if (outcome == ReportOutcome.reported) {
    _confirm(messenger,
        'Report submitted. A group admin will review this comment.');
  }
  return outcome;
}
