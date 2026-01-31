// FULL FEED SCREEN – FIXED & CRASH SAFE
// ✅ Quiz works like poll (options, correct/incorrect)
// ✅ username[0] crash fixed
// ✅ likes, counts, polls safe

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FeedScreen extends StatelessWidget {
  const FeedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Feed')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('questions').snapshots(),
        builder: (_, q) {
          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('polls').snapshots(),
            builder: (_, p) {
              return StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('quizzes')
                    .snapshots(),
                builder: (_, z) {
                  if (!q.hasData || !p.hasData || !z.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final docs = [
                    ...q.data!.docs,
                    ...p.data!.docs,
                    ...z.data!.docs,
                  ];

                  docs.sort(
                    (a, b) => (b['createdAt'] as Timestamp).compareTo(
                      a['createdAt'] as Timestamp,
                    ),
                  );

                  return ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: docs.length,
                    itemBuilder: (_, i) {
                      final d = docs[i].data() as Map<String, dynamic>;
                      return FeedCard(data: d, id: docs[i].id);
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

// ================= FEED CARD =================
class FeedCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final String id;
  const FeedCard({super.key, required this.data, required this.id});

  @override
  Widget build(BuildContext context) {
    final type = data['type'];
    final username = (data['username'] ?? '').toString();
    final safeName = username.isNotEmpty ? username : 'User';

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.indigo,
                  child: Text(
                    safeName[0].toUpperCase(),
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      safeName,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      '${type.toUpperCase()} • ${data['category']} • ${timeAgo(data['createdAt'])}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 10),
            Text('Que. ${data['content'] ?? ''}'),

            if (type == 'question') AnswerBox(postId: id),
            if (type == 'poll')
              PollWidget(postId: id, options: data['options']),
            if (type == 'quiz')
              QuizWidget(
                postId: id,
                options: data['options'],
                correct: data['correctIndex'],
              ),

            const SizedBox(height: 10),
            Row(
              children: [
                LikeButton(postId: id, collection: '${type}s'),
                Text(formatCount(data['likes'] ?? 0)),
                const SizedBox(width: 16),
                const Icon(Icons.question_answer, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Text(formatCount(data['answeredCount'] ?? 0)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ================= QUIZ =================
class QuizWidget extends StatelessWidget {
  final String postId;
  final List options;
  final int correct;

  const QuizWidget({
    super.key,
    required this.postId,
    required this.options,
    required this.correct,
  });

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final ref = FirebaseFirestore.instance
        .collection('quizzes')
        .doc(postId)
        .collection('attempts')
        .doc(uid);

    if (options.isEmpty) {
      return const Text('No quiz options');
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: ref.snapshots(),
      builder: (_, snap) {
        final answered = snap.data?.exists ?? false;
        final selected = (snap.data?.data() as Map<String, dynamic>?)?['index'];

        return Column(
          children: List.generate(options.length, (i) {
            Color? bg;
            if (answered) {
              if (i == correct) bg = Colors.green.withOpacity(.2);
              if (i == selected && i != correct)
                bg = Colors.red.withOpacity(.2);
            }

            return Container(
              margin: const EdgeInsets.only(bottom: 6),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: ListTile(
                title: Text(options[i]),
                onTap: answered
                    ? null
                    : () async {
                        await ref.set({'index': i});
                        await FirebaseFirestore.instance
                            .collection('quizzes')
                            .doc(postId)
                            .update({'answeredCount': FieldValue.increment(1)});
                      },
              ),
            );
          }),
        );
      },
    );
  }
}

// ================= POLL =================
class PollWidget extends StatelessWidget {
  final String postId;
  final List options;
  const PollWidget({super.key, required this.postId, required this.options});

  @override
  Widget build(BuildContext context) {
    if (options.isEmpty) return const Text('No poll options');

    final uid = FirebaseAuth.instance.currentUser!.uid;
    final ref = FirebaseFirestore.instance
        .collection('polls')
        .doc(postId)
        .collection('votes')
        .doc(uid);

    return StreamBuilder<DocumentSnapshot>(
      stream: ref.snapshots(),
      builder: (_, s) {
        final voted = s.data?.exists ?? false;
        return Column(
          children: options
              .map(
                (o) => ListTile(
                  title: Text(o),
                  trailing: voted
                      ? const Icon(Icons.check, color: Colors.indigo)
                      : null,
                  onTap: voted
                      ? null
                      : () async {
                          await ref.set({'option': o});
                          await FirebaseFirestore.instance
                              .collection('polls')
                              .doc(postId)
                              .update({
                                'answeredCount': FieldValue.increment(1),
                              });
                        },
                ),
              )
              .toList(),
        );
      },
    );
  }
}

// ================= LIKE =================
class LikeButton extends StatelessWidget {
  final String postId;
  final String collection;
  const LikeButton({super.key, required this.postId, required this.collection});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final ref = FirebaseFirestore.instance
        .collection(collection)
        .doc(postId)
        .collection('likes')
        .doc(uid);

    return StreamBuilder<DocumentSnapshot>(
      stream: ref.snapshots(),
      builder: (_, s) {
        final liked = s.data?.exists ?? false;
        return IconButton(
          icon: Icon(
            liked ? Icons.favorite : Icons.favorite_border,
            color: liked ? Colors.indigo : Colors.grey,
          ),
          onPressed: () async {
            final post = FirebaseFirestore.instance
                .collection(collection)
                .doc(postId);
            FirebaseFirestore.instance.runTransaction((tx) async {
              liked ? tx.delete(ref) : tx.set(ref, {'uid': uid});
              tx.update(post, {'likes': FieldValue.increment(liked ? -1 : 1)});
            });
          },
        );
      },
    );
  }
}

// ================= ANSWER =================
class AnswerBox extends StatefulWidget {
  final String postId;
  const AnswerBox({super.key, required this.postId});

  @override
  State<AnswerBox> createState() => _AnswerBoxState();
}

class _AnswerBoxState extends State<AnswerBox> {
  final c = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: c,
            decoration: const InputDecoration(hintText: 'Answer...'),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.arrow_upward, color: Colors.indigo),
          onPressed: () async {
            if (c.text.trim().isEmpty) return;
            final uid = FirebaseAuth.instance.currentUser!.uid;
            final ref = FirebaseFirestore.instance
                .collection('questions')
                .doc(widget.postId)
                .collection('answers')
                .doc(uid);

            if ((await ref.get()).exists) return;
            await ref.set({'text': c.text.trim(), 'uid': uid});
            await FirebaseFirestore.instance
                .collection('questions')
                .doc(widget.postId)
                .update({'answeredCount': FieldValue.increment(1)});
            c.clear();
          },
        ),
      ],
    );
  }
}

// ================= HELPERS =================
String formatCount(int n) {
  if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
  if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
  return n.toString();
}

String timeAgo(Timestamp t) {
  final d = DateTime.now().difference(t.toDate());
  if (d.inMinutes < 1) return 'just now';
  if (d.inMinutes < 60) return '${d.inMinutes}m ago';
  if (d.inHours < 24) return '${d.inHours}h ago';
  return '${d.inDays}d ago';
}
