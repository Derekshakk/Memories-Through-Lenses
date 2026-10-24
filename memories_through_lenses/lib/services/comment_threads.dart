import 'package:cloud_firestore/cloud_firestore.dart';

/// A top-level comment and its replies.
class CommentThread {
  CommentThread(this.comment, this.replies);
  final Map<String, dynamic> comment;
  final List<Map<String, dynamic>> replies;
}

DateTime commentDate(Object? raw) {
  if (raw is Timestamp) return raw.toDate();
  if (raw is DateTime) return raw;
  // A comment written moments ago may not have a server value yet.
  return DateTime.now();
}

/// Groups flat comment documents (each with an `id`) into one level of
/// threads.
///
/// Backward compatible: comments written before replies existed have no
/// `parent_id` and are top-level. A reply whose parent is gone or hidden is
/// promoted to top level rather than silently dropped. Top-level comments are
/// newest first; replies read oldest first, like a conversation.
List<CommentThread> buildCommentThreads(
  List<Map<String, dynamic>> comments, {
  Set<String> hiddenCommentIds = const {},
  Set<String> blockedUserIds = const {},
}) {
  final visible = comments.where((c) {
    final id = c['id'];
    return id is String &&
        !hiddenCommentIds.contains(id) &&
        !blockedUserIds.contains(c['uid']);
  }).toList();
  final byId = {for (final c in visible) c['id'] as String: c};

  // The app always points replies at the top-level comment, but resolve
  // chains defensively so a reply-to-a-reply can never be lost.
  String rootOf(Map<String, dynamic> c) {
    var current = c;
    final seen = <String>{};
    while (true) {
      final parent = current['parent_id'];
      if (parent is! String ||
          !byId.containsKey(parent) ||
          !seen.add(parent)) {
        return current['id'] as String;
      }
      current = byId[parent]!;
    }
  }

  final top = <Map<String, dynamic>>[];
  final replies = <String, List<Map<String, dynamic>>>{};
  for (final c in visible) {
    final root = rootOf(c);
    if (root == c['id']) {
      top.add(c);
    } else {
      replies.putIfAbsent(root, () => []).add(c);
    }
  }

  int byDate(Map<String, dynamic> a, Map<String, dynamic> b) =>
      commentDate(a['date']).compareTo(commentDate(b['date']));
  top.sort((a, b) => byDate(b, a));
  for (final list in replies.values) {
    list.sort(byDate);
  }
  return [
    for (final c in top) CommentThread(c, replies[c['id']] ?? const []),
  ];
}
