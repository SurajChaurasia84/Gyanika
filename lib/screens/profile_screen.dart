import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:gyanika/screens/add_poll_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final uid = FirebaseAuth.instance.currentUser!.uid;

  @override
  void initState() {
    super.initState();
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

        return Scaffold(
          appBar: AppBar(
            title: Text('@${user['username'] ?? ''}'),
            actions: [
              IconButton(
                icon: const Icon(Icons.settings_outlined),
                onPressed: () {},
              ),
            ],
          ),

          /// ================= FLOATING ADD BUTTON =================
          floatingActionButton: FloatingActionButton(
            backgroundColor: Colors.indigo,
            child: const Icon(Icons.add),
            onPressed: () => _showCreateOptions(context),
          ),

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

                /// ================= EDIT PROFILE =================
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: SizedBox(
                    width: double.infinity,
                    height: 40,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        elevation: 0,
                        backgroundColor: Colors.indigo.shade50,
                        foregroundColor: Colors.indigo,
                      ),
                      onPressed: () {},
                      child: const Text("Edit Profile"),
                    ),
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
                  icon: Icons.help_outline,
                  label: "Question",
                  onTap: () {
                    Navigator.push(
                      context,
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
                  icon: Icons.quiz_outlined,
                  label: "Quiz",
                  onTap: () {
                    Navigator.push(
                      context,
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
                  icon: Icons.poll_outlined,
                  label: "Poll",
                  onTap: () {
                    Navigator.push(
                      context,
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
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Text(emptyText, style: const TextStyle(color: Colors.grey)),
          );
        }

        final docs = snapshot.data!.docs;

        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: docs.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, i) {
            final data = docs[i].data() as Map<String, dynamic>;
            return _PostCard(
              title: data['content'] ?? '',
              category: data['category'] ?? '',
              type: 'Question',
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
                final isQuiz = data.containsKey('questions');

                return _PostCard(
                  title: data['content'] ?? data['content'] ?? '',
                  category: data['category'] ?? '',
                  type: isQuiz ? 'Quiz' : 'Poll',
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

  const _PostCard({
    required this.title,
    required this.category,
    required this.type,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            type,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.indigo,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            title,
            style: const TextStyle(fontSize: 14),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (category.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              category,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ],
      ),
    );
  }
}
