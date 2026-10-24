import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memories_through_lenses/services/comment_threads.dart';

Map<String, dynamic> c(String id, int minute,
        {String? parent, String uid = 'u1'}) =>
    {
      'id': id,
      'uid': uid,
      'description': id,
      'date': Timestamp.fromDate(DateTime(2026, 1, 1, 12, minute)),
      if (parent != null) 'parent_id': parent,
    };

void main() {
  test('legacy comments without parent_id are top-level, newest first', () {
    final threads = buildCommentThreads([c('a', 1), c('b', 3), c('c', 2)]);
    expect(threads.map((t) => t.comment['id']), ['b', 'c', 'a']);
    expect(threads.every((t) => t.replies.isEmpty), isTrue);
  });

  test('replies nest under their parent, oldest first', () {
    final threads = buildCommentThreads([
      c('root', 1),
      c('r2', 5, parent: 'root'),
      c('r1', 4, parent: 'root'),
    ]);
    expect(threads, hasLength(1));
    expect(threads.single.replies.map((r) => r['id']), ['r1', 'r2']);
  });

  test('a reply to a reply joins the top-level thread', () {
    final threads = buildCommentThreads([
      c('root', 1),
      c('r1', 2, parent: 'root'),
      c('rr', 3, parent: 'r1'),
    ]);
    expect(threads, hasLength(1));
    expect(threads.single.replies.map((r) => r['id']), ['r1', 'rr']);
  });

  test('orphaned and hidden-parent replies are promoted, not lost', () {
    final threads = buildCommentThreads(
      [c('gone-child', 1, parent: 'deleted'), c('p', 2), c('k', 3, parent: 'p')],
      hiddenCommentIds: {'p'},
    );
    expect(threads.map((t) => t.comment['id']).toSet(), {'gone-child', 'k'});
  });

  test('reported and blocked-user comments are hidden', () {
    final threads = buildCommentThreads(
      [c('mine', 1), c('reported', 2), c('blocked', 3, uid: 'bad')],
      hiddenCommentIds: {'reported'},
      blockedUserIds: {'bad'},
    );
    expect(threads.map((t) => t.comment['id']), ['mine']);
  });

  test('a parent cycle cannot hang or drop comments', () {
    final threads = buildCommentThreads(
        [c('a', 1, parent: 'b'), c('b', 2, parent: 'a')]);
    final all = [
      for (final t in threads) ...[t.comment['id'], ...t.replies.map((r) => r['id'])]
    ];
    expect(all.toSet(), {'a', 'b'});
  });
}
