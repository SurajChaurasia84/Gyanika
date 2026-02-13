import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import 'profile_screen.dart';
import 'my_profile_screen.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  static const int _pageSize = 20;
  final List<QueryDocumentSnapshot> _items = [];
  DocumentSnapshot? _lastDoc;
  bool _loading = false;
  bool _hasMore = true;
  bool _showToggleBanner = true;

  @override
  void initState() {
    super.initState();
    _loadInitial();
  }

  Future<void> _loadInitial() async {
    if (_loading) return;
    setState(() => _loading = true);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final snap = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('activities')
        .orderBy('timestamp', descending: true)
        .limit(_pageSize)
        .get();

    _items
      ..clear()
      ..addAll(snap.docs);
    _lastDoc = snap.docs.isNotEmpty ? snap.docs.last : null;
    _hasMore = snap.docs.length == _pageSize;
    await _markRead(snap.docs);
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadMore() async {
    if (_loading || !_hasMore) return;
    setState(() => _loading = true);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    if (_lastDoc == null) {
      _hasMore = false;
      setState(() => _loading = false);
      return;
    }

    final snap = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('activities')
        .orderBy('timestamp', descending: true)
        .startAfterDocument(_lastDoc!)
        .limit(_pageSize)
        .get();

    if (snap.docs.isEmpty) {
      _hasMore = false;
      setState(() => _loading = false);
      return;
    }

    _items.addAll(snap.docs);
    _lastDoc = snap.docs.last;
    _hasMore = snap.docs.length == _pageSize;
    await _markRead(snap.docs);
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _markRead(List<QueryDocumentSnapshot> docs) async {
    if (docs.isEmpty) return;
    final unread = docs.where((d) {
      final data = d.data() as Map<String, dynamic>;
      return data['read'] != true;
    }).toList();
    if (unread.isEmpty) return;
    final batch = FirebaseFirestore.instance.batch();
    for (final doc in unread) {
      batch.update(doc.reference, {'read': true});
    }
    await batch.commit();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(body: Center(child: Text('User not logged in')));
    }
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: const Text('Notifications'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () {
              Navigator.push(
                context,
                PageRouteBuilder(
                  transitionDuration: const Duration(milliseconds: 250),
                  pageBuilder: (_, animation, __) => FadeTransition(
                    opacity:
                        CurvedAnimation(parent: animation, curve: Curves.easeInOut),
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0.03, 0),
                        end: Offset.zero,
                      ).animate(
                        CurvedAnimation(parent: animation, curve: Curves.easeOut),
                      ),
                      child: const NotificationsScreen(),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          ValueListenableBuilder<Box>(
            valueListenable:
                Hive.box('settings').listenable(keys: ['in_app_notifications']),
            builder: (context, box, _) {
              final notifyEnabled =
                  box.get('in_app_notifications', defaultValue: true) as bool;
              if (notifyEnabled || !_showToggleBanner) {
                return const SizedBox.shrink();
              }
              return InkWell(
                borderRadius: BorderRadius.circular(10),
                splashColor: Colors.transparent,
                highlightColor: Colors.transparent,
                hoverColor: Colors.transparent,
                onTap: () {
                  Navigator.push(
                    context,
                    PageRouteBuilder(
                      transitionDuration: const Duration(milliseconds: 250),
                      pageBuilder: (_, animation, __) => FadeTransition(
                        opacity: CurvedAnimation(
                          parent: animation,
                          curve: Curves.easeInOut,
                        ),
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0.03, 0),
                            end: Offset.zero,
                          ).animate(
                            CurvedAnimation(
                              parent: animation,
                              curve: Curves.easeOut,
                            ),
                          ),
                          child: const NotificationsScreen(),
                        ),
                      ),
                    ),
                  );
                },
                child: Container(
                  margin: const EdgeInsets.fromLTRB(16, 6, 16, 0),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Theme.of(context)
                          .colorScheme
                          .outline
                          .withOpacity(0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Turn on notifications to receive updates',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () {
                          setState(() => _showToggleBanner = false);
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          Expanded(
            child: _items.isEmpty && _loading
                ? const _NotificationsSkeleton()
                : _items.isEmpty
                    ? const Center(child: Text('No notifications yet'))
                    : NotificationListener<ScrollNotification>(
                        onNotification: (notification) {
                          if (notification.metrics.pixels >=
                              notification.metrics.maxScrollExtent - 200) {
                            _loadMore();
                          }
                          return false;
                        },
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                          children: [
                            ..._buildGroupedList(_items),
                            if (_loading)
                              const Padding(
                                padding: EdgeInsets.only(top: 12),
                                child: _NotificationsLoadMoreSkeleton(),
                              ),
                          ],
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

class _NotificationsSkeleton extends StatelessWidget {
  const _NotificationsSkeleton();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final base = isDark
        ? const Color(0xFF2A3252)
        : const Color(0xFFE2E6EF);
    final highlight = isDark
        ? const Color(0xFF3A4470)
        : const Color(0xFFF4F6FB);

    Widget line(double width, {double height = 12}) {
      return Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: base,
          borderRadius: BorderRadius.circular(8),
        ),
      );
    }

    Widget item() {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: base,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  line(double.infinity, height: 13),
                  const SizedBox(height: 6),
                  line(170),
                ],
              ),
            ),
            const SizedBox(width: 10),
            line(56, height: 10),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return Shimmer.fromColors(
          baseColor: base,
          highlightColor: highlight,
          child: SingleChildScrollView(
            physics: const NeverScrollableScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                child: Column(
                  children: [
                    Row(
                      children: [
                        line(54, height: 11),
                      ],
                    ),
                    const SizedBox(height: 10),
                    item(),
                    item(),
                    item(),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        line(74, height: 11),
                      ],
                    ),
                    const SizedBox(height: 10),
                    item(),
                    item(),
                    item(),
                    item(),
                    item(),
                    item(),
                    item(),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _NotificationsLoadMoreSkeleton extends StatelessWidget {
  const _NotificationsLoadMoreSkeleton();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final base = isDark
        ? const Color(0xFF56608B)
        : const Color(0xFFB8C0D1);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (i) {
        return Container(
          width: 6,
          height: 6,
          margin: EdgeInsets.only(right: i == 2 ? 0 : 6),
          decoration: BoxDecoration(
            color: base,
            borderRadius: BorderRadius.circular(99),
          ),
        );
      }),
    );
  }
}

List<Widget> _buildGroupedList(List<QueryDocumentSnapshot> docs) {
  final grouped = _groupByTime(_dedupeLikeNotifications(docs));
  final widgets = <Widget>[];
  if (grouped.today.isNotEmpty) {
    widgets.add(_SectionLabel('Today'));
    widgets.addAll(grouped.today.map((d) => _NotificationTile(doc: d)));
  }
  if (grouped.tomorrow.isNotEmpty) {
    widgets.add(const SizedBox(height: 12));
    widgets.add(_SectionLabel('Tomorrow'));
    widgets.addAll(grouped.tomorrow.map((d) => _NotificationTile(doc: d)));
  }
  if (grouped.lastWeek.isNotEmpty) {
    widgets.add(const SizedBox(height: 12));
    widgets.add(_SectionLabel('Last week'));
    widgets.addAll(grouped.lastWeek.map((d) => _NotificationTile(doc: d)));
  }
  if (grouped.older.isNotEmpty) {
    widgets.add(const SizedBox(height: 12));
    widgets.add(_SectionLabel('Older'));
    widgets.addAll(grouped.older.map((d) => _NotificationTile(doc: d)));
  }
  return widgets;
}

List<QueryDocumentSnapshot> _dedupeLikeNotifications(
  List<QueryDocumentSnapshot> docs,
) {
  final out = <QueryDocumentSnapshot>[];
  final seenLikeKeys = <String>{};
  final seenFollowKeys = <String>{};

  for (final doc in docs) {
    final data = doc.data() as Map<String, dynamic>;
    final type = (data['type'] ?? '').toString();
    if (type == 'follow') {
      final actorUid = (data['actorUid'] ?? '').toString();
      if (actorUid.isEmpty) {
        out.add(doc);
        continue;
      }
      final key = 'follow|$actorUid';
      if (seenFollowKeys.add(key)) {
        out.add(doc);
      }
      continue;
    }

    if (type != 'like') {
      out.add(doc);
      continue;
    }

    final actorUid = (data['actorUid'] ?? '').toString();
    final postId = (data['postId'] ?? '').toString();
    final postType = (data['postType'] ?? '').toString();
    if (actorUid.isEmpty || postId.isEmpty || postType.isEmpty) {
      out.add(doc);
      continue;
    }

    final key = '$actorUid|$postType|$postId';
    if (seenLikeKeys.add(key)) {
      out.add(doc);
    }
  }

  return out;
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final QueryDocumentSnapshot doc;
  const _NotificationTile({required this.doc});

  @override
  Widget build(BuildContext context) {
    final data = doc.data() as Map<String, dynamic>;
    final title = (data['title'] ?? 'Notification').toString();
    final timestamp = data['timestamp'] as Timestamp?;
    final actorUid = (data['actorUid'] ?? '').toString();
    final postId = (data['postId'] ?? '').toString();
    final postType = (data['postType'] ?? '').toString();
    final preview = (data['content'] ?? data['postContent'] ?? '').toString();
    final type = (data['type'] ?? '').toString();

    return InkWell(
      onTap: () {
        if (postId.isNotEmpty) {
          final collection = _collectionFromPostType(postType);
          if (collection.isNotEmpty) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PostDetailScreen(
                  postId: postId,
                  collection: collection,
                  type: _titleFromPostType(postType),
                ),
              ),
            );
            return;
          }
        }
        if (actorUid.isNotEmpty) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => ProfileScreen(uid: actorUid)),
          );
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Icon(_activityIcon(type), size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, maxLines: 2, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  _NotificationPreview(
                    preview: preview,
                    postId: postId,
                    postType: postType,
                  ),
                ],
              ),
            ),
            Text(
              _formatTime(timestamp),
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}

class _GroupedNotifications {
  final List<QueryDocumentSnapshot> today;
  final List<QueryDocumentSnapshot> tomorrow;
  final List<QueryDocumentSnapshot> lastWeek;
  final List<QueryDocumentSnapshot> older;

  _GroupedNotifications({
    required this.today,
    required this.tomorrow,
    required this.lastWeek,
    required this.older,
  });
}

_GroupedNotifications _groupByTime(List<QueryDocumentSnapshot> docs) {
  final now = DateTime.now();
  final today = <QueryDocumentSnapshot>[];
  final tomorrow = <QueryDocumentSnapshot>[];
  final lastWeek = <QueryDocumentSnapshot>[];
  final older = <QueryDocumentSnapshot>[];

  for (final d in docs) {
    final data = d.data() as Map<String, dynamic>;
    final ts = data['timestamp'] as Timestamp?;
    final date = ts?.toDate();
    if (date == null) {
      older.add(d);
      continue;
    }

    final startToday = DateTime(now.year, now.month, now.day);
    final startTomorrow = startToday.add(const Duration(days: 1));
    final startDayAfter = startToday.add(const Duration(days: 2));

    if (date.isAfter(startToday) && date.isBefore(startTomorrow)) {
      today.add(d);
    } else if (date.isAfter(startTomorrow) && date.isBefore(startDayAfter)) {
      tomorrow.add(d);
    } else {
      final diff = now.difference(date).inDays;
      if (diff >= 0 && diff <= 7) {
        lastWeek.add(d);
      } else {
        older.add(d);
      }
    }
  }

  return _GroupedNotifications(
    today: today,
    tomorrow: tomorrow,
    lastWeek: lastWeek,
    older: older,
  );
}

String _formatTime(Timestamp? timestamp) {
  if (timestamp == null) return '';
  final date = timestamp.toDate();
  final now = DateTime.now();
  final diff = now.difference(date);
  if (diff.inMinutes < 1) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
  if (diff.inHours < 24) return '${diff.inHours} hours ago';
  return '${diff.inDays} days ago';
}

String _collectionFromPostType(String postType) {
  final type = postType.toLowerCase();
  if (type.contains('question')) return 'questions';
  if (type.contains('quiz')) return 'quizzes';
  if (type.contains('poll')) return 'polls';
  if (type == 'questions' || type == 'quizzes' || type == 'polls') {
    return type;
  }
  return '';
}

String _titleFromPostType(String postType) {
  final type = postType.toLowerCase();
  if (type.contains('question')) return 'Question';
  if (type.contains('quiz')) return 'Quiz';
  if (type.contains('poll')) return 'Poll';
  return 'Post';
}

IconData _activityIcon(String type) {
  switch (type) {
    case 'like':
      return Icons.favorite_outline;
    case 'answer':
      return Icons.question_answer_outlined;
    case 'vote':
      return Icons.how_to_vote_outlined;
    case 'follow':
      return Icons.person_add_alt_1_outlined;
    default:
      return Icons.notifications;
  }
}

class _NotificationPreview extends StatelessWidget {
  final String preview;
  final String postId;
  final String postType;

  const _NotificationPreview({
    required this.preview,
    required this.postId,
    required this.postType,
  });

  @override
  Widget build(BuildContext context) {
    if (preview.isNotEmpty) {
      return Text(
        preview,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 12, color: Colors.grey),
      );
    }

    final collection = _collectionFromPostType(postType);
    if (collection.isEmpty || postId.isEmpty) {
      return const SizedBox.shrink();
    }

    final ref =
        FirebaseFirestore.instance.collection(collection).doc(postId);
    return FutureBuilder<DocumentSnapshot>(
      future: ref.get(),
      builder: (context, snap) {
        final data = snap.data?.data() as Map<String, dynamic>?;
        final content = (data?['content'] ?? '').toString();
        if (content.isEmpty) return const SizedBox.shrink();
        return Text(
          content,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        );
      },
    );
  }
}
