import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:gyanika/screens/notification_screen.dart';
import 'package:gyanika/screens/preference_screen.dart';
import 'package:gyanika/helpers/notification_helper.dart';
import 'package:iconsax/iconsax.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hive/hive.dart';

import 'my_profile_screen.dart';
import 'course_detail_screen.dart';
import 'explore_section.dart';
import 'subject_screen.dart';
import 'profile_screen.dart';

Future<String> _dailyCurrentUserLabel() async {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return 'Someone';
  final snap = await FirebaseFirestore.instance.collection('users').doc(uid).get();
  final data = snap.data() ?? {};
  final name = (data['name'] ?? '').toString().trim();
  if (name.isNotEmpty) return name;
  final username = (data['username'] ?? '').toString().trim();
  if (username.isNotEmpty) return username;
  return 'Someone';
}

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
      action: _HeroCardAction.dailyPractice,
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
                    switch (card.action) {
                      case _HeroCardAction.dailyPractice:
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const DailyPracticeScreen(),
                          ),
                        );
                        break;
                      case _HeroCardAction.recommended:
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const RecommendedCoursesScreen(),
                          ),
                        );
                        break;
                      case null:
                        break;
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

enum _HeroCardAction { dailyPractice, recommended }

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

class _DailyPracticeQuestion {
  final String id;
  final String source;
  final String content;
  final List<String> options;
  final int? correctIndex;
  final String explanation;
  final String stream;
  final String ownerUid;
  final String ownerName;
  final String ownerUsername;

  const _DailyPracticeQuestion({
    required this.id,
    required this.source,
    required this.content,
    required this.options,
    required this.correctIndex,
    required this.explanation,
    required this.stream,
    required this.ownerUid,
    required this.ownerName,
    required this.ownerUsername,
  });

  String get localKey => '${source}_$id';

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'source': source,
      'content': content,
      'options': options,
      'correctIndex': correctIndex,
      'explanation': explanation,
      'stream': stream,
      'ownerUid': ownerUid,
      'ownerName': ownerName,
      'ownerUsername': ownerUsername,
    };
  }
}

class DailyPracticeScreen extends StatefulWidget {
  const DailyPracticeScreen({super.key});

  @override
  State<DailyPracticeScreen> createState() => _DailyPracticeScreenState();
}

class _DailyPracticeScreenState extends State<DailyPracticeScreen> {
  late Future<void> _initFuture;
  final String _uid = FirebaseAuth.instance.currentUser?.uid ?? 'guest';
  final List<_DailyPracticeQuestion> _questions = [];
  Map<String, int> _answers = {};
  int _currentIndex = 0;
  bool _suppressNavigationTap = false;
  Box? _box;
  Timer? _midnightTimer;

  @override
  void initState() {
    super.initState();
    _initFuture = _initializeDailyPractice();
    _scheduleMidnightReset();
  }

  @override
  void dispose() {
    _midnightTimer?.cancel();
    super.dispose();
  }

  String _dayKey(DateTime d) {
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '${d.year}-$m-$day';
  }

  void _scheduleMidnightReset() {
    _midnightTimer?.cancel();
    final now = DateTime.now();
    final next = DateTime(now.year, now.month, now.day + 1);
    _midnightTimer = Timer(next.difference(now), () async {
      final box = _box ?? await Hive.openBox('daily_practice_local');
      await box.clear();
      if (!mounted) return;
      setState(() {
        _questions.clear();
        _answers = {};
        _currentIndex = 0;
        _initFuture = _initializeDailyPractice();
      });
      _scheduleMidnightReset();
    });
  }

  Future<void> _initializeDailyPractice() async {
    final box = await Hive.openBox('daily_practice_local');
    _box = box;
    final fetched = await _fetchDailyQuestions();
    _questions
      ..clear()
      ..addAll(fetched);
    _answers = {};
  }

  Future<void> _persistAnswers() async {
    final box = _box ?? await Hive.openBox('daily_practice_local');
    final today = _dayKey(DateTime.now());
    await box.put('answers_${_uid}_$today', _answers);
  }

