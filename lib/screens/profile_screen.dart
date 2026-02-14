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

Future<void> _toggleFollowRelation({
  required String myUid,
  required String targetUid,
  required bool isFollowing,
}) async {
  final batch = FirebaseFirestore.instance.batch();
  final targetFollowerRef = FirebaseFirestore.instance
      .collection('users')
      .doc(targetUid)
      .collection('followers')
      .doc(myUid);
  final myFollowingRef = FirebaseFirestore.instance
      .collection('users')
      .doc(myUid)
      .collection('following')
      .doc(targetUid);

  if (isFollowing) {
    batch.delete(targetFollowerRef);
    batch.delete(myFollowingRef);
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
    batch.set(targetFollowerRef, {'time': Timestamp.now()});
    batch.set(myFollowingRef, {'time': Timestamp.now()});
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

  if (myUid == targetUid) return;
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
}

Future<void> _removeFollowerRelation({
  required String ownerUid,
  required String followerUid,
}) async {
  final batch = FirebaseFirestore.instance.batch();
  final ownerFollowerRef = FirebaseFirestore.instance
      .collection('users')
      .doc(ownerUid)
      .collection('followers')
      .doc(followerUid);
  final followerFollowingRef = FirebaseFirestore.instance
      .collection('users')
      .doc(followerUid)
      .collection('following')
      .doc(ownerUid);

  batch.delete(ownerFollowerRef);
  batch.delete(followerFollowingRef);
  batch.set(
    FirebaseFirestore.instance.collection('users').doc(ownerUid),
    {'followers': FieldValue.increment(-1)},
    SetOptions(merge: true),
  );
  batch.set(
    FirebaseFirestore.instance.collection('users').doc(followerUid),
    {'following': FieldValue.increment(-1)},
    SetOptions(merge: true),
  );
  await batch.commit();

  await NotificationHelper.removeFollowActivity(
    targetUid: ownerUid,
    actorUid: followerUid,
  );
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
  final ScrollController _profileScrollController = ScrollController();
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
  void dispose() {
    _tabController.dispose();
    _profileScrollController.dispose();
    super.dispose();
  }

  void _focusOnPosts() {
    if (!_profileScrollController.hasClients) return;
    final targetOffset = _profileScrollController.position.maxScrollExtent > 220
        ? 220.0
        : _profileScrollController.position.maxScrollExtent;
    _profileScrollController.animateTo(
      targetOffset,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
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
            child: NestedScrollView(
              controller: _profileScrollController,
              headerSliverBuilder: (context, innerBoxIsScrolled) {
                return [
                  SliverToBoxAdapter(
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
                              _StatItem(
                                label: "Posts",
                                value: user['posts'] ?? 0,
                                onTap: _focusOnPosts,
                              ),
                              _StatItem(
                                label: "Followers",
                                value: user['followers'] ?? 0,
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => FollowedUsersScreen(
                                        uid: uid,
                                        showFollowers: true,
                                      ),
                                    ),
                                  );
                                },
                              ),
                              _StatItem(
                                label: "Following",
                                value: user['following'] ?? 0,
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => FollowedUsersScreen(
                                        uid: uid,
                                        showFollowers: false,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                    ),
                  ),
                  SliverOverlapAbsorber(
                    handle: NestedScrollView.sliverOverlapAbsorberHandleFor(
                      context,
                    ),
                    sliver: SliverPersistentHeader(
                      pinned: true,
                      delegate: _PinnedTabBarDelegate(
                        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                        tabBar: TabBar(
                          controller: _tabController,
                          indicatorColor: Colors.indigo,
                          labelColor: Colors.indigo,
                          unselectedLabelColor: Colors.grey,
                          tabs: const [
                            Tab(text: "Questions"),
                            Tab(text: "Quizzes & Polls"),
                          ],
                        ),
                      ),
                    ),
                  ),
                ];
              },
              body: TabBarView(
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
          return _buildInfoScroll(
            context,
            child: const Text(
              'Failed to load questions',
              style: TextStyle(color: Colors.grey),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildInfoScroll(
            context,
            child: const CircularProgressIndicator(),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildInfoScroll(
            context,
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

        return Builder(
          builder: (innerContext) {
            return CustomScrollView(
              slivers: [
                SliverOverlapInjector(
                  handle: NestedScrollView.sliverOverlapAbsorberHandleFor(
                    innerContext,
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.all(12),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      if (index.isOdd) return const SizedBox(height: 10);
                      final i = index ~/ 2;
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
                    }, childCount: docs.length * 2 - 1),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildInfoScroll(BuildContext context, {required Widget child}) {
    return Builder(
      builder: (innerContext) {
        return CustomScrollView(
          slivers: [
            SliverOverlapInjector(
              handle: NestedScrollView.sliverOverlapAbsorberHandleFor(
                innerContext,
              ),
            ),
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: child),
            ),
          ],
        );
      },
    );
  }
}

/// ================= STAT ITEM =================
class _StatItem extends StatelessWidget {
  final String label;
  final int value;
  final VoidCallback? onTap;

  const _StatItem({required this.label, required this.value, this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Column(
          children: [
            Text(
              value.toString(),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            Text(label, style: const TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

class _PinnedTabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  final Color backgroundColor;

  _PinnedTabBarDelegate({required this.tabBar, required this.backgroundColor});

  @override
  double get minExtent => tabBar.preferredSize.height;

  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      color: backgroundColor,
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(covariant _PinnedTabBarDelegate oldDelegate) {
    return oldDelegate.tabBar != tabBar ||
        oldDelegate.backgroundColor != backgroundColor;
  }
}

class FollowedUsersScreen extends StatefulWidget {
  final String uid;
  final bool showFollowers;

  const FollowedUsersScreen({
    super.key,
    required this.uid,
    required this.showFollowers,
  });

  @override
  State<FollowedUsersScreen> createState() => _FollowedUsersScreenState();
}

class _FollowedUsersScreenState extends State<FollowedUsersScreen> {
  final List<String> _sessionFollowingIds = [];

  void _mergeFollowingIds(List<String> latestIds) {
    for (final id in latestIds) {
      if (!_sessionFollowingIds.contains(id)) {
        _sessionFollowingIds.add(id);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = widget.uid;
    final showFollowers = widget.showFollowers;
    final relation = showFollowers ? 'followers' : 'following';
    final title = showFollowers ? 'Followers' : 'Following';
    final emptyText = showFollowers ? 'No followers' : 'No followed users';
    final myUid = FirebaseAuth.instance.currentUser!.uid;
    final canManage = uid == myUid;
    final ref = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection(relation)
        .orderBy('time', descending: true);

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: StreamBuilder<QuerySnapshot>(
        stream: ref.snapshots(),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snap.data!.docs;
          final latestIds = docs.map((e) => e.id).toList();

          final shouldHoldFollowingList = canManage && !showFollowers;
          if (shouldHoldFollowingList) {
            _mergeFollowingIds(latestIds);
          }
          final idsToShow = shouldHoldFollowingList ? _sessionFollowingIds : latestIds;

          if (idsToShow.isEmpty) {
            return Center(child: Text(emptyText));
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            itemCount: idsToShow.length,
            itemBuilder: (context, i) {
              final targetUid = idsToShow[i];
              return _FollowedUserTile(
                uid: targetUid,
                ownerUid: uid,
                canManage: canManage,
                showFollowers: showFollowers,
              );
            },
          );
        },
      ),
    );
  }
}

class _FollowedUserTile extends StatelessWidget {
  final String uid;
  final String ownerUid;
  final bool canManage;
  final bool showFollowers;

  const _FollowedUserTile({
    required this.uid,
    required this.ownerUid,
    required this.canManage,
    required this.showFollowers,
  });

  @override
  Widget build(BuildContext context) {
    final userRef = FirebaseFirestore.instance.collection('users').doc(uid);

    return StreamBuilder<DocumentSnapshot>(
      stream: userRef.snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) return const SizedBox.shrink();
        final data = snap.data!.data() as Map<String, dynamic>? ?? {};
        final name = (data['name'] ?? '').toString().trim();
        final username = (data['username'] ?? '').toString().trim();
        final display = name.isNotEmpty ? name : username;
        final letter = display.isNotEmpty ? display[0].toUpperCase() : 'U';

        return ListTile(
          contentPadding: EdgeInsets.zero,
          leading: CircleAvatar(
            backgroundColor: Colors.indigo,
            child: Text(letter, style: const TextStyle(color: Colors.white)),
          ),
          title: Text(display.isNotEmpty ? display : 'User'),
          subtitle: Text(username.isNotEmpty ? '@$username' : ''),
          trailing: canManage
              ? (showFollowers
                    ? _RemoveFollowerButton(ownerUid: ownerUid, followerUid: uid)
                    : _InlineFollowButton(targetUid: uid))
              : null,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => ProfileScreen(uid: uid)),
            );
          },
        );
      },
    );
  }
}

class _InlineFollowButton extends StatelessWidget {
  final String targetUid;
  const _InlineFollowButton({required this.targetUid});

  @override
  Widget build(BuildContext context) {
    final myUid = FirebaseAuth.instance.currentUser!.uid;
    if (myUid == targetUid) return const SizedBox.shrink();

    final targetFollowerRef = FirebaseFirestore.instance
        .collection('users')
        .doc(targetUid)
        .collection('followers')
        .doc(myUid);

    return StreamBuilder<DocumentSnapshot>(
      stream: targetFollowerRef.snapshots(),
      builder: (_, snap) {
        final isFollowing = snap.data?.exists ?? false;
        return InkWell(
          onTap: () async {
            await _toggleFollowRelation(
              myUid: myUid,
              targetUid: targetUid,
              isFollowing: isFollowing,
            );
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: isFollowing ? Colors.grey.shade200 : Colors.indigo,
              borderRadius: BorderRadius.circular(18),
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

class _RemoveFollowerButton extends StatelessWidget {
  final String ownerUid;
  final String followerUid;

  const _RemoveFollowerButton({
    required this.ownerUid,
    required this.followerUid,
  });

  @override
  Widget build(BuildContext context) {
    final myUid = FirebaseAuth.instance.currentUser!.uid;
    if (myUid != ownerUid || followerUid == ownerUid) {
      return const SizedBox.shrink();
    }

    return TextButton(
      onPressed: () async {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) {
            return AlertDialog(
              title: const Text('Remove follower?'),
              content: const Text(
                'This will remove this user from your followers.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: const Text('Remove'),
                ),
              ],
            );
          },
        );
        if (confirmed != true) return;
        await _removeFollowerRelation(ownerUid: ownerUid, followerUid: followerUid);
      },
      style: TextButton.styleFrom(
        foregroundColor: Colors.red,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: const Text('Remove'),
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
              await _toggleFollowRelation(
                myUid: myUid,
                targetUid: targetUid,
                isFollowing: isFollowing,
              );
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
              return _buildInfoScroll(
                context,
                child: const CircularProgressIndicator(),
              );
            }

            final quizDocs = quizSnap.data?.docs ?? [];
            final pollDocs = pollSnap.data?.docs ?? [];

            final all = [...quizDocs, ...pollDocs];

            if (all.isEmpty) {
              return _buildInfoScroll(
                context,
                child: const Text(
                  "No quizzes or polls yet",
                  style: TextStyle(color: Colors.grey),
                ),
              );
            }

            return Builder(
              builder: (innerContext) {
                return CustomScrollView(
                  slivers: [
                    SliverOverlapInjector(
                      handle: NestedScrollView.sliverOverlapAbsorberHandleFor(
                        innerContext,
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.all(12),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate((context, index) {
                          if (index.isOdd) return const SizedBox(height: 10);
                          final i = index ~/ 2;
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
                        }, childCount: all.length * 2 - 1),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildInfoScroll(BuildContext context, {required Widget child}) {
    return Builder(
      builder: (innerContext) {
        return CustomScrollView(
          slivers: [
            SliverOverlapInjector(
              handle: NestedScrollView.sliverOverlapAbsorberHandleFor(
                innerContext,
              ),
            ),
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: child),
            ),
          ],
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

  static const List<String> _reportReasons = [
    'Abusive content',
    'Harassment',
    'Sexual content',
    'Hate speech',
    'Violence or threat',
    'Spam or scam',
    'Misinformation',
    'Impersonation',
    'Misleading',
    'Self-harm content',
    'Not mentioned',
    'Other',
  ];

  Future<void> _showReportReasonPicker(
    BuildContext context, {
    required String ownerUid,
    required Map<String, dynamic> postData,
  }) async {
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    if (myUid == null || myUid == ownerUid) return;

    final reason = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        String? selectedReason;
        return SafeArea(
          child: StatefulBuilder(
            builder: (context, setModalState) {
              final canSubmit = (selectedReason ?? '').trim().isNotEmpty;
              final textColor =
                  Theme.of(context).colorScheme.onSurface.withOpacity(0.74);

              return DraggableScrollableSheet(
                expand: false,
                initialChildSize: 0.5,
                minChildSize: 0.35,
                maxChildSize: 0.9,
                builder: (context, scrollController) {
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            const Text(
                              'Report post',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const Spacer(),
                            TextButton(
                              onPressed: canSubmit
                                  ? () async {
                                      final ok = await showDialog<bool>(
                                        context: context,
                                        builder: (dialogContext) => AlertDialog(
                                          title: const Text('Submit report?'),
                                          content: const Text(
                                            'Are you sure you want to submit this report?',
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () => Navigator.pop(
                                                dialogContext,
                                                false,
                                              ),
                                              child: const Text('Cancel'),
                                            ),
                                            FilledButton(
                                              onPressed: () => Navigator.pop(
                                                dialogContext,
                                                true,
                                              ),
                                              child: const Text('Submit'),
                                            ),
                                          ],
                                        ),
                                      );
                                      if (ok == true && context.mounted) {
                                        Navigator.pop(context, selectedReason);
                                      }
                                    }
                                  : null,
                              child: Text(
                                'Submit',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: canSubmit
                                      ? null
                                      : Theme.of(context)
                                          .colorScheme
                                          .onSurface
                                          .withOpacity(0.35),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Expanded(
                          child: ListView.separated(
                            controller: scrollController,
                            itemCount: _reportReasons.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 2),
                            itemBuilder: (context, i) {
                              final reason = _reportReasons[i];
                              final selected = selectedReason == reason;
                              return InkWell(
                                borderRadius: BorderRadius.circular(10),
                                onTap: () {
                                  setModalState(() => selectedReason = reason);
                                },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 8,
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          reason,
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: textColor,
                                            fontWeight: selected
                                                ? FontWeight.w600
                                                : FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                      if (selected)
                                        Icon(
                                          Icons.check_circle,
                                          size: 18,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .primary,
                                        ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        );
      },
    );

    if (reason == null || reason.trim().isEmpty) return;

    final reportDocId = '${myUid}_${collection}_$postId';
    final content = (postData['content'] ?? '').toString();
    final category = (postData['category'] ?? '').toString();
    await FirebaseFirestore.instance.collection('reports').doc(reportDocId).set({
      'reporterUid': myUid,
      'reportedUid': ownerUid,
      'postId': postId,
      'collection': collection,
      'postType': type,
      'reason': reason,
      'content': content,
      'category': category,
      'status': 'pending',
      'updatedAt': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Report submitted')),
    );
  }

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
                  if (value == 'report') {
                    await _showReportReasonPicker(
                      context,
                      ownerUid: ownerUid,
                      postData: data ?? const <String, dynamic>{},
                    );
                  }
                },
                itemBuilder: (_) => isOwner
                    ? const [
                        PopupMenuItem(value: 'edit', child: Text('Edit')),
                        PopupMenuItem(value: 'delete', child: Text('Delete')),
                      ]
                    : const [
                        PopupMenuItem(value: 'report', child: Text('Report')),
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
  String? _selectedCategory;
  bool _initialized = false;
  bool _saving = false;

  @override
  void dispose() {
    _contentCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    final category = (_selectedCategory ?? '').trim();
    if (category.isEmpty) return;
    setState(() => _saving = true);
    await widget.postRef.set({
      'content': _contentCtrl.text.trim(),
      'category': category,
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
        if (!_initialized) {
          _contentCtrl.text = (data['content'] ?? '').toString();
          _selectedCategory = (data['category'] ?? '').toString().trim();
          _initialized = true;
        }
        final dropdownItems = <String>[
          ...kCategories,
          if ((_selectedCategory ?? '').isNotEmpty &&
              !kCategories.contains(_selectedCategory))
            _selectedCategory!,
        ];

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
              DropdownButtonFormField<String>(
                value: (_selectedCategory ?? '').isEmpty
                    ? null
                    : _selectedCategory,
                items: dropdownItems
                    .map(
                      (e) => DropdownMenuItem<String>(
                        value: e,
                        child: Text(e),
                      ),
                    )
                    .toList(),
                onChanged: _saving
                    ? null
                    : (v) {
                        setState(() => _selectedCategory = v);
                      },
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
