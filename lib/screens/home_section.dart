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
  final PageController _heroCardsController = PageController(
    viewportFraction: 0.9,
    initialPage: 1000,
  );
  Timer? _heroCardsTimer;
  final ValueNotifier<int> _heroCardIndex = ValueNotifier<int>(0);
  final List<_HeroCardData> _heroCards = const [
    _HeroCardData(
      title: 'Daily Practice',
      subtitle: 'Solve quick quizzes and keep your streak alive.',
      icon: Iconsax.flash_1,
      colors: [Color(0xFF3257D5), Color(0xFF5E7CFF)],
    ),
    _HeroCardData(
      title: 'Mock Tests',
      subtitle: 'Build exam confidence with timed full-length tests.',
      icon: Iconsax.clipboard_tick,
      colors: [Color(0xFF0F8D7F), Color(0xFF2CB8A8)],
    ),
    _HeroCardData(
      title: 'Revision Zone',
      subtitle: 'Revise smartly with focused, high-yield concepts.',
      icon: Iconsax.book_saved,
      colors: [Color(0xFFC15C09), Color(0xFFF08F2E)],
    ),
    _HeroCardData(
      title: 'Recommended For You',
      subtitle: 'Explore personalized courses picked for your learning path.',
      icon: Iconsax.star_1,
      colors: [Color(0xFF6A3FB3), Color(0xFF9A65E5)],
      action: _HeroCardAction.recommended,
    ),
  ];

  @override
  void initState() {
    super.initState();
    if (_heroCards.isNotEmpty) {
      _heroCardIndex.value =
          _heroCardsController.initialPage % _heroCards.length;
    }
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
    _startHeroCardsAutoLoop();
  }

  @override
  void dispose() {
    _heroCardsTimer?.cancel();
    _heroCardsController.dispose();
    _heroCardIndex.dispose();
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
            _heroCardsSlider(theme),
            const SizedBox(height: 14),
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
          ],
        ),
      ),
    );
  }

  void _startHeroCardsAutoLoop() {
    _heroCardsTimer?.cancel();
    _heroCardsTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted || !_heroCardsController.hasClients || _heroCards.isEmpty) {
        return;
      }
      final currentPage =
          _heroCardsController.page?.round() ?? _heroCardsController.initialPage;
      final nextPage = currentPage + 1;
      _heroCardsController.animateToPage(
        nextPage,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOutCubic,
      );
    });
  }

  Widget _heroCardsSlider(ThemeData theme) {
    if (_heroCards.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        SizedBox(
          height: 170,
          child: PageView.builder(
            controller: _heroCardsController,
            itemBuilder: (context, index) {
              final card = _heroCards[index % _heroCards.length];
              return Padding(
                padding: const EdgeInsets.only(right: 10),
                child: _HeroCardView(
                  card: card,
                  theme: theme,
                  onTap: () {
                    if (card.action == _HeroCardAction.recommended) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const RecommendedCoursesScreen(),
                        ),
                      );
                    }
                  },
                ),
              );
            },
            onPageChanged: (index) {
              _heroCardIndex.value = index % _heroCards.length;
            },
          ),
        ),
        const SizedBox(height: 10),
        ValueListenableBuilder<int>(
          valueListenable: _heroCardIndex,
          builder: (context, activeIndex, _) {
            return Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_heroCards.length, (index) {
                final isActive = index == activeIndex;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 280),
                  curve: Curves.easeOutCubic,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: isActive ? 18 : 7,
                  height: 7,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    color: isActive
                        ? theme.colorScheme.primary
                        : theme.colorScheme.outline.withOpacity(0.4),
                  ),
                );
              }),
            );
          },
        ),
      ],
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

  Widget _horizontalCards(
    ThemeData theme,
    List<String> subjects,
    String stream,
  ) {
    if (subjects.isEmpty) {
      return const SizedBox.shrink();
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = (constraints.maxWidth - 12) / 2;
        final cardHeight = cardWidth / 1.9;
        return SizedBox(
          height: cardHeight,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: subjects.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              return SizedBox(
                width: cardWidth,
                child: _HomeSubjectCard(
                  title: subjects[index],
                  stream: stream,
                ),
              );
            },
          ),
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: .6,
                    ),
                  ),
                  const SizedBox(height: 4),
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collectionGroup('sets')
                        .where('stream', isEqualTo: stream)
                        .where('subject', isEqualTo: title)
                        .snapshots(),
                    builder: (context, snap) {
                      final docs = snap.data?.docs ?? const [];
                      final totalQuestions = docs.fold<int>(0, (acc, doc) {
                        final data = doc.data() as Map<String, dynamic>? ?? const {};
                        final q = data['questionCount'];
                        if (q is int) return acc + q;
                        if (q is num) return acc + q.toInt();
                        if (q is String) return acc + (int.tryParse(q) ?? 0);
                        return acc;
                      });
                      return Text(
                        '$totalQuestions questions',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      );
                    },
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