  Future<List<_DailyPracticeQuestion>> _fetchCollectionQuestions(
    String collection,
    String source,
    int limit,
  ) async {
    final snap = await FirebaseFirestore.instance
        .collection(collection)
        .limit(limit)
        .get();
    return snap.docs.map((doc) {
      final data = doc.data();
      final optionsRaw = data['options'];
      final options = optionsRaw is List
          ? optionsRaw
                .map((e) => e.toString().trim())
                .where((e) => e.isNotEmpty)
                .toList()
          : <String>[];
      final content = (data['content'] ?? data['question'] ?? '')
          .toString()
          .trim();
      final stream = (data['stream'] ?? data['exam'] ?? data['category'] ?? '')
          .toString()
          .trim();
      final correctIndex = data['correctIndex'] is num
          ? (data['correctIndex'] as num).toInt()
          : null;
      final explanationRaw = (data['explanation'] ?? '').toString().trim();
      final explanation = explanationRaw.isNotEmpty
          ? explanationRaw
          : (correctIndex != null &&
                    correctIndex >= 0 &&
                    correctIndex < options.length
                ? 'Correct answer: ${options[correctIndex]}'
                : 'Answer submitted.');
      final ownerUid = (data['uid'] ?? '').toString();
      final ownerName = (data['name'] ?? '').toString().trim();
      final ownerUsername = (data['username'] ?? '').toString().trim();
      return _DailyPracticeQuestion(
        id: doc.id,
        source: source,
        content: content,
        options: options,
        correctIndex: correctIndex,
        explanation: explanation,
        stream: stream.isEmpty ? 'General' : stream,
        ownerUid: ownerUid,
        ownerName: ownerName,
        ownerUsername: ownerUsername,
      );
    }).where((q) => q.content.isNotEmpty && q.options.length >= 2).toList();
  }

  Future<bool> _isUnansweredForCurrentUser(_DailyPracticeQuestion q) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return false;

