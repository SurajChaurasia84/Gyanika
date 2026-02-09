import 'dart:async';

import 'package:flutter/material.dart';
import 'package:gyanika/screens/notification_screen.dart';
import 'package:gyanika/screens/preference_screen.dart';
import 'package:iconsax/iconsax.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hive/hive.dart';

import 'my_profile_screen.dart';
import 'course_detail_screen.dart';
import 'explore_section.dart';
import 'subject_screen.dart';
import 'profile_screen.dart';

class HomeSection extends StatefulWidget {
  const HomeSection({super.key});

  @override
  State<HomeSection> createState() => _HomeSectionState();
}

class _HomeSectionState extends State<HomeSection> {
  final String uid = FirebaseAuth.instance.currentUser!.uid;
  late final Box _settingsBox;
  StreamSubscription<DocumentSnapshot>? _userSub;
  String _streamText = 'Select Stream';
  String _profileLetter = '?';

  Stream<QuerySnapshot> recommendedCoursesStream() {
    return FirebaseFirestore.instance
        .collection('courses')
        .where('published', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .limit(6)
        .snapshots();
  }

  @override
  void initState() {
    super.initState();
    _settingsBox = Hive.box('settings');
    final cached = _settingsBox.get('preference_stream');
    if (cached is String && cached.trim().isNotEmpty) {
      _streamText = cached;
    }
    final cachedLetter = _settingsBox.get('profile_letter');
    if (cachedLetter is String && cachedLetter.trim().isNotEmpty) {
      _profileLetter = cachedLetter;
    }
    _userSub = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .snapshots()
        .listen((snap) {
      if (!snap.exists) return;
      final data = snap.data() ?? {};
      final pref = (data['preferenceStream'] ?? '').toString().trim();
      final next = pref.isNotEmpty ? pref : 'Select Stream';
      if (next != _streamText) {
        if (mounted) {
          setState(() => _streamText = next);
        } else {
          _streamText = next;
        }
        _settingsBox.put('preference_stream', next);
      }

      final name = (data['name'] ?? '').toString().trim();
      final username = (data['username'] ?? '').toString().trim();
      final display = name.isNotEmpty ? name : username;
      final letter = display.isNotEmpty ? display[0].toUpperCase() : '?';
      if (letter != _profileLetter) {
        if (mounted) {
          setState(() => _profileLetter = letter);
        } else {
          _profileLetter = letter;
        }
        _settingsBox.put('profile_letter', letter);
      }
    });
  }

  @override
  void dispose() {
    _userSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,

      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: false,
        titleSpacing: 12,

        title: Row(
          children: [
            /// 👤 PROFILE ICON
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  PageRouteBuilder(
                    transitionDuration: const Duration(milliseconds: 250),
                    pageBuilder: (_, _, _) => const MyProfileScreen(),
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

              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: theme.colorScheme.primary.withOpacity(0.12),
                ),
                child: CircleAvatar(
                  radius: 16,
                  backgroundColor: theme.colorScheme.primary.withOpacity(
                    0.15,
                  ),
                  child: Text(
                    _profileLetter,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(width: 10),

            /// STREAM SELECTOR (Cached locally, updated from Firestore)
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  PageRouteBuilder(
                    transitionDuration: const Duration(milliseconds: 250),
                    pageBuilder: (_, _, _) => const PreferenceScreen(),
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
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: theme.dividerColor),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _streamText,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Iconsax.arrow_down_1,
                      size: 16,
                      color: theme.hintColor,
                    ),
                  ],
                ),
              ),
            ),

          ],
        ),
        actions: [
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(uid)
                .collection('activities')
                .where('read', isEqualTo: false)
                .snapshots(),
            builder: (context, snap) {
              final hasUnread = (snap.data?.docs.length ?? 0) > 0;
              return Stack(
                alignment: Alignment.center,
                children: [
                  IconButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        PageRouteBuilder(
                          transitionDuration:
                              const Duration(milliseconds: 250),
                          pageBuilder: (_, _, _) =>
                              const NotificationScreen(),
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
                    icon: Icon(
                      Iconsax.notification,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  if (hasUnread)
                    Positioned(
                      top: 10,
                      right: 10,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                PageRouteBuilder(
                  transitionDuration: const Duration(milliseconds: 250),
                  pageBuilder: (_, _, _) => const SearchAllScreen(),
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
            icon: Icon(Icons.search, color: theme.colorScheme.onSurface),
          ),
        ],
      ),

      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _followedUsersSection(theme),
            const SizedBox(height: 10),
            StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(uid)
                  .snapshots(),
              builder: (context, snapshot) {
                final data =
                    snapshot.data?.data() as Map<String, dynamic>? ?? {};
                final prefStream = (data['preferenceStream'] ?? '').toString();
                final prefSubjects = <String>[];
                final rawPrefs = data['preferences'];
                if (rawPrefs is List) {
                  prefSubjects.addAll(rawPrefs.map((e) => e.toString()));
                }
                final title = prefStream.isNotEmpty
                    ? prefStream
                    : (prefSubjects.isNotEmpty
                          ? 'Your Preferences'
                          : 'Continue Learning');

                if (prefSubjects.isEmpty) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sectionTitle(title, theme),
                      const SizedBox(height: 14),
                      const Center(
                        child: Text(
                          'No preferences set',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    ],
                  );
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionTitle(title, theme),
                    const SizedBox(height: 14),
                    _horizontalCards(theme, prefSubjects, prefStream),
                  ],
                );
              },
            ),
            const SizedBox(height: 16),
            _sectionTitle('Recommended For You', theme),
            const SizedBox(height: 14),
            _gridCards(theme),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title, ThemeData theme) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        // color: theme.colorScheme.onSurface,
        color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withOpacity(.6),
      ),
    );
  }

  Widget _followedUsersSection(ThemeData theme) {
    final ref = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('following')
        .orderBy('time', descending: true);

    return StreamBuilder<QuerySnapshot>(
      stream: ref.snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) return const SizedBox.shrink();
        final docs = snap.data!.docs;
        if (docs.isEmpty) return const SizedBox.shrink();

        final visible = docs.take(8).toList();
        final showAll = docs.length > visible.length;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _sectionTitle('Persons you followed', theme),
                if (showAll)
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const FollowedUsersScreen(),
                        ),
                      );
                    },
                    child: const Text('Show all'),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 85,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: visible.length,
                separatorBuilder: (_, _) => const SizedBox(width: 0),
                itemBuilder: (context, i) {
                  final targetUid = visible[i].id;
                  return _FollowedUserAvatar(uid: targetUid);
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _horizontalCards(
    ThemeData theme,
    List<String> subjects,
    String stream,
  ) {
    if (subjects.isEmpty) {
      return const SizedBox.shrink();
    }
    return SizedBox(
      height: 110,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: subjects.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          return _HomeSubjectCard(title: subjects[index], stream: stream);
        },
      ),
    );
  }

  Widget _gridCards(ThemeData theme) {
    return StreamBuilder<QuerySnapshot>(
      stream: recommendedCoursesStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text("No courses found"));
        }

        final courses = snapshot.data!.docs;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: courses.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 14,
            crossAxisSpacing: 14,
            childAspectRatio: 0.9,
          ),
          itemBuilder: (context, index) {
            final course = courses[index];

            return GestureDetector(
              onTap: () {
                final courseData =
                    courses[index].data() as Map<String, dynamic>;
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CourseDetailScreen(courseData: courseData),
                  ),
                );
              },

              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: theme.colorScheme.surface,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    /// STREAM
                    Text(
                      course['stream'],
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),

                    const SizedBox(height: 8),

                    /// COURSE NAME
                    Text(
                      course['courseName'],
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),

                    const SizedBox(height: 6),

                    /// SUBTITLE
                    Text(
                      course['subtitle'],
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 13, color: theme.hintColor),
                    ),

                    const Spacer(),

                    /// LEVEL BADGE
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: theme.colorScheme.primary.withOpacity(0.12),
                      ),
                      child: Text(
                        course['level'],
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _HomeSubjectCard extends StatelessWidget {
  final String title;
  final String stream;

  const _HomeSubjectCard({required this.title, required this.stream});

  @override
  Widget build(BuildContext context) {
    final config = subjectConfigs[title];
    final bg = config?.color ?? Colors.grey.shade600;
    final image = config?.image ?? 'assets/src/icon.png';

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                SubjectScreen(subjectName: title, stream: stream),
          ),
        );
      },
      child: Container(
        width: 170,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: LinearGradient(
                    begin: Alignment.bottomRight,
                    end: Alignment.topLeft,
                    colors: [
                      Colors.white.withOpacity(.18),
                      Colors.white.withOpacity(.05),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              right: -8,
              bottom: -8,
              child: Opacity(
                opacity: .18,
                child: Image.asset(image, width: 72, height: 72),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Text(
                title.toUpperCase(),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: .6,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SearchAllScreen extends StatefulWidget {
  const SearchAllScreen({super.key});

  @override
  State<SearchAllScreen> createState() => _SearchAllScreenState();
}

class FollowedUsersScreen extends StatelessWidget {
  const FollowedUsersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final myUid = FirebaseAuth.instance.currentUser!.uid;
    final ref = FirebaseFirestore.instance
        .collection('users')
        .doc(myUid)
        .collection('following')
        .orderBy('time', descending: true);

    return Scaffold(
      appBar: AppBar(title: const Text('Following')),
      body: StreamBuilder<QuerySnapshot>(
        stream: ref.snapshots(),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snap.data!.docs;
          if (docs.isEmpty) {
            return const Center(child: Text('No followed users'));
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            itemCount: docs.length,
            itemBuilder: (context, i) {
              final targetUid = docs[i].id;
              return _FollowedUserTile(uid: targetUid);
            },
          );
        },
      ),
    );
  }
}

class _FollowedUserAvatar extends StatelessWidget {
  final String uid;
  const _FollowedUserAvatar({required this.uid});

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

        return InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => ProfileScreen(uid: uid)),
            );
          },
          child: SizedBox(
            width: 82,
            child: Column(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: Colors.indigo,
                  child: Text(
                    letter,
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  display.isNotEmpty ? display : 'User',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  softWrap: false,
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _FollowedUserTile extends StatelessWidget {
  final String uid;
  const _FollowedUserTile({required this.uid});

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
          contentPadding: const EdgeInsets.symmetric(vertical: 4),
          leading: CircleAvatar(
            backgroundColor: Colors.indigo,
            child: Text(
              letter,
              style: const TextStyle(color: Colors.white),
            ),
          ),
          title: Text(display.isNotEmpty ? display : 'User'),
          subtitle: Text(username.isNotEmpty ? '@$username' : ''),
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

class _SearchAllScreenState extends State<SearchAllScreen> {
  final TextEditingController _ctrl = TextEditingController();
  final List<String> _history = [];
  final Map<String, List<String>> _streams = {
    'LKG/UKG': ['ABCD', '0-9'],
    'Class 1-5': [
      'Hindi',
      'English',
      'Maths',
      'Science',
      'Environmental Studies',
      'General Knowledge',
      'Moral Science',
    ],
    'Class 6-8': ['Hindi', 'English', 'Maths', 'Science'],
    'Class 9-10th': [
      'Hindi',
      'English',
      'Mathematics',
      'Science',
      'Social Science',
    ],
    'Class 11-12th': [
      'Hindi',
      'English',
      'Mathematics',
      'Physics',
      'Chemistry',
      'Biology',
    ],
    'JEE': ['Mathematics', 'Physics', 'Chemistry'],
    'NEET': ['Botany', 'Zoology', 'Physics', 'Chemistry'],
    'CUET': ['Language', 'Mathematics', 'Physics', 'Chemistry'],
    'College': ['B.Tech', 'B.Sc', 'BCA', 'BA'],
    'GATE': [
      'Computer Science & IT',
      'Mechanical Engineering',
      'Electrical Engineering',
      'Electronics & Communication',
      'Civil Engineering',
    ],
    'SSC': [
      'Reasoning',
      'Quantitative Aptitude',
      'General Awareness',
      'English Comprehension',
    ],
  };

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  void _loadHistory() {
    final box = Hive.box('messages');
    final raw = box.get('search_history');
    if (raw is List) {
      _history
        ..clear()
        ..addAll(raw.map((e) => e.toString()));
    }
  }

  void _saveHistory(String q) {
    final query = q.trim();
    if (query.isEmpty) return;
    _history.removeWhere((e) => e.toLowerCase() == query.toLowerCase());
    _history.insert(0, query);
    if (_history.length > 12) {
      _history.removeRange(12, _history.length);
    }
    Hive.box('messages').put('search_history', _history);
  }

  Map<String, List<String>> _filteredStreams(String query) {
    if (query.isEmpty) return {};
    final q = query.toLowerCase();
    final Map<String, List<String>> result = {};

    _streams.forEach((section, subjects) {
      final matched = subjects
          .where((s) => s.toLowerCase().contains(q))
          .toList();
      if (matched.isNotEmpty) result[section] = matched;
    });

    return result;
  }

  void _removeHistory(String item) {
    _history.removeWhere((e) => e.toLowerCase() == item.toLowerCase());
    Hive.box('messages').put('search_history', _history);
  }

  Future<void> _confirmClearHistory() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Clear search history'),
        content: const Text('Are you sure you want to clear all searches?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (ok == true) {
      setState(() => _history.clear());
      Hive.box('messages').delete('search_history');
    }
  }

  @override
  Widget build(BuildContext context) {
    final q = _ctrl.text.trim().toLowerCase();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Search',
            border: InputBorder.none,
          ),
          onChanged: (_) => setState(() {}),
          onSubmitted: (v) {
            _saveHistory(v);
            setState(() {});
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      body: DefaultTabController(
        length: 5,
        child: Column(
          children: [
            if (q.isEmpty && _history.isEmpty)
              const Expanded(
                child: Align(
                  alignment: Alignment.topCenter,
                  child: Padding(
                    padding: EdgeInsets.only(top: 16),
                    child: Text(
                      'No recent searches',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                ),
              ),
            if (q.isEmpty && _history.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Recent searches',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    TextButton(
                      onPressed: _confirmClearHistory,
                      child: const Text('Clear all'),
                    ),
                  ],
                ),
              ),
            if (q.isEmpty && _history.isNotEmpty)
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                  itemCount: _history.length,
                  itemBuilder: (context, i) {
                    final h = _history[i];
                    return InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () {
                        _ctrl.text = h;
                        _ctrl.selection = TextSelection.fromPosition(
                          TextPosition(offset: _ctrl.text.length),
                        );
                        setState(() {});
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          // vertical: 10,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                h,
                                style: TextStyle(
                                  color: theme.colorScheme.onSurface,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, size: 18),
                              onPressed: () {
                                setState(() => _removeHistory(h));
                              },
                              tooltip: 'Remove',
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            if (q.isNotEmpty)
              const TabBar(
                isScrollable: false,
                tabs: [
                  Tab(text: 'Users'),
                  Tab(text: 'Explore'),
                  Tab(text: 'Questions'),
                  Tab(text: 'Quizzes'),
                  Tab(text: 'Polls'),
                ],
              ),
            if (q.isNotEmpty)
              Expanded(
                child: TabBarView(
                  children: [
                    _UserResults(query: q),
                    _ExploreResults(query: q, streams: _filteredStreams(q)),
                    _CategoryResults(query: q, collection: 'questions'),
                    _CategoryResults(query: q, collection: 'quizzes'),
                    _CategoryResults(query: q, collection: 'polls'),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _UserResults extends StatelessWidget {
  final String query;
  const _UserResults({required this.query});

  @override
  Widget build(BuildContext context) {
    if (query.isEmpty) return const SizedBox.shrink();
    final ref = FirebaseFirestore.instance
        .collection('users')
        .orderBy('username')
        .startAt([query])
        .endAt(['$query\uf8ff']);

    return StreamBuilder<QuerySnapshot>(
      stream: ref.limit(10).snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) return const SizedBox.shrink();
        final docs = snap.data!.docs;
        if (docs.isEmpty) {
          return const Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: EdgeInsets.only(top: 16),
              child: Text(
                'No searches found',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          itemCount: docs.length,
          itemBuilder: (context, i) {
            final data = docs[i].data() as Map<String, dynamic>;
            final uid = docs[i].id;
            final name = (data['name'] ?? '').toString();
            final username = (data['username'] ?? '').toString();
            final letter = username.isNotEmpty
                ? username[0].toUpperCase()
                : 'U';

            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => ProfileScreen(uid: uid)),
                  );
                },
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: Colors.indigo,
                      child: Text(
                        letter,
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name.isNotEmpty ? name : username,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          '@$username',
                          style: const TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _ExploreResults extends StatelessWidget {
  final String query;
  final Map<String, List<String>> streams;
  const _ExploreResults({required this.query, required this.streams});

  @override
  Widget build(BuildContext context) {
    if (query.isEmpty) return const SizedBox.shrink();
    final data = streams;
    if (data.isEmpty) {
      return const Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: EdgeInsets.only(top: 16),
          child: Text(
            'No searches found',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: data.entries.map((entry) {
        final subjects = entry.value;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              entry.key,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(.6),
              ),
            ),
            const SizedBox(height: 12),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: subjects.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.9,
              ),
              itemBuilder: (_, i) =>
                  _ExploreSubjectCard(title: subjects[i], stream: entry.key),
            ),
            const SizedBox(height: 12),
          ],
        );
      }).toList(),
    );
  }
}

class _ExploreSubjectCard extends StatelessWidget {
  final String title;
  final String stream;

  const _ExploreSubjectCard({required this.title, required this.stream});

  @override
  Widget build(BuildContext context) {
    final config = subjectConfigs[title];
    final bg = config?.color ?? Colors.grey.shade600;
    final image = config?.image ?? 'assets/src/icon.png';

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                SubjectScreen(subjectName: title, stream: stream),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: LinearGradient(
                    begin: Alignment.bottomRight,
                    end: Alignment.topLeft,
                    colors: [
                      Colors.white.withOpacity(.18),
                      Colors.white.withOpacity(.05),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              right: -8,
              bottom: -8,
              child: Opacity(
                opacity: .18,
                child: Image.asset(image, width: 72, height: 72),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Text(
                title.toUpperCase(),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: .6,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryResults extends StatelessWidget {
  final String query;
  final String collection;
  const _CategoryResults({required this.query, required this.collection});

  Future<List<QueryDocumentSnapshot>> _fetchMatches() async {
    if (query.isEmpty) return [];

    final lower = query.toLowerCase();
    final snap = await FirebaseFirestore.instance
        .collection(collection)
        .orderBy('createdAt', descending: true)
        .limit(30)
        .get();

    return snap.docs.where((d) {
      final data = d.data();
      final content = (data['content'] ?? '').toString().toLowerCase();
      return content.contains(lower);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (query.isEmpty) return const SizedBox.shrink();
    return FutureBuilder<List<QueryDocumentSnapshot>>(
      future: _fetchMatches(),
      builder: (context, snap) {
        if (!snap.hasData) return const SizedBox.shrink();
        final items = snap.data!;
        if (items.isEmpty) {
          return const Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: EdgeInsets.only(top: 16),
              child: Text(
                'No searches found',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          itemCount: items.length,
          itemBuilder: (context, i) {
            final doc = items[i];
            final item = doc.data() as Map<String, dynamic>;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PostDetailScreen(
                        postId: doc.id,
                        collection: collection,
                        type: _labelForCollection(collection),
                      ),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Theme.of(
                        context,
                      ).colorScheme.outline.withOpacity(0.2),
                    ),
                  ),
                  child: Text(
                    (item['content'] ?? '').toString(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

String _labelForCollection(String collection) {
  if (collection == 'questions') return 'Question';
  if (collection == 'quizzes') return 'Quiz';
  if (collection == 'polls') return 'Poll';
  return 'Post';
}
