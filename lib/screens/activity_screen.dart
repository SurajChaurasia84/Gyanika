import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'profile_screen.dart';

class ActivityScreen extends StatelessWidget {
  const ActivityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    // final theme = Theme.of(context);

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text("User not logged in")),
      );
    }

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: const Text('My Activity'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collectionGroup('activities')
            .where('actorUid', isEqualTo: user.uid)
            .where('type', whereIn: const ['like', 'answer', 'vote', 'follow'])
            .orderBy('timestamp', descending: true)
            .limit(50)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text("No activity yet"),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            itemCount: snapshot.data!.docs.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final doc = snapshot.data!.docs[index];
              final data = doc.data() as Map<String, dynamic>;
              data['reference'] = doc.reference;

              return _ActivityTile(data: data);
            },
          );
        },
      ),
    );
  }
}

class _ActivityTile extends StatelessWidget {
  final Map<String, dynamic> data;
  const _ActivityTile({required this.data});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final type = (data['type'] ?? '').toString();
    final postId = (data['postId'] ?? '').toString();
    final postType = (data['postType'] ?? '').toString();
    final title = (data['title'] ?? '').toString();
    final preview = (data['content'] ?? data['postContent'] ?? '').toString();
    final time = data['timestamp'] as Timestamp?;
    final actorUid = (data['actorUid'] ?? '').toString();
    final targetUid = _targetUidFromActivity(data);

    final iconColor = _activityColor(type, theme);
    final iconData = _activityIcon(type);

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () {
        if (type == 'follow' && targetUid.isNotEmpty) {
          _pushSmooth(context, ProfileScreen(uid: targetUid));
          return;
        }
        final collection = _collectionFromPostType(postType);
        if (postId.isNotEmpty && collection.isNotEmpty) {
          _pushSmooth(
            context,
            PostDetailScreen(
              postId: postId,
              collection: collection,
              type: _titleFromPostType(postType),
            ),
          );
        }
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: theme.brightness == Brightness.dark
              ? Colors.white.withOpacity(0.05)
              : Colors.black.withOpacity(0.04),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: iconColor.withOpacity(0.15),
              child: Icon(iconData, color: iconColor),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ActivityLabel(
                    type: type,
                    postType: postType,
                    title: title,
                    actorUid: actorUid,
                    targetUid: targetUid,
                  ),
                  const SizedBox(height: 4),
                  _ActivityPreview(
                    preview: preview,
                    postId: postId,
                    postType: postType,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _formatTime(time),
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActivityLabel extends StatelessWidget {
  final String type;
  final String postType;
  final String title;
  final String actorUid;
  final String targetUid;

  const _ActivityLabel({
    required this.type,
    required this.postType,
    required this.title,
    required this.actorUid,
    required this.targetUid,
  });

  @override
  Widget build(BuildContext context) {
    final baseStyle = const TextStyle(fontSize: 15, fontWeight: FontWeight.w600);
    if (type != 'follow') {
      return Text(
        _activityLabel(type, postType, title),
        style: baseStyle,
      );
    }

    if (targetUid.isEmpty || targetUid == actorUid) {
      return Text('You started following a user', style: baseStyle);
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(targetUid).snapshots(),
      builder: (context, snap) {
        final data = snap.data?.data() as Map<String, dynamic>?;
        final name = (data?['name'] ?? data?['username'] ?? 'User').toString();
        return RichText(
          text: TextSpan(
            style: baseStyle.copyWith(color: Theme.of(context).colorScheme.onSurface),
            children: [
              const TextSpan(text: 'You started following '),
              TextSpan(
                text: name,
                style: baseStyle.copyWith(color: Theme.of(context).colorScheme.primary),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ActivityPreview extends StatelessWidget {
  final String preview;
  final String postId;
  final String postType;

  const _ActivityPreview({
    required this.preview,
    required this.postId,
    required this.postType,
  });

  @override
  Widget build(BuildContext context) {
    if (preview.isNotEmpty) {
      return Text(
        preview,
        maxLines: 2,
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
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        );
      },
    );
  }
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
      return Icons.bolt;
  }
}

Color _activityColor(String type, ThemeData theme) {
  switch (type) {
    case 'like':
      return Colors.redAccent;
    case 'answer':
      return Colors.indigo;
    case 'vote':
      return Colors.green;
    case 'follow':
      return Colors.deepPurple;
    default:
      return theme.colorScheme.primary;
  }
}

String _activityLabel(String type, String postType, String title) {
  final typeLabel = _titleFromPostType(postType);
  switch (type) {
    case 'like':
      return 'You liked a $typeLabel';
    case 'answer':
      return 'You answered a $typeLabel';
    case 'vote':
      return 'You voted on a $typeLabel';
    case 'follow':
      return 'You followed a user';
    default:
      return title.isNotEmpty ? title : 'Activity';
  }
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

String _targetUidFromActivity(Map<String, dynamic> data) {
  final explicit = (data['targetUid'] ?? '').toString();
  if (explicit.isNotEmpty) return explicit;
  final ref = data['reference'];
  if (ref is DocumentReference) {
    return ref.parent.parent?.id ?? '';
  }
  return '';
}

void _pushSmooth(BuildContext context, Widget page) {
  Navigator.push(
    context,
    PageRouteBuilder(
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (_, animation, _) => FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeInOut),
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0.03, 0),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut)),
          child: page,
        ),
      ),
    ),
  );
}
