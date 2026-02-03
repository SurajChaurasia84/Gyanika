import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'profile_screen.dart';

class LibrarySection extends StatefulWidget {
  const LibrarySection({super.key});

  @override
  State<LibrarySection> createState() => _LibrarySectionState();
}

class _LibrarySectionState extends State<LibrarySection> {
  String _filter = 'All';
  bool _showChips = true;
  bool _isSearching = false;
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: _isSearching
            ? TextField(
                controller: _searchCtrl,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Search username...',
                  border: InputBorder.none,
                ),
                onChanged: (_) => setState(() {}),
              )
            : const Text('Feed'),
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                _isSearching = !_isSearching;
                if (!_isSearching) {
                  _searchCtrl.clear();
                }
              });
            },
          ),
        ],
      ),
      body: Column(
        children: [
          if (_isSearching && _searchCtrl.text.trim().isNotEmpty)
            _UserSearchSuggestions(query: _searchCtrl.text.trim()),
          if (!_isSearching)
            AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeInOut,
            child: _showChips
                ? Column(
                    children: [
                      const SizedBox(height: 8),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Row(
                          children: [
                            _FilterChip(
                              label: 'All',
                              selected: _filter == 'All',
                              onTap: () => setState(() => _filter = 'All'),
                            ),
                            _FilterChip(
                              label: 'Questions',
                              selected: _filter == 'Questions',
                              onTap: () => setState(() => _filter = 'Questions'),
                            ),
                            _FilterChip(
                              label: 'Quizzes',
                              selected: _filter == 'Quizzes',
                              onTap: () => setState(() => _filter = 'Quizzes'),
                            ),
                            _FilterChip(
                              label: 'Polls',
                              selected: _filter == 'Polls',
                              onTap: () => setState(() => _filter = 'Polls'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  )
                : const SizedBox.shrink(),
          ),
          if (!_isSearching)
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
              stream:
                  FirebaseFirestore.instance.collection('questions').snapshots(),
              builder: (_, q) {
                return StreamBuilder<QuerySnapshot>(
                  stream:
                      FirebaseFirestore.instance.collection('polls').snapshots(),
                  builder: (_, p) {
                    return StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('quizzes')
                          .snapshots(),
                      builder: (_, z) {
                        if (!q.hasData || !p.hasData || !z.hasData) {
                          return const Center(
                              child: CircularProgressIndicator());
                        }

                        final docs = [
                          if (_filter == 'All' || _filter == 'Questions')
                            ...q.data!.docs,
                          if (_filter == 'All' || _filter == 'Polls')
                            ...p.data!.docs,
                          if (_filter == 'All' || _filter == 'Quizzes')
                            ...z.data!.docs,
                        ];

                        if (docs.isEmpty) {
                          return const Center(
                            child: Text(
                              'No posts found',
                              style: TextStyle(color: Colors.grey),
                            ),
                          );
                        }

                        docs.sort(
                          (a, b) => (b['createdAt'] as Timestamp).compareTo(
                            a['createdAt'] as Timestamp,
                          ),
                        );

                        return NotificationListener<UserScrollNotification>(
                          onNotification: (notification) {
                            if (notification.direction ==
                                    ScrollDirection.reverse &&
                                _showChips) {
                              setState(() => _showChips = false);
                            } else if (notification.direction ==
                                    ScrollDirection.forward &&
                                !_showChips) {
                              setState(() => _showChips = true);
                            }
                            return false;
                          },
                          child: ListView.builder(
                            padding: const EdgeInsets.all(12),
                            itemCount: docs.length,
                            itemBuilder: (_, i) {
                              final d =
                                  docs[i].data() as Map<String, dynamic>;
                              return FeedCard(data: d, id: docs[i].id);
                            },
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.surface;
    final textColor = selected
        ? Theme.of(context).colorScheme.onPrimary
        : Theme.of(context).colorScheme.onSurface;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
        ),
      ),
    );
  }
}

class _UserSearchSuggestions extends StatelessWidget {
  final String query;
  const _UserSearchSuggestions({required this.query});

  @override
  Widget build(BuildContext context) {
    final q = query.toLowerCase();
    final ref = FirebaseFirestore.instance
        .collection('users')
        .orderBy('username')
        .startAt([q]).endAt(['$q\uf8ff']);

    return StreamBuilder<QuerySnapshot>(
      stream: ref.limit(10).snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const SizedBox.shrink();
        }
        final docs = snap.data!.docs;
        if (docs.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Text(
              'No users found',
              style: TextStyle(color: Colors.grey),
            ),
          );
        }

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: docs.length,
            itemBuilder: (context, i) {
              final data = docs[i].data() as Map<String, dynamic>;
              final uid = docs[i].id;
              final name = (data['name'] ?? '').toString();
              final username = (data['username'] ?? '').toString();
              final letter = username.isNotEmpty ? username[0].toUpperCase() : 'U';

              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.indigo,
                  child: Text(
                    letter,
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                title: Text(name.isNotEmpty ? name : username),
                subtitle: Text('@$username'),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ProfileScreen(uid: uid),
                    ),
                  );
                },
              );
            },
          ),
        );
      },
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
    final typeLabel =
        type == 'quiz' ? 'Quiz' : type == 'poll' ? 'Poll' : 'Question';
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
                InkWell(
                  borderRadius: BorderRadius.circular(24),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ProfileScreen(uid: data['uid']),
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
                  child: InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ProfileScreen(uid: data['uid']),
                        ),
                      );
                    },
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
                ),
                FollowButton(targetUid: data['uid']),
              ],
            ),

            const SizedBox(height: 10),
            Text('Que. ${data['content'] ?? ''}'),

            if (type == 'question') AnswerBox(postId: id),
            if (type == 'poll' || type == 'quiz') ...[
              const SizedBox(height: 10),
              const Text(
                'Options',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              _OptionStatsList(
                postId: id,
                type: type,
                options: (data['options'] as List?) ?? const [],
                correctIndex: data['correctIndex'] as int?,
              ),
            ],

            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    LikeButton(postId: id, collection: collection),
                    Text(formatCount(data['likes'] ?? 0)),
                  ],
                ),
                InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PostDetailScreen(
                          postId: id,
                          collection: collection,
                          type: typeLabel,
                        ),
                      ),
                    );
                  },
                  child: Row(
                    children: [
                      Text(
                        _answerLabel(
                          type: type,
                          count: data['answeredCount'] ?? 0,
                        ),
                        style: const TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.chevron_right,
                        size: 16,
                        color: Colors.grey,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _OptionStatsList extends StatelessWidget {
  final String postId;
  final String type;
  final List options;
  final int? correctIndex;

  const _OptionStatsList({
    required this.postId,
    required this.type,
    required this.options,
    required this.correctIndex,
  });

  @override
  Widget build(BuildContext context) {
    if (options.isEmpty) {
      return const Text('No options available');
    }

    final collection = type == 'quiz' ? 'quizzes' : 'polls';
    final subcollection = type == 'quiz' ? 'attempts' : 'votes';

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection(collection)
          .doc(postId)
          .collection(subcollection)
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snap.data!.docs;
        final counts = List<int>.filled(options.length, 0);
        for (final d in docs) {
          final data = d.data() as Map<String, dynamic>;
          if (type == 'quiz') {
            final index = data['index'];
            if (index is int && index >= 0 && index < counts.length) {
              counts[index] += 1;
            }
          } else {
            final option = data['option'];
            if (option is String) {
              final idx = options.indexOf(option);
              if (idx != -1) counts[idx] += 1;
            }
          }
        }

        final total = counts.fold<int>(0, (a, b) => a + b);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ...List.generate(options.length, (i) {
              final percent = total == 0
                  ? 0
                  : ((counts[i] / total) * 100).round();
              final isCorrect = type == 'quiz' && correctIndex == i;
              final fillColor = type == 'quiz'
                  ? (isCorrect
                      ? Colors.green.withOpacity(0.18)
                      : Colors.red.withOpacity(0.12))
                  : Theme.of(context).colorScheme.primary.withOpacity(0.10);

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: Theme.of(
                      context,
                    ).colorScheme.outline.withOpacity(0.2),
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Stack(
                    children: [
                      FractionallySizedBox(
                        widthFactor: percent / 100,
                        alignment: Alignment.centerLeft,
                        child: Container(height: 44, color: fillColor),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                options[i].toString(),
                                style: TextStyle(
                                  fontWeight: isCorrect
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                  color: isCorrect
                                      ? Theme.of(context).colorScheme.primary
                                      : Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                            ),
                            Text(
                              '$percent%',
                              style: TextStyle(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        );
      },
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

String _answerLabel({required String type, required int count}) {
  if (type == 'question') return '$count answers';
  if (type == 'quiz') return '$count answers';
  if (type == 'poll') return '$count votes';
  return '$count';
}