    if (q.source == 'quizzes') {
      final snap = await FirebaseFirestore.instance
          .collection('quizzes')
          .doc(q.id)
          .collection('attempts')
          .doc(uid)
          .get();
      return !snap.exists;
    }
    if (q.source == 'polls') {
      final snap = await FirebaseFirestore.instance
          .collection('polls')
          .doc(q.id)
          .collection('votes')
          .doc(uid)
          .get();
      return !snap.exists;
    }
    if (q.source == 'questions') {
      final snap = await FirebaseFirestore.instance
          .collection('questions')
          .doc(q.id)
          .collection('users')
          .doc(uid)
          .get();
      return !snap.exists;
    }
    return false;
  }

  Future<List<_DailyPracticeQuestion>> _fetchDailyQuestions() async {
    final rng = math.Random();
    final targetCount = 4 + rng.nextInt(9); // 4..12

    final merged = <_DailyPracticeQuestion>[
      ...await _fetchCollectionQuestions('questions', 'questions', 90),
      ...await _fetchCollectionQuestions('quizzes', 'quizzes', 90),
      ...await _fetchCollectionQuestions('polls', 'polls', 90),
    ];

    final dedup = <String, _DailyPracticeQuestion>{};
    for (final q in merged) {
      dedup['${q.source}_${q.id}'] = q;
    }
    final pool = dedup.values.toList();
    if (pool.isEmpty) return const [];

    final unansweredPool = <_DailyPracticeQuestion>[];
    for (final q in pool) {
      if (await _isUnansweredForCurrentUser(q)) {
        unansweredPool.add(q);
      }
    }
    final effectivePool = unansweredPool.isNotEmpty ? unansweredPool : pool;

    effectivePool.sort((a, b) => a.id.compareTo(b.id));
    effectivePool.shuffle(rng);

    final byStream = <String, List<_DailyPracticeQuestion>>{};
    for (final q in effectivePool) {
      byStream.putIfAbsent(q.stream, () => []).add(q);
    }

    final chosen = <_DailyPracticeQuestion>[];
    final streamKeys = byStream.keys.toList()..shuffle(rng);
    for (final key in streamKeys) {
      final list = byStream[key]!;
      if (list.isEmpty) continue;
      chosen.add(list.removeAt(0));
      if (chosen.length >= targetCount) break;
    }

    if (chosen.length < targetCount) {
      final used = chosen.map((e) => e.localKey).toSet();
      for (final q in effectivePool) {
        if (used.contains(q.localKey)) continue;
        chosen.add(q);
        if (chosen.length >= targetCount) break;
      }
    }
    if (chosen.length < 4 && effectivePool.length >= 4) {
      final used = chosen.map((e) => e.localKey).toSet();
      for (final q in effectivePool) {
        if (used.contains(q.localKey)) continue;
        chosen.add(q);
        if (chosen.length >= 4) break;
      }
    }
    return chosen.take(math.min(12, chosen.length)).toList();
  }

  String? _postCollection(_DailyPracticeQuestion q) {
    if (q.source == 'questions') return 'questions';
    if (q.source == 'quizzes') return 'quizzes';
    if (q.source == 'polls') return 'polls';
    return null;
  }

  String _typeLabel(_DailyPracticeQuestion q) {
    if (q.source == 'quizzes') return 'quiz';
    if (q.source == 'polls') return 'poll';
    return 'question';
  }

  String _answerCountLabel(_DailyPracticeQuestion q, int count) {
    if (q.source == 'polls') return '$count votes';
    if (q.source == 'quizzes') return '$count answers';
    return '$count answers';
  }

  String _detailType(_DailyPracticeQuestion q) {
    if (q.source == 'quizzes') return 'Quiz';
    if (q.source == 'polls') return 'Poll';
    return 'Question';
  }

  Future<void> _toggleLike(_DailyPracticeQuestion q) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final collection = _postCollection(q);
    if (uid == null || collection == null) return;

    final postRef = FirebaseFirestore.instance.collection(collection).doc(q.id);
    final likeRef = postRef.collection('likes').doc(uid);
    final liked = (await likeRef.get()).exists;

    await FirebaseFirestore.instance.runTransaction((tx) async {
      if (liked) {
        tx.delete(likeRef);
      } else {
        tx.set(likeRef, {'uid': uid});
      }
      tx.update(postRef, {'likes': FieldValue.increment(liked ? -1 : 1)});
    });

    final ownerUid = q.ownerUid;
    if (ownerUid.isEmpty || ownerUid == uid) return;
    if (liked) {
      await NotificationHelper.removeLikeActivity(
        targetUid: ownerUid,
        actorUid: uid,
        postId: q.id,
        postType: collection,
      );
      return;
    }

    final myName = await _dailyCurrentUserLabel();
    final likeLabel = _typeLabel(q);
    await NotificationHelper.upsertLikeActivity(
      targetUid: ownerUid,
      title: '$myName likes your $likeLabel.',
      actorUid: uid,
      postId: q.id,
      postType: collection,
      content: q.content,
    );
  }

  Future<void> _submitAnswer(int optionIndex) async {
    if (_questions.isEmpty) return;
    final q = _questions[_currentIndex];
    if (_answers.containsKey(q.localKey)) return;
    setState(() => _answers[q.localKey] = optionIndex);
    await _persistAnswers();

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    if (q.source == 'quizzes') {
      final userRef = FirebaseFirestore.instance
          .collection('quizzes')
          .doc(q.id)
          .collection('attempts')
          .doc(uid);
      if (!(await userRef.get()).exists) {
        await userRef.set({'index': optionIndex});
        await FirebaseFirestore.instance
            .collection('quizzes')
            .doc(q.id)
            .update({'answeredCount': FieldValue.increment(1)});
        if (q.ownerUid.isNotEmpty && q.ownerUid != uid) {
          final myName = await _dailyCurrentUserLabel();
          await NotificationHelper.addActivity(
            targetUid: q.ownerUid,
            type: 'vote',
            title: '$myName answered your quiz.',
            actorUid: uid,
            postId: q.id,
            postType: 'quiz',
            content: q.content,
          );
        }
      }
      return;
    }

    if (q.source == 'polls') {
      final userRef = FirebaseFirestore.instance
          .collection('polls')
          .doc(q.id)
          .collection('votes')
          .doc(uid);
      if (!(await userRef.get()).exists) {
        await userRef.set({'option': q.options[optionIndex]});
        await FirebaseFirestore.instance
            .collection('polls')
            .doc(q.id)
            .update({'answeredCount': FieldValue.increment(1)});
        if (q.ownerUid.isNotEmpty && q.ownerUid != uid) {
          final myName = await _dailyCurrentUserLabel();
          await NotificationHelper.addActivity(
            targetUid: q.ownerUid,
            type: 'vote',
            title: '$myName votes on your poll.',
            actorUid: uid,
            postId: q.id,
            postType: 'poll',
            content: q.content,
          );
        }
      }
      return;
    }

    if (q.source == 'questions') {
      final userRef = FirebaseFirestore.instance
          .collection('questions')
          .doc(q.id)
          .collection('users')
          .doc(uid);
      if (!(await userRef.get()).exists) {
        await userRef.set({'option': q.options[optionIndex]});
        await FirebaseFirestore.instance
            .collection('questions')
            .doc(q.id)
            .update({'answeredCount': FieldValue.increment(1)});
        if (q.ownerUid.isNotEmpty && q.ownerUid != uid) {
          final myName = await _dailyCurrentUserLabel();
          await NotificationHelper.addActivity(
            targetUid: q.ownerUid,
            type: 'answer',
            title: '$myName answered your question.',
            actorUid: uid,
            postId: q.id,
            postType: 'question',
            content: q.content,
          );
        }
      }
    }
  }

  void _nextQuestion() {
    if (_currentIndex >= _questions.length - 1) {
      Navigator.pop(context);
      return;
    }
    setState(() => _currentIndex += 1);
  }

  void _previousQuestion() {
    if (_currentIndex <= 0) return;
    setState(() => _currentIndex -= 1);
  }

  void _handleScreenTap(TapUpDetails details) {
    if (_suppressNavigationTap) {
      _suppressNavigationTap = false;
      return;
    }
    final width = MediaQuery.of(context).size.width;
    if (details.localPosition.dx < width / 2) {
      _previousQuestion();
    } else {
      _nextQuestion();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0C1020),
      body: FutureBuilder<void>(
        future: _initFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (_questions.isEmpty) {
            return const Center(
              child: Text('No daily questions available right now.'),
            );
          }

          final q = _questions[_currentIndex];
          final selected = _answers[q.localKey];
          final answered = selected != null;

          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: _handleScreenTap,
            child: Stack(
              children: [
                Positioned.fill(
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0xFF1A2364), Color(0xFF090D1A)],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: -80,
                  right: -60,
                  child: ImageFiltered(
                    imageFilter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
                    child: Container(
                      width: 180,
                      height: 180,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.12),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: List.generate(_questions.length, (i) {
                            return Expanded(
                              child: Container(
                                height: 3,
                                margin: const EdgeInsets.symmetric(horizontal: 2),
                                decoration: BoxDecoration(
                                  color: i <= _currentIndex
                                      ? Colors.white
                                      : Colors.white.withOpacity(0.25),
                                  borderRadius: BorderRadius.circular(99),
                                ),
                              ),
                            );
                          }),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            IconButton(
                              onPressed: () => Navigator.pop(context),
                              icon: const Icon(Icons.close, color: Colors.white),
                            ),
                            const Spacer(),
                            Text(
                              'Daily Practice',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.92),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              '${_currentIndex + 1}/${_questions.length}',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.86),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Flexible(
                          fit: FlexFit.loose,
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.10),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.22),
                              ),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(999),
                                        onTap: q.ownerUid.isEmpty
                                            ? null
                                            : () {
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (_) =>
                                                        ProfileScreen(
                                                      uid: q.ownerUid,
                                                    ),
                                                  ),
                                                );
                                              },
                                        child: Row(
                                          children: [
                                            CircleAvatar(
                                              radius: 13,
                                              backgroundColor:
                                                  Colors.white.withOpacity(
                                                    0.22,
                                                  ),
                                              child: Text(
                                                (q.ownerName.isNotEmpty
                                                        ? q.ownerName
                                                        : q.ownerUsername
                                                                  .isNotEmpty
                                                            ? q.ownerUsername
                                                            : 'G')[0]
                                                    .toUpperCase(),
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    q.ownerName.isNotEmpty
                                                        ? q.ownerName
                                                        : (q.ownerUsername
                                                                  .isNotEmpty
                                                              ? q.ownerUsername
                                                              : 'Gyanika'),
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                    ),
                                                  ),
                                                  Text(
                                                    q.ownerUsername.isNotEmpty
                                                        ? '@${q.ownerUsername}'
                                                        : '@gyanika',
                                                    style: TextStyle(
                                                      color: Colors.white
                                                          .withOpacity(0.78),
                                                      fontSize: 11,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    _BlurStatusChip(
                                      text: q.stream,
                                      icon: Iconsax.category,
                                      dark: true,
                                    ),
                                    const SizedBox(width: 8),
                                    _BlurStatusChip(
                                      text: q.source,
                                      icon: Iconsax.document_text,
                                      dark: true,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 14),
                                Text(
                                  'Q. ${q.content}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Flexible(
                                  fit: FlexFit.loose,
                                  child: ListView.separated(
                                    shrinkWrap: true,
                                    physics:
                                        const NeverScrollableScrollPhysics(),
                                    itemCount: q.options.length,
                                    separatorBuilder: (_, _) =>
                                        const SizedBox(height: 10),
                                    itemBuilder: (context, i) {
                                      final isSelected = selected == i;
                                      final hasCorrect = q.correctIndex != null &&
                                          q.correctIndex! >= 0 &&
                                          q.correctIndex! < q.options.length &&
                                          q.source != 'polls';
                                      final isCorrect = hasCorrect && q.correctIndex == i;
                                      final isWrongSelected =
                                          answered && isSelected && !isCorrect && hasCorrect;

                                      Color tileColor = Colors.white.withOpacity(0.12);
                                      Color tileBorderColor = Colors.white.withOpacity(0.25);

                                      if (answered) {
                                        if (isCorrect) {
                                          tileColor = Colors.green.withOpacity(0.24);
                                          tileBorderColor = Colors.greenAccent.withOpacity(0.9);
                                        } else if (isWrongSelected) {
                                          tileColor = Colors.red.withOpacity(0.24);
                                          tileBorderColor = Colors.redAccent.withOpacity(0.9);
                                        } else if (!hasCorrect && isSelected) {
                                          tileColor = Colors.indigo.withOpacity(0.35);
                                          tileBorderColor = Colors.indigoAccent.withOpacity(0.9);
                                        }
                                      } else if (isSelected) {
                                        tileColor = q.source == 'polls'
                                            ? Colors.indigo.withOpacity(0.35)
                                            : Colors.red.withOpacity(0.82);
                                        tileBorderColor = q.source == 'polls'
                                            ? Colors.indigoAccent.withOpacity(0.9)
                                            : Colors.red.shade100;
                                      }

                                      return GestureDetector(
                                        behavior: HitTestBehavior.opaque,
                                        onTapDown: (_) {
                                          _suppressNavigationTap = true;
                                        },
                                        onTap: answered
                                            ? null
                                            : () async {
                                                await _submitAnswer(i);
                                              },
                                        child: Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: tileColor,
                                            borderRadius: BorderRadius.circular(
                                              14,
                                            ),
                                            border: Border.all(
                                              color: tileBorderColor,
                                            ),
                                          ),
                                          child: Text(
                                            q.options[i],
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Builder(
                                  builder: (context) {
                                    final collection = _postCollection(q);
                                    if (collection == null) {
                                      return Row(
                                        children: [
                                          Row(
                                            children: [
                                              Icon(
                                                Icons.favorite_border,
                                                color: Colors.white.withOpacity(
                                                  0.75,
                                                ),
                                                size: 18,
                                              ),
                                              const SizedBox(width: 6),
                                              Text(
                                                '0',
                                                style: TextStyle(
                                                  color: Colors.white.withOpacity(
                                                    0.85,
                                                  ),
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const Spacer(),
                                          Text(
                                            _answerCountLabel(
                                              q,
                                              answered ? 1 : 0,
                                            ),
                                            style: TextStyle(
                                              color: Colors.white.withOpacity(
                                                0.8,
                                              ),
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      );
                                    }

                                    final postRef = FirebaseFirestore.instance
                                        .collection(collection)
                                        .doc(q.id);
                                    final likeRef = postRef
                                        .collection('likes')
                                        .doc(_uid);

                                    return StreamBuilder<DocumentSnapshot>(
                                      stream: postRef.snapshots(),
                                      builder: (context, postSnap) {
                                        final postData = postSnap.data?.data()
                                                as Map<String, dynamic>? ??
                                            const {};
                                        final likes =
                                            (postData['likes'] as num?)
                                                ?.toInt() ??
                                            0;
                                        final answers =
                                            (postData['answeredCount'] as num?)
                                                ?.toInt() ??
                                            0;

                                        return StreamBuilder<DocumentSnapshot>(
                                          stream: likeRef.snapshots(),
                                          builder: (context, likeSnap) {
                                            final liked =
                                                likeSnap.data?.exists ?? false;
                                            return Row(
                                              children: [
                                                IconButton(
                                                  visualDensity:
                                                      VisualDensity.compact,
                                                  padding: EdgeInsets.zero,
                                                  constraints:
                                                      const BoxConstraints(),
                                                  onPressed: () async {
                                                    _suppressNavigationTap =
                                                        true;
                                                    await _toggleLike(q);
                                                  },
                                                  icon: Icon(
                                                    liked
                                                        ? Icons.favorite
                                                        : Icons.favorite_border,
                                                    color: liked
                                                        ? Colors.pinkAccent
                                                        : Colors.white
                                                              .withOpacity(
                                                                0.85,
                                                              ),
                                                    size: 20,
                                                  ),
                                                ),
                                                const SizedBox(width: 6),
                                                Text(
                                                  likes.toString(),
                                                  style: TextStyle(
                                                    color: Colors.white
                                                        .withOpacity(0.88),
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                                const Spacer(),
                                                GestureDetector(
                                                  onTapDown: (_) {
                                                    _suppressNavigationTap =
                                                        true;
                                                  },
                                                  onTap: () {
                                                    Navigator.push(
                                                      context,
                                                      MaterialPageRoute(
                                                        builder: (_) =>
                                                            PostDetailScreen(
                                                          postId: q.id,
                                                          collection: collection,
                                                          type: _detailType(q),
                                                        ),
                                                      ),
                                                    );
                                                  },
                                                  child: Text(
                                                    _answerCountLabel(q, answers),
                                                    style: TextStyle(
                                                      color: Colors.white
                                                          .withOpacity(0.82),
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            );
                                          },
                                        );
                                      },
                                    );
                                  },
                                ),
                                const SizedBox(height: 10),
                                Center(
                                  child: Text(
                                    'Tap left for previous, right for next',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Colors.grey.shade500,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (answered && q.explanation.trim().isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.25),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.2),
                              ),
                            ),
                            child: Text(
                              q.explanation,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _BlurStatusChip extends StatelessWidget {
  final String text;
  final IconData icon;
  final bool dark;

  const _BlurStatusChip({
    required this.text,
    required this.icon,
    this.dark = false,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: dark
                ? Colors.white.withOpacity(0.15)
                : Theme.of(context).colorScheme.primary.withOpacity(0.14),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: dark
                  ? Colors.white.withOpacity(0.26)
                  : Theme.of(context).colorScheme.primary.withOpacity(0.25),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 13,
                color: dark
                    ? Colors.white
                    : Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 5),
              Text(
                text,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: dark
                      ? Colors.white
                      : Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
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
