import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:memories_through_lenses/services/username.dart';
import 'package:memories_through_lenses/theme/app_colors.dart';

/// Bottom comment composer.
///
/// Multiline: Return inserts a line break (it used to submit), and a separate
/// Submit button posts. When replying, a preview of the comment being replied
/// to sits directly above the field, so it stays visible above the keyboard.
class CommentInputBar extends StatelessWidget {
  const CommentInputBar({
    super.key,
    required this.controller,
    required this.onSubmit,
    this.focusNode,
    this.submitting = false,
    this.replyingToName,
    this.replyingToText,
    this.onCancelReply,
  });

  static const int maxLength = 1000;

  final TextEditingController controller;
  final FocusNode? focusNode;
  final VoidCallback onSubmit;
  final bool submitting;
  final String? replyingToName;
  final String? replyingToText;
  final VoidCallback? onCancelReply;

  @override
  Widget build(BuildContext context) {
    final replying = replyingToName != null;
    return Material(
      color: AppColors.surface(context),
      elevation: 8,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (replying)
                Container(
                  key: const Key('reply-preview'),
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.fromLTRB(12, 6, 4, 6),
                  decoration: BoxDecoration(
                    color: AppColors.subtle(context),
                    borderRadius: BorderRadius.circular(12),
                    border: const Border(
                        left: BorderSide(color: Colors.blue, width: 3)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Replying to ${Username.displayName(replyingToName)}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.poppins(
                                  fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                            if (replyingToText != null &&
                                replyingToText!.isNotEmpty)
                              Text(
                                replyingToText!,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    color: AppColors.muted(
                                        context, Colors.grey[700]!)),
                              ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Cancel reply',
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: submitting ? null : onCancelReply,
                      ),
                    ],
                  ),
                ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: controller,
                      focusNode: focusNode,
                      enabled: !submitting,
                      style: GoogleFonts.poppins(fontSize: 14),
                      keyboardType: TextInputType.multiline,
                      textInputAction: TextInputAction.newline,
                      textCapitalization: TextCapitalization.sentences,
                      minLines: 1,
                      maxLines: 5,
                      inputFormatters: [
                        LengthLimitingTextInputFormatter(maxLength),
                      ],
                      decoration: InputDecoration(
                        hintText:
                            replying ? 'Write a reply...' : 'Add a comment...',
                        hintStyle: GoogleFonts.poppins(
                          color: Colors.grey[400],
                          fontSize: 14,
                        ),
                        filled: true,
                        fillColor: AppColors.subtle(context),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20.0),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16.0,
                          vertical: 10.0,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ValueListenableBuilder<TextEditingValue>(
                    valueListenable: controller,
                    builder: (context, value, _) {
                      final canSubmit =
                          !submitting && value.text.trim().isNotEmpty;
                      return FilledButton.icon(
                        key: const Key('comment-submit'),
                        onPressed: canSubmit ? onSubmit : null,
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.blue,
                          minimumSize: const Size(48, 44),
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                        ),
                        icon: submitting
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.send, size: 18),
                        label: const Text('Submit'),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
