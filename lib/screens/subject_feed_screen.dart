import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SubjectFeedScreen extends StatelessWidget {
  final String subjectName;
  final String stream;

  const SubjectFeedScreen({
    super.key,
    required this.subjectName,
    required this.stream,
  });

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(subjectName),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Questions'),
              Tab(text: 'Quiz & Polls'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            FeedList(subject: subjectName, stream: stream, type: 'question'),
            FeedList(subject: subjectName, stream: stream, type: 'quiz_poll'),
          ],
        ),
        bottomNavigationBar:
            BottomActionBar(subject: subjectName, stream: stream),
      ),
    );
  }
}

/// ==================================================
/// FEED LIST (REALTIME STREAM)
/// ==================================================

class FeedList extends StatelessWidget {
  final String subject;
  final String stream;
  final String type;

  const FeedList({
    super.key,
    required this.subject,
    required this.stream,
    required this.type,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('posts')
          .where('subject', isEqualTo: subject)
          .where('stream', isEqualTo: stream)
          .where('type', isEqualTo: type)
          .orderBy('createdAt', descending: false) // newest at bottom
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('No posts yet'));
        }

        final docs = snapshot.data!.docs;

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
          itemCount: docs.length,
          itemBuilder: (_, i) => PostCard(post: docs[i]),
        );
      },
    );
  }
}

/// ==================================================
/// POST CARD UI
/// ==================================================

class PostCard extends StatelessWidget {
  final QueryDocumentSnapshot post;

  const PostCard({super.key, required this.post});

  @override
  Widget build(BuildContext context) {
    final Timestamp ts = post['createdAt'];

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  post['username'],
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                Text(
                  timeAgo(ts),
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(post['content'], style: const TextStyle(fontSize: 14)),
            const SizedBox(height: 12),
            Row(
              children: [
                _ActionIcon(
                    icon: Icons.thumb_up_alt_outlined,
                    count: post['likeCount']),
                _ActionIcon(
                    icon: Icons.comment_outlined,
                    count: post['commentCount']),
                IconButton(
                  icon: const Icon(Icons.share),
                  onPressed: () {},
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionIcon extends StatelessWidget {
  final IconData icon;
  final int count;

  const _ActionIcon({required this.icon, required this.count});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(icon: Icon(icon, size: 20), onPressed: () {}),
        Text(count.toString()),
        const SizedBox(width: 6),
      ],
    );
  }
}

/// ==================================================
/// BOTTOM ACTION BAR
/// ==================================================

class BottomActionBar extends StatelessWidget {
  final String subject;
  final String stream;

  const BottomActionBar({
    super.key,
    required this.subject,
    required this.stream,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          border: Border(top: BorderSide(color: Colors.grey.shade300)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _BottomBtn(
              label: 'Q&A',
              icon: Icons.question_answer,
              onTap: () => openCreatePost(context, subject, stream, 'question'),
            ),
            _BottomBtn(
              label: 'Quiz',
              icon: Icons.quiz,
              onTap: () => openCreatePost(context, subject, stream, 'quiz'),
            ),
            _BottomBtn(
              label: 'Poll',
              icon: Icons.poll,
              onTap: () => openCreatePost(context, subject, stream, 'poll'),
            ),
          ],
        ),
      ),
    );
  }
}

class _BottomBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _BottomBtn({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 22),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

/// ==================================================
/// CREATE POST BOTTOM SHEET
/// ==================================================

void openCreatePost(
    BuildContext context, String subject, String stream, String type) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => CreatePostSheet(
      subject: subject,
      stream: stream,
      type: type,
    ),
  );
}

class CreatePostSheet extends StatefulWidget {
  final String subject;
  final String stream;
  final String type;

  const CreatePostSheet({
    super.key,
    required this.subject,
    required this.stream,
    required this.type,
  });

  @override
  State<CreatePostSheet> createState() => _CreatePostSheetState();
}

class _CreatePostSheetState extends State<CreatePostSheet> {
  final ctrl = TextEditingController();
  bool isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Add ${widget.type.toUpperCase()}',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: ctrl,
            maxLines: 4,
            decoration: const InputDecoration(hintText: 'Write here...'),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: isLoading ? null : submitPost,
            child: isLoading
                ? const CircularProgressIndicator()
                : const Text('Post'),
          ),
        ],
      ),
    );
  }

  Future<void> submitPost() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || ctrl.text.trim().isEmpty) return;

    setState(() => isLoading = true);

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    await FirebaseFirestore.instance.collection('posts').add({
      'subject': widget.subject,
      'stream': widget.stream,
      'type': widget.type == 'quiz' || widget.type == 'poll'
          ? 'quiz_poll'
          : 'question',
      'uid': user.uid,
      'username': userDoc.data()?['username'] ?? 'Anonymous',
      'content': ctrl.text.trim(),
      'likeCount': 0,
      'commentCount': 0,
      'createdAt': Timestamp.now(), // IMPORTANT FIX
    });

    if (mounted) Navigator.of(context).pop();
  }
}

/// ==================================================
/// TIME AGO HELPER
/// ==================================================

String timeAgo(Timestamp ts) {
  final diff = DateTime.now().difference(ts.toDate());

  if (diff.inMinutes < 1) return 'just now';
  if (diff.inHours < 1) return '${diff.inMinutes}m ago';
  if (diff.inDays < 1) return '${diff.inHours}h ago';
  return '${diff.inDays}d ago';
}
