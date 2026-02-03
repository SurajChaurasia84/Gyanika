import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LibrarySection extends StatelessWidget {
  const LibrarySection({super.key});

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
    final collection = type == 'quiz' ? 'quizzes' : '${type}s';
    final username = (data['username'] ?? '').toString();
    final safeName = username.isNotEmpty ? username : 'User';

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ================= UPDATED HEADER ROW =================
            Row(
              children: [
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => UserProfileScreen(uid: data['uid']),
                      ),
                    );
                  },
                  child: CircleAvatar(
                    backgroundColor: Colors.indigo,
                    child: Text(
                      safeName[0].toUpperCase(),
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ),

                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        safeName,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        '${type.toUpperCase()} • ${data['category']} • ${timeAgo(data['createdAt'])}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                FollowButton(targetUid: data['uid']),
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
                LikeButton(postId: id, collection: collection),
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
            await ref.set({
              'text': c.text.trim(),
              'uid': uid,
              'createdAt': FieldValue.serverTimestamp(),
            });
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

// ================= FOLLOW BUTTON WIDGET =================
class FollowButton extends StatelessWidget {
  final String targetUid;
  const FollowButton({super.key, required this.targetUid});

  @override
  Widget build(BuildContext context) {
    final myUid = FirebaseAuth.instance.currentUser!.uid;
    if (myUid == targetUid) return const SizedBox();

    final ref = FirebaseFirestore.instance
        .collection('users')
        .doc(targetUid)
        .collection('followers')
        .doc(myUid);

    return StreamBuilder<DocumentSnapshot>(
      stream: ref.snapshots(),
      builder: (_, snap) {
        final isFollowing = snap.data?.exists ?? false;
        return InkWell(
          onTap: () async {
            final batch = FirebaseFirestore.instance.batch();
            final myRef = FirebaseFirestore.instance
                .collection('users')
                .doc(myUid)
                .collection('following')
                .doc(targetUid);

            if (isFollowing) {
              batch.delete(ref);
              batch.delete(myRef);
              batch.set(
                FirebaseFirestore.instance.collection('users').doc(targetUid),
                {'followers': FieldValue.increment(-1)},
                SetOptions(merge: true),
              );
              batch.set(
                FirebaseFirestore.instance.collection('users').doc(myUid),
                {'following': FieldValue.increment(-1)},
                SetOptions(merge: true),
              );
            } else {
              batch.set(ref, {'time': Timestamp.now()});
              batch.set(myRef, {'time': Timestamp.now()});
              batch.set(
                FirebaseFirestore.instance.collection('users').doc(targetUid),
                {'followers': FieldValue.increment(1)},
                SetOptions(merge: true),
              );
              batch.set(
                FirebaseFirestore.instance.collection('users').doc(myUid),
                {'following': FieldValue.increment(1)},
                SetOptions(merge: true),
              );
            }
            await batch.commit();
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isFollowing ? Colors.grey.shade200 : Colors.indigo,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              isFollowing ? 'Following' : 'Follow',
              style: TextStyle(
                fontSize: 12,
                color: isFollowing ? Colors.black : Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        );
      },
    );
  }
}

// ================= USER PROFILE SCREEN =================
class UserProfileScreen extends StatelessWidget {
  final String uid;
  const UserProfileScreen({super.key, required this.uid});

  @override
  Widget build(BuildContext context) {
    final userRef = FirebaseFirestore.instance.collection('users').doc(uid);

    return Scaffold(
      appBar: AppBar(),
      body: StreamBuilder<DocumentSnapshot>(
        stream: userRef.snapshots(),
        builder: (_, snap) {
          if (!snap.hasData)
            return const Center(child: CircularProgressIndicator());
          final user = snap.data!.data() as Map<String, dynamic>;
          final username = user['username'] ?? 'User';

          return Column(
            children: [
              const SizedBox(height: 20),
              CircleAvatar(
                radius: 40,
                backgroundColor: Colors.indigo,
                child: Text(
                  username[0].toUpperCase(),
                  style: const TextStyle(fontSize: 28, color: Colors.white),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                username,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _Count(uid: uid, label: 'Posts'),
                  _Count(uid: uid, label: 'Followers'),
                  _Count(uid: uid, label: 'Following'),
                ],
              ),
              const Divider(height: 30),
              Expanded(child: _UserPosts(uid: uid)),
            ],
          );
        },
      ),
    );
  }
}

class _Count extends StatelessWidget {
  final String uid;
  final String label;
  const _Count({required this.uid, required this.label});

  @override
  Widget build(BuildContext context) {
    final ref = label == 'Followers'
        ? FirebaseFirestore.instance
              .collection('users')
              .doc(uid)
              .collection('followers')
        : label == 'Following'
        ? FirebaseFirestore.instance
              .collection('users')
              .doc(uid)
              .collection('following')
        : FirebaseFirestore.instance
              .collection('questions')
              .where('uid', isEqualTo: uid);

    return StreamBuilder<QuerySnapshot>(
      stream: ref.snapshots(),
      builder: (_, snap) {
        final count = snap.data?.docs.length ?? 0;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              Text(
                count.toString(),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(label, style: const TextStyle(color: Colors.grey)),
            ],
          ),
        );
      },
    );
  }
}

class _UserPosts extends StatelessWidget {
  final String uid;
  const _UserPosts({required this.uid});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('questions')
          .where('uid', isEqualTo: uid)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (_, snap) {
        if (!snap.hasData)
          return const Center(child: CircularProgressIndicator());
        if (snap.data!.docs.isEmpty)
          return const Center(child: Text('No posts yet'));

        return ListView.builder(
          itemCount: snap.data!.docs.length,
          itemBuilder: (_, i) {
            final data = snap.data!.docs[i].data() as Map<String, dynamic>;
            return ListTile(title: Text(data['content'] ?? ''));
          },
        );
      },
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