class _HeroCardData {
  final String title;
  final String subtitle;
  final IconData icon;
  final List<Color> colors;
  final _HeroCardAction? action;

  const _HeroCardData({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.colors,
    this.action,
  });
}

enum _HeroCardAction { recommended }

class _HeroCardView extends StatelessWidget {
  final _HeroCardData card;
  final ThemeData theme;
  final VoidCallback? onTap;

  const _HeroCardView({required this.card, required this.theme, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: card.colors,
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                right: -24,
                top: -12,
                child: Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(
                      theme.brightness == Brightness.dark ? 0.08 : 0.16,
                    ),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(card.icon, color: Colors.white, size: 20),
                    ),
                    const Spacer(),
                    Text(
                      card.title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      card.subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.92),
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class RecommendedCoursesScreen extends StatelessWidget {
  const RecommendedCoursesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final stream = FirebaseFirestore.instance
        .collection('courses')
        .where('published', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .limit(12)
        .snapshots();

    return Scaffold(
      appBar: AppBar(title: const Text('Recommended For You')),
      body: StreamBuilder<QuerySnapshot>(
        stream: stream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("No courses found"));
          }

          final courses = snapshot.data!.docs;
          return GridView.builder(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            itemCount: courses.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 14,
              crossAxisSpacing: 14,
              childAspectRatio: 0.9,
            ),
            itemBuilder: (context, index) {
              final course = courses[index];
              final courseData = course.data() as Map<String, dynamic>;
              return GestureDetector(
                onTap: () {
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
                      Text(
                        courseData['stream'] ?? '',
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        courseData['courseName'] ?? '',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        courseData['subtitle'] ?? '',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 13, color: theme.hintColor),
                      ),
                      const Spacer(),
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
                          courseData['level'] ?? '',
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
      ),
    );
  }
}

class SearchAllScreen extends StatefulWidget {
  const SearchAllScreen({super.key});

  @override
  State<SearchAllScreen> createState() => _SearchAllScreenState();
}

class _SearchAllScreenState extends State<SearchAllScreen> {
  final TextEditingController _ctrl = TextEditingController();
  final List<String> _history = [];
  final Map<String, List<String>> _streams = {
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: .6,
                    ),
                  ),
                  const SizedBox(height: 4),
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collectionGroup('sets')
                        .where('stream', isEqualTo: stream)
                        .where('subject', isEqualTo: title)
                        .snapshots(),
                    builder: (context, snap) {
                      final docs = snap.data?.docs ?? const [];
                      final totalQuestions = docs.fold<int>(0, (acc, doc) {
                        final data = doc.data() as Map<String, dynamic>? ?? const {};
                        final q = data['questionCount'];
                        if (q is int) return acc + q;
                        if (q is num) return acc + q.toInt();
                        if (q is String) return acc + (int.tryParse(q) ?? 0);
                        return acc;
                      });
                      return Text(
                        '$totalQuestions questions',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      );
                    },
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
