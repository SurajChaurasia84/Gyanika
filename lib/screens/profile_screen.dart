import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:iconsax/iconsax.dart';
import 'package:gyanika/screens/add_post_screen.dart';
import 'package:gyanika/helpers/notification_helper.dart';
import 'settings_screen.dart';

Future<String> _currentUserLabel() async {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return 'Someone';
  final snap = await FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .get();
  final data = snap.data() ?? {};
  final name = (data['name'] ?? '').toString().trim();
  if (name.isNotEmpty) return name;
  final username = (data['username'] ?? '').toString().trim();
  if (username.isNotEmpty) return username;
  return 'Someone';
}

class ProfileScreen extends StatefulWidget {
  final String? uid;
  const ProfileScreen({super.key, this.uid});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late final String uid;
  late final String myUid;

  @override
  void initState() {
    super.initState();
    myUid = FirebaseAuth.instance.currentUser!.uid;
    uid = widget.uid ?? myUid;
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final user = snapshot.data!.data() as Map<String, dynamic>;
        final isOwner = uid == myUid;

        return Scaffold(
          appBar: AppBar(
            title: Text('@${user['username'] ?? ''}'),
            actions: [
              if (isOwner)
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (_) => EditProfileDialog(
                        uid: uid,
                        initialName: user['name'] ?? '',
                        initialBio: user['bio'] ?? '',
                      ),
                    );
                  },
                ),
              if (isOwner)
                IconButton(
                  icon: const Icon(Icons.settings_outlined),
                  onPressed: () {
                    Navigator.push(
                      context,
                      PageRouteBuilder(
                        transitionDuration: const Duration(milliseconds: 250),
                        pageBuilder: (_, _, _) => const SettingsScreen(),
                        transitionsBuilder: (_, animation, _, child) {
                          return FadeTransition(
                            opacity: CurvedAnimation(
                              parent: animation,
                              curve: Curves.easeInOut,
                            ),
                            child: child,
                          );
                        },
                      ),
                    );
                  },
                ),
              if (!isOwner) _ProfileFollowButton(targetUid: uid),
            ],
          ),

          /// ================= FLOATING ADD BUTTON =================
          floatingActionButton: isOwner
              ? FloatingActionButton(
                  backgroundColor: Colors.indigo,
                  child: const Icon(Icons.add),
                  onPressed: () => _showCreateOptions(context),
                )
              : null,

          body: SafeArea(
            child: Column(
              children: [
                /// ================= PROFILE HEADER =================
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 36,
                        backgroundColor: Colors.indigo,
                        child: Text(
                          (user['username'] ?? 'U')[0].toUpperCase(),
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),

                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user['name'] ?? '',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              (user['bio'] ?? '').isNotEmpty
                                  ? user['bio']
                                  : 'No bio added',
                              style: const TextStyle(
                                fontSize: 13,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                /// ================= COUNTS ROW =================
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _StatItem(label: "Posts", value: user['posts'] ?? 0),
                      _StatItem(
                        label: "Followers",
                        value: user['followers'] ?? 0,
                      ),
                      _StatItem(
                        label: "Following",
                        value: user['following'] ?? 0,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                /// ================= TABS =================
                TabBar(
                  controller: _tabController,
                  indicatorColor: Colors.indigo,
                  labelColor: Colors.indigo,
                  unselectedLabelColor: Colors.grey,
                  tabs: const [
                    Tab(text: "Questions"),
                    Tab(text: "Quizzes & Polls"),
                  ],
                ),

                /// ================= TAB CONTENT =================
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _UserPostsList(
                        collection: 'questions',
                        uid: uid,
                        emptyText: "No questions yet",
                      ),
                      _MixedPostsList(uid: uid),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// ================= BOTTOM CREATE OPTIONS =================
  void _showCreateOptions(BuildContext context) {
    final parentContext = context;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  "Create New",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),

                _CreateOptionTile(
                  icon: Iconsax.message_question,
                  label: "Question",
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      parentContext,
                      PageRouteBuilder(
                        transitionDuration: const Duration(milliseconds: 250),
                        pageBuilder: (_, _, _) => const AddQuestionScreen(),
                        transitionsBuilder: (_, animation, _, child) {
                          return FadeTransition(
                            opacity: CurvedAnimation(
                              parent: animation,
                              curve: Curves.easeInOut,
                            ),
                            child: child,
                          );
                        },
                      ),
                    );
                  },
                ),

                _CreateOptionTile(
                  icon: Iconsax.chart,
                  label: "Quiz",
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      parentContext,
                      PageRouteBuilder(
                        transitionDuration: const Duration(milliseconds: 250),
                        pageBuilder: (_, _, _) => const AddQuizScreen(),
                        transitionsBuilder: (_, animation, _, child) {
                          return FadeTransition(
                            opacity: CurvedAnimation(
                              parent: animation,
                              curve: Curves.easeInOut,
                            ),
                            child: child,
                          );
                        },
                      ),
                    );
                  },
                ),

                _CreateOptionTile(
                  icon: Iconsax.percentage_square,
                  label: "Poll",
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      parentContext,
                      PageRouteBuilder(
                        transitionDuration: const Duration(milliseconds: 250),
                        pageBuilder: (_, _, _) => const AddPollScreen(),
                        transitionsBuilder: (_, animation, _, child) {
                          return FadeTransition(
                            opacity: CurvedAnimation(
                              parent: animation,
                              curve: Curves.easeInOut,
                            ),
                            child: child,
                          );
                        },
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _UserPostsList extends StatelessWidget {
  final String collection;
  final String uid;
  final String emptyText;

  const _UserPostsList({
    required this.collection,
    required this.uid,
    required this.emptyText,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection(collection)
          .where('uid', isEqualTo: uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Failed to load questions',
              style: const TextStyle(color: Colors.grey),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Text(emptyText, style: const TextStyle(color: Colors.grey)),
          );
        }

        final docs = snapshot.data!.docs.toList()
          ..sort((a, b) {
            final aData = a.data() as Map<String, dynamic>;
            final bData = b.data() as Map<String, dynamic>;
            final aTs = aData['createdAt'] as Timestamp?;
            final bTs = bData['createdAt'] as Timestamp?;
            if (aTs == null && bTs == null) return 0;
            if (aTs == null) return 1;
            if (bTs == null) return -1;
            return bTs.compareTo(aTs);
          });

        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: docs.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, i) {
            final data = docs[i].data() as Map<String, dynamic>;
            final postId = docs[i].id;
            return _PostCard(
              title: data['content'] ?? '',
              category: data['category'] ?? '',
              type: 'Question',
              likes: (data['likes'] ?? 0) as int,
              answered: (data['answeredCount'] ?? 0) as int,
              createdAt: data['createdAt'] as Timestamp?,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PostDetailScreen(
                      postId: postId,
                      collection: 'questions',
                      type: 'Question',
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

/// ================= STAT ITEM =================
class _StatItem extends StatelessWidget {
  final String label;
  final int value;

  const _StatItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value.toString(),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}

/// ================= CREATE OPTION TILE =================
class _CreateOptionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _CreateOptionTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: Colors.indigo),
      title: Text(label),
      onTap: onTap,
    );
  }
}

class _ProfileFollowButton extends StatelessWidget {
  final String targetUid;
  const _ProfileFollowButton({required this.targetUid});

  @override
  Widget build(BuildContext context) {
    final myUid = FirebaseAuth.instance.currentUser!.uid;
    if (myUid == targetUid) return const SizedBox.shrink();

    final ref = FirebaseFirestore.instance
        .collection('users')
        .doc(targetUid)
        .collection('followers')
        .doc(myUid);

    return StreamBuilder<DocumentSnapshot>(
      stream: ref.snapshots(),
      builder: (_, snap) {
        final isFollowing = snap.data?.exists ?? false;
        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: InkWell(
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

              if (myUid == targetUid) {
                return;
              }

              if (isFollowing) {
                await NotificationHelper.removeFollowActivity(
                  targetUid: targetUid,
                  actorUid: myUid,
                );
              } else {
                final myName = await _currentUserLabel();
                await NotificationHelper.upsertFollowActivity(
                  targetUid: targetUid,
                  title: '$myName started followed you',
                  actorUid: myUid,
                );
              }
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
          ),
        );
      },
    );
  }
}

class _MixedPostsList extends StatelessWidget {
  final String uid;
  const _MixedPostsList({required this.uid});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('quizzes')
          .where('uid', isEqualTo: uid)
          .snapshots(),
      builder: (context, quizSnap) {
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('polls')
              .where('uid', isEqualTo: uid)
              .snapshots(),
          builder: (context, pollSnap) {
            if (quizSnap.connectionState == ConnectionState.waiting ||
                pollSnap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final quizDocs = quizSnap.data?.docs ?? [];
            final pollDocs = pollSnap.data?.docs ?? [];

            final all = [...quizDocs, ...pollDocs];

            if (all.isEmpty) {
              return const Center(
                child: Text(
                  "No quizzes or polls yet",
                  style: TextStyle(color: Colors.grey),
                ),
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: all.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final data = all[i].data() as Map<String, dynamic>;
                final type = (data['type'] ?? '').toString();
                final isQuiz = type == 'quiz';
                final postId = all[i].id;
                final collection = isQuiz ? 'quizzes' : 'polls';

                return _PostCard(
                  title: 'Que. ${data['content'] ?? ''}',
                  category: data['category'] ?? '',
                  type: isQuiz ? 'Quiz' : 'Poll',
                  likes: (data['likes'] ?? 0) as int,
                  answered: (data['answeredCount'] ?? 0) as int,
                  createdAt: data['createdAt'] as Timestamp?,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PostDetailScreen(
                          postId: postId,
                          collection: collection,
                          type: isQuiz ? 'Quiz' : 'Poll',
                        ),
                      ),
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }
}

class _PostCard extends StatelessWidget {
  final String title;
  final String category;
  final String type;
  final int likes;
  final int answered;
  final Timestamp? createdAt;
  final VoidCallback? onTap;

  const _PostCard({
    required this.title,
    required this.category,
    required this.type,
    this.likes = 0,
    this.answered = 0,
    this.createdAt,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                type,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              _MetaRow(
                items: [
                  _MetaItem.label(_timeLabel(createdAt)),
                  if (category.isNotEmpty) _MetaItem.label(category),
                  _MetaItem.iconText(
                    icon: Icons.favorite,
                    text: likes.toString(),
                  ),
                  _MetaItem.iconText(
                    icon: Icons.question_answer,
                    text: answered.toString(),
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

class EditProfileDialog extends StatefulWidget {
  final String uid;
  final String initialName;
  final String initialBio;

  const EditProfileDialog({
    super.key,
    required this.uid,
    required this.initialName,
    required this.initialBio,
  });

  @override
  State<EditProfileDialog> createState() => _EditProfileDialogState();
}

class _EditProfileDialogState extends State<EditProfileDialog> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _bioCtrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.initialName);
    _bioCtrl = TextEditingController(text: widget.initialBio);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _bioCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    await FirebaseFirestore.instance.collection('users').doc(widget.uid).set({
      'name': _nameCtrl.text.trim(),
      'bio': _bioCtrl.text.trim(),
    }, SetOptions(merge: true));
    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Profile'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameCtrl,
            decoration: const InputDecoration(labelText: 'Name'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _bioCtrl,
            decoration: const InputDecoration(labelText: 'Bio'),
            minLines: 1,
            maxLines: 3,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save'),
        ),
      ],
    );
  }
}

class PostDetailScreen extends StatelessWidget {
  final String postId;
  final String collection;
  final String type;

  const PostDetailScreen({
    super.key,
    required this.postId,
    required this.collection,
    required this.type,
  });

  @override
  Widget build(BuildContext context) {
    final postRef = FirebaseFirestore.instance
        .collection(collection)
        .doc(postId);
    final myUid = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Text(type),
        actions: [
          StreamBuilder<DocumentSnapshot>(
            stream: postRef.snapshots(),
            builder: (_, snap) {
              final data = snap.data?.data() as Map<String, dynamic>?;
              final ownerUid = (data?['uid'] ?? '').toString();
              final isOwner = ownerUid == myUid;
              if (!isOwner) return const SizedBox.shrink();
              return PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert),
                onSelected: (value) async {
                  if (value == 'edit') {
                    showDialog(
                      context: context,
                      builder: (_) => _EditPostDialog(postRef: postRef),
                    );
                  }
                  if (value == 'delete') {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text('Delete Post'),
                        content: const Text('Are you sure you want to delete?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Cancel'),
                          ),
                          ElevatedButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('Delete'),
                          ),
                        ],
                      ),
                    );
                    if (confirm != true) return;
                    await postRef.delete();
                    await FirebaseFirestore.instance
                        .collection('users')
                        .doc(myUid)
                        .set({
                          'posts': FieldValue.increment(-1),
                        }, SetOptions(merge: true));
                    if (!context.mounted) return;
                    Navigator.pop(context);
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Text('Edit')),
                  PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: postRef.snapshots(),
        builder: (_, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snap.data!.data() as Map<String, dynamic>;
          final content = (data['content'] ?? '').toString();
          final category = (data['category'] ?? '').toString();
          final likes = (data['likes'] ?? 0) as int;
          final createdAt = data['createdAt'] as Timestamp?;
          final options = (data['options'] as List?) ?? const [];
          final correctIndex = data['correctIndex'] as int?;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(content, style: const TextStyle(fontSize: 16)),
              const SizedBox(height: 8),
              _MetaRow(
                items: [
                  _MetaItem.label(_timeLabel(createdAt)),
                  if (category.isNotEmpty) _MetaItem.label(category),
                  _MetaItem.iconText(
                    icon: Icons.favorite,
                    text: likes.toString(),
                  ),
                ],
              ),
              if (type == 'Poll' || type == 'Quiz') ...[
                const SizedBox(height: 16),
                const Text(
                  'Options',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                _OptionStatsList(
                  postId: postId,
                  type: type,
                  options: options,
                  correctIndex: correctIndex,
                ),
              ],
              if (type == 'Question') ...[
                const SizedBox(height: 16),
                _QuestionAnswerBox(
                  postId: postId,
                  ownerUid: (data['uid'] ?? '').toString(),
                ),
                const SizedBox(height: 12),
                _AnswerList(postId: postId),
              ],
            ],
          );
        },
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

    final collection = type == 'Quiz' ? 'quizzes' : 'polls';
    final subcollection = type == 'Quiz' ? 'attempts' : 'votes';

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
          if (type == 'Quiz') {
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
              final isCorrect = type == 'Quiz' && correctIndex == i;
              final fillColor = isCorrect
                  ? Theme.of(context).colorScheme.primary.withOpacity(0.18)
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
                                fontWeight: FontWeight.w600,
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
            const SizedBox(height: 4),
            Center(
              child: Text(
                type == 'Quiz' ? '$total answers' : '$total votes',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _AnswerList extends StatelessWidget {
  final String postId;
  const _AnswerList({required this.postId});

  @override
  Widget build(BuildContext context) {
    final ref = FirebaseFirestore.instance
        .collection('questions')
        .doc(postId)
        .collection('answers');

    return StreamBuilder<QuerySnapshot>(
      stream: ref.snapshots(),
      builder: (_, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.data!.docs.isEmpty) {
          return const Expanded(
            child: Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: EdgeInsets.only(top: 16),
                child: Text(
                  'No answers yet',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            ),
          );
        }

        final docs = snap.data!.docs.toList()
          ..sort((a, b) {
            final aData = a.data() as Map<String, dynamic>;
            final bData = b.data() as Map<String, dynamic>;
            final aTs = aData['createdAt'] as Timestamp?;
            final bTs = bData['createdAt'] as Timestamp?;
            if (aTs == null && bTs == null) return 0;
            if (aTs == null) return 1;
            if (bTs == null) return -1;
            return bTs.compareTo(aTs);
          });

        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: docs.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (_, i) {
            final data = docs[i].data() as Map<String, dynamic>;
            return _AnswerTile(
              answerId: docs[i].id,
              answerUid: (data['uid'] ?? '').toString(),
              text: (data['text'] ?? '').toString(),
              createdAt: data['createdAt'] as Timestamp?,
              postId: postId,
            );
          },
        );
      },
    );
  }
}

class _QuestionAnswerBox extends StatefulWidget {
  final String postId;
  final String ownerUid;

  const _QuestionAnswerBox({required this.postId, required this.ownerUid});

  @override
  State<_QuestionAnswerBox> createState() => _QuestionAnswerBoxState();
}

class _QuestionAnswerBoxState extends State<_QuestionAnswerBox> {
  final TextEditingController _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_ctrl.text.trim().isEmpty) return;
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final ref = FirebaseFirestore.instance
        .collection('questions')
        .doc(widget.postId)
        .collection('answers')
        .doc(uid);

    if ((await ref.get()).exists) return;
    await ref.set({
      'text': _ctrl.text.trim(),
      'uid': uid,
      'createdAt': FieldValue.serverTimestamp(),
    });
    await FirebaseFirestore.instance
        .collection('questions')
        .doc(widget.postId)
        .update({'answeredCount': FieldValue.increment(1)});

    if (uid != widget.ownerUid) {
      final myName = await _currentUserLabel();
      await NotificationHelper.addActivity(
        targetUid: widget.ownerUid,
        type: 'answer',
        title: '$myName answered your question.',
        actorUid: uid,
        postId: widget.postId,
        postType: 'question',
        content: _ctrl.text.trim(),
      );
    }
    _ctrl.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _ctrl,
            decoration: const InputDecoration(hintText: 'Answer...'),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.arrow_upward, color: Colors.indigo),
          onPressed: _submit,
        ),
      ],
    );
  }
}

class _AnswerTile extends StatefulWidget {
  final String answerId;
  final String answerUid;
  final String text;
  final Timestamp? createdAt;
  final String postId;

  const _AnswerTile({
    required this.answerId,
    required this.answerUid,
    required this.text,
    required this.createdAt,
    required this.postId,
  });

  @override
  State<_AnswerTile> createState() => _AnswerTileState();
}

class _AnswerTileState extends State<_AnswerTile> {
  bool _replying = false;
  final TextEditingController _replyCtrl = TextEditingController();
  bool _sending = false;
  bool _showResponses = false;

  @override
  void dispose() {
    _replyCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendReply() async {
    if (_sending) return;
    final text = _replyCtrl.text.trim();
    if (text.isEmpty) return;
    setState(() => _sending = true);
    final myUid = FirebaseAuth.instance.currentUser!.uid;
    await FirebaseFirestore.instance
        .collection('questions')
        .doc(widget.postId)
        .collection('answers')
        .doc(widget.answerId)
        .collection('responses')
        .add({
          'uid': myUid,
          'text': text,
          'createdAt': FieldValue.serverTimestamp(),
        });
    if (!mounted) return;
    setState(() {
      _sending = false;
      _replying = false;
      _replyCtrl.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final userRef = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.answerUid);
    final timeText = _timeLabel(widget.createdAt);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StreamBuilder<DocumentSnapshot>(
            stream: userRef.snapshots(),
            builder: (_, snap) {
              final username =
                  (snap.data?.data() as Map<String, dynamic>?)?['username'] ??
                  'User';
              final safeName = username.toString();
              return Row(
                children: [
                  InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ProfileScreen(uid: widget.answerUid),
                        ),
                      );
                    },
                    child: CircleAvatar(
                      radius: 14,
                      backgroundColor: Colors.indigo,
                      child: Text(
                        safeName.isNotEmpty ? safeName[0].toUpperCase() : 'U',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ProfileScreen(uid: widget.answerUid),
                        ),
                      );
                    },
                    child: Text(
                      safeName,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '•',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    timeText,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(
                      _showResponses
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    onPressed: () =>
                        setState(() => _showResponses = !_showResponses),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 6),
          Text(widget.text),
          if (_showResponses) ...[
            const SizedBox(height: 8),
            _ResponseList(postId: widget.postId, answerId: widget.answerId),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              TextButton(
                onPressed: () => setState(() => _replying = !_replying),
                child: Text(_replying ? 'Cancel' : 'Reply'),
              ),
            ],
          ),
          if (_replying) ...[
            TextField(
              controller: _replyCtrl,
              decoration: const InputDecoration(hintText: 'Write a reply...'),
            ),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton(
                onPressed: _sending ? null : _sendReply,
                child: _sending
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Send'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

String _timeAgo(Timestamp t) {
  final d = DateTime.now().difference(t.toDate());
  if (d.inMinutes < 1) return 'just now';
  if (d.inMinutes < 60) return '${d.inMinutes}m ago';
  if (d.inHours < 24) return '${d.inHours}h ago';
  return '${d.inDays}d ago';
}

String _timeLabel(Timestamp? t) {
  if (t == null) return 'just now';
  return _timeAgo(t);
}

class _MetaItem {
  final IconData? icon;
  final String text;

  const _MetaItem._({required this.text, this.icon});

  static _MetaItem label(String text) => _MetaItem._(text: text);

  static _MetaItem iconText({required IconData icon, required String text}) =>
      _MetaItem._(text: text, icon: icon);
}

class _MetaRow extends StatelessWidget {
  final List<_MetaItem> items;

  const _MetaRow({required this.items});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    final widgets = <Widget>[];
    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      if (item.icon != null) {
        widgets.add(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(item.icon, size: 14, color: color),
              const SizedBox(width: 4),
              Text(item.text, style: TextStyle(fontSize: 12, color: color)),
            ],
          ),
        );
      } else {
        widgets.add(
          Text(item.text, style: TextStyle(fontSize: 12, color: color)),
        );
      }
      if (i != items.length - 1) {
        widgets.add(const SizedBox(width: 8));
        widgets.add(Text('•', style: TextStyle(fontSize: 12, color: color)));
        widgets.add(const SizedBox(width: 8));
      }
    }
    return Wrap(spacing: 0, runSpacing: 6, children: widgets);
  }
}

class _ResponseList extends StatelessWidget {
  final String postId;
  final String answerId;

  const _ResponseList({required this.postId, required this.answerId});

  @override
  Widget build(BuildContext context) {
    final ref = FirebaseFirestore.instance
        .collection('questions')
        .doc(postId)
        .collection('answers')
        .doc(answerId)
        .collection('responses');

    return StreamBuilder<QuerySnapshot>(
      stream: ref.snapshots(),
      builder: (_, snap) {
        if (!snap.hasData) {
          return const SizedBox.shrink();
        }
        if (snap.data!.docs.isEmpty) {
          return const Text(
            'No responses yet',
            style: TextStyle(color: Colors.grey, fontSize: 12),
          );
        }

        final docs = snap.data!.docs.toList()
          ..sort((a, b) {
            final aData = a.data() as Map<String, dynamic>;
            final bData = b.data() as Map<String, dynamic>;
            final aTs = aData['createdAt'] as Timestamp?;
            final bTs = bData['createdAt'] as Timestamp?;
            if (aTs == null && bTs == null) return 0;
            if (aTs == null) return 1;
            if (bTs == null) return -1;
            return bTs.compareTo(aTs);
          });

        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: docs.length,
          separatorBuilder: (_, _) => const SizedBox(height: 6),
          itemBuilder: (_, i) {
            final data = docs[i].data() as Map<String, dynamic>;
            final uid = (data['uid'] ?? '').toString();
            final text = (data['text'] ?? '').toString();
            final createdAt = data['createdAt'] as Timestamp?;

            return _ResponseTile(uid: uid, text: text, createdAt: createdAt);
          },
        );
      },
    );
  }
}

class _ResponseTile extends StatelessWidget {
  final String uid;
  final String text;
  final Timestamp? createdAt;

  const _ResponseTile({
    required this.uid,
    required this.text,
    required this.createdAt,
  });

  @override
  Widget build(BuildContext context) {
    final userRef = FirebaseFirestore.instance.collection('users').doc(uid);
    final timeText = _timeLabel(createdAt);

    return StreamBuilder<DocumentSnapshot>(
      stream: userRef.snapshots(),
      builder: (_, snap) {
        final username =
            (snap.data?.data() as Map<String, dynamic>?)?['username'] ?? 'User';
        final safeName = username.toString();
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => ProfileScreen(uid: uid)),
                );
              },
              child: CircleAvatar(
                radius: 10,
                backgroundColor: Colors.indigo,
                child: Text(
                  safeName.isNotEmpty ? safeName[0].toUpperCase() : 'U',
                  style: const TextStyle(
                    fontSize: 10,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      InkWell(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ProfileScreen(uid: uid),
                            ),
                          );
                        },
                        child: Text(
                          safeName,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '•',
                        style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        timeText,
                        style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  Text(text),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _EditPostDialog extends StatefulWidget {
  final DocumentReference postRef;

  const _EditPostDialog({required this.postRef});

  @override
  State<_EditPostDialog> createState() => _EditPostDialogState();
}

class _EditPostDialogState extends State<_EditPostDialog> {
  final TextEditingController _contentCtrl = TextEditingController();
  final TextEditingController _categoryCtrl = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _contentCtrl.dispose();
    _categoryCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    await widget.postRef.set({
      'content': _contentCtrl.text.trim(),
      'category': _categoryCtrl.text.trim(),
    }, SetOptions(merge: true));
    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: widget.postRef.snapshots(),
      builder: (_, snap) {
        if (!snap.hasData) {
          return const AlertDialog(
            content: SizedBox(
              height: 60,
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }
        final data = snap.data!.data() as Map<String, dynamic>;
        _contentCtrl.text = (data['content'] ?? '').toString();
        _categoryCtrl.text = (data['category'] ?? '').toString();

        return AlertDialog(
          title: const Text('Edit Post'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _contentCtrl,
                decoration: const InputDecoration(labelText: 'Content'),
                minLines: 1,
                maxLines: 3,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _categoryCtrl,
                decoration: const InputDecoration(labelText: 'Category'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: _saving ? null : () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save'),
            ),
          ],
        );
      },
    );
  }
}
