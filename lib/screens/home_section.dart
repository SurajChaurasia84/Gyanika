import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:gyanika/helpers/notification_helper.dart';
import 'package:shimmer/shimmer.dart';
import 'package:iconsax/iconsax.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hive/hive.dart';

import 'notification_screen.dart';
import 'my_profile_screen.dart';
import 'course_detail_screen.dart';
import 'explore_section.dart';
import 'subject_screen.dart';
import 'profile_screen.dart';
import 'library_section.dart';
import 'preference_screen.dart';

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
  late Future<List<_HomeFeedPost>> _homeFeedFuture;
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
      action: _HeroCardAction.mockTests,
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
    _homeFeedFuture = _fetchPersonalizedHomeFeed();
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

      body: RefreshIndicator(
        onRefresh: _refreshHomeSection,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
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
              const SizedBox(height: 16),
              _sectionTitle('For You', theme),
              const SizedBox(height: 10),
              _personalizedFeedSection(theme),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _refreshHomeSection() async {
    final future = _fetchPersonalizedHomeFeed();
    if (mounted) {
      setState(() => _homeFeedFuture = future);
    }
    await future;
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
          height: 160,
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
                      case _HeroCardAction.mockTests:
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const MockTestScreen(),
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

  List<List<T>> _chunkList<T>(List<T> items, int size) {
    if (items.isEmpty) return <List<T>>[];
    final chunks = <List<T>>[];
    for (var i = 0; i < items.length; i += size) {
      final end = math.min(i + size, items.length);
      chunks.add(items.sublist(i, end));
    }
    return chunks;
  }

  Future<List<_HomeFeedPost>> _fetchPersonalizedHomeFeed() async {
    final userSnap = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();
    final userData = userSnap.data() ?? const <String, dynamic>{};

    final rawCategories = userData['categories'];
    final categories = rawCategories is List
        ? rawCategories
              .map((e) => e.toString().trim())
              .where((e) => e.isNotEmpty)
              .toSet()
              .toList()
        : <String>[];

    final followingSnap = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('following')
        .get();
    final followingUids = followingSnap.docs
        .map((d) => d.id.trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();

    final batches = <_HomeQueryBatch>[];
    const collections = ['questions', 'polls', 'quizzes'];

    for (final collection in collections) {
      if (categories.isNotEmpty) {
        final categoryBatch = categories.take(10).toList();
        batches.add(
          _HomeQueryBatch(
            collection: collection,
            future: FirebaseFirestore.instance
                .collection(collection)
                .where('categories', whereIn: categoryBatch)
                .orderBy('createdAt', descending: true)
                .limit(20)
                .get(),
          ),
        );
      }

      if (followingUids.isNotEmpty) {
        final uidChunks = _chunkList(followingUids, 10);
        for (final chunk in uidChunks) {
          batches.add(
            _HomeQueryBatch(
              collection: collection,
              future: FirebaseFirestore.instance
                  .collection(collection)
                  .where('uid', whereIn: chunk)
                  .orderBy('createdAt', descending: true)
                  .limit(20)
                  .get(),
            ),
          );
        }
      }
    }

    if (batches.isEmpty) return const [];

    final snaps = await Future.wait(batches.map((b) => b.future));
    final dedup = <String, _HomeFeedPost>{};
    for (var i = 0; i < snaps.length; i++) {
      final snap = snaps[i];
      final collection = batches[i].collection;
      for (final doc in snap.docs) {
        final id = doc.id;
        final key = '${collection}_$id';
        final data = doc.data() as Map<String, dynamic>? ?? const {};
        dedup[key] = _HomeFeedPost(
          id: id,
          collection: collection,
          data: data,
        );
      }
    }

    final posts = dedup.values.toList()
      ..sort((a, b) {
        final aTs = a.data['createdAt'] as Timestamp?;
        final bTs = b.data['createdAt'] as Timestamp?;
        if (aTs == null && bTs == null) return 0;
        if (aTs == null) return 1;
        if (bTs == null) return -1;
        return bTs.compareTo(aTs);
      });
    return _mixHomeFeed(posts, limit: 30);
  }

  List<_HomeFeedPost> _mixHomeFeed(
    List<_HomeFeedPost> sortedRecentFirst, {
    required int limit,
  }) {
    if (sortedRecentFirst.isEmpty) return const [];

    final maxItems = math.min(limit, sortedRecentFirst.length);
    final recentWindow = math.min(12, sortedRecentFirst.length);
    final recentPool = sortedRecentFirst.take(recentWindow).toList();
    final olderPool = sortedRecentFirst.skip(recentWindow).toList()..shuffle();

    final recentTarget = math.min((maxItems * 0.7).round(), recentPool.length);
    final olderTarget = math.min(maxItems - recentTarget, olderPool.length);

    final recent = recentPool.take(recentTarget).toList();
    final older = olderPool.take(olderTarget).toList();

    final mixed = <_HomeFeedPost>[];
    var recentIndex = 0;
    var olderIndex = 0;

    while (mixed.length < maxItems &&
        (recentIndex < recent.length || olderIndex < older.length)) {
      var recentBurst = 0;
      while (recentBurst < 3 &&
          recentIndex < recent.length &&
          mixed.length < maxItems) {
        mixed.add(recent[recentIndex++]);
        recentBurst++;
      }
      if (olderIndex < older.length && mixed.length < maxItems) {
        mixed.add(older[olderIndex++]);
      }
      if (recentIndex >= recent.length && olderIndex < older.length) {
        mixed.add(older[olderIndex++]);
      }
    }

    if (mixed.length < maxItems && recentIndex < recentPool.length) {
      for (var i = recentIndex; i < recentPool.length && mixed.length < maxItems; i++) {
        mixed.add(recentPool[i]);
      }
    }
    if (mixed.length < maxItems && olderIndex < olderPool.length) {
      for (var i = olderIndex; i < olderPool.length && mixed.length < maxItems; i++) {
        mixed.add(olderPool[i]);
      }
    }

    return mixed;
  }

  Widget _homeFeedSkeleton(ThemeData theme) {
    return Shimmer.fromColors(
      baseColor: theme.colorScheme.surfaceContainerHighest.withOpacity(0.7),
      highlightColor: theme.colorScheme.surface.withOpacity(0.95),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 4,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (_, _) => Container(
          height: 88,
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Widget _personalizedFeedSection(ThemeData theme) {
    return FutureBuilder<List<_HomeFeedPost>>(
      future: _homeFeedFuture,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: _homeFeedSkeleton(theme),
          );
        }

        final posts = snap.data ?? const <_HomeFeedPost>[];
        if (posts.isEmpty) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: theme.colorScheme.outline.withOpacity(0.18),
              ),
            ),
            child: Text(
              'No posts found for your categories/following yet.',
              style: TextStyle(
                color: theme.colorScheme.onSurface.withOpacity(0.7),
                fontWeight: FontWeight.w500,
              ),
            ),
          );
        }

        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: posts.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final post = posts[index];
            final docRef = FirebaseFirestore.instance
                .collection(post.collection)
                .doc(post.id);
            return StreamBuilder<DocumentSnapshot>(
              stream: docRef.snapshots(),
              builder: (context, liveSnap) {
                final liveData =
                    (liveSnap.data?.data() as Map<String, dynamic>?) ??
                    post.data;
                return FeedCard(data: liveData, id: post.id);
              },
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

class _HomeFeedPost {
  final String id;
  final String collection;
  final Map<String, dynamic> data;

  const _HomeFeedPost({
    required this.id,
    required this.collection,
    required this.data,
  });
}

class _HomeQueryBatch {
  final String collection;
  final Future<QuerySnapshot> future;

  const _HomeQueryBatch({
    required this.collection,
    required this.future,
  });
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

enum _HeroCardAction { dailyPractice, mockTests, recommended }

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
            return const _DailyPracticeSkeleton();
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

  factory _DailyPracticeQuestion.fromMap(Map<String, dynamic> map) {
    final optionsRaw = map['options'];
    final options = optionsRaw is List
        ? optionsRaw
              .map((e) => e.toString().trim())
              .where((e) => e.isNotEmpty)
              .toList()
        : <String>[];
    final correctIndex = map['correctIndex'] is num
        ? (map['correctIndex'] as num).toInt()
        : null;
    return _DailyPracticeQuestion(
      id: (map['id'] ?? '').toString(),
      source: (map['source'] ?? '').toString(),
      content: (map['content'] ?? '').toString().trim(),
      options: options,
      correctIndex: correctIndex,
      explanation: (map['explanation'] ?? '').toString().trim(),
      stream: (map['stream'] ?? 'General').toString().trim().isEmpty
          ? 'General'
          : (map['stream'] ?? 'General').toString().trim(),
      ownerUid: (map['ownerUid'] ?? '').toString(),
      ownerName: (map['ownerName'] ?? '').toString().trim(),
      ownerUsername: (map['ownerUsername'] ?? '').toString().trim(),
    );
  }
}

class DailyPracticeScreen extends StatefulWidget {
  const DailyPracticeScreen({super.key});

  @override
  State<DailyPracticeScreen> createState() => _DailyPracticeScreenState();
}

class _DailyPracticeScreenState extends State<DailyPracticeScreen> {
  static const String _dailyBoxName = 'daily_practice_local';
  static const String _dailyPostsDayKey = 'daily_posts_day';
  static const String _dailyPostsItemsKey = 'daily_posts_items';
  late Future<void> _initFuture;
  final String _uid = FirebaseAuth.instance.currentUser?.uid ?? 'guest';
  final List<_DailyPracticeQuestion> _questions = [];
  final Set<String> _answeredInFirebase = <String>{};
  Map<String, int> _answers = {};
  int _currentIndex = 0;
  bool _suppressNavigationTap = false;
  Box? _dailyBox;
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

  void _scheduleMidnightReset() {
    _midnightTimer?.cancel();
    final now = DateTime.now();
    final next = DateTime(now.year, now.month, now.day + 1);
    _midnightTimer = Timer(next.difference(now), () {
      if (!mounted) return;
      setState(() {
        _questions.clear();
        _answers = {};
        _currentIndex = 0;
        _initFuture = _initializeDailyPractice(forceRefresh: true);
      });
      _scheduleMidnightReset();
    });
  }

  String _dayKey(DateTime d) {
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '${d.year}-$m-$day';
  }

  Future<void> _initializeDailyPractice({bool forceRefresh = false}) async {
    final fetched = await _loadOrCreateDailyQuestions(forceRefresh: forceRefresh);
    _questions
      ..clear()
      ..addAll(fetched);
    _answeredInFirebase.clear();
    _answers = {};
    _currentIndex = 0;
  }

  Future<Box> _openDailyBox() async {
    final box = _dailyBox ?? await Hive.openBox(_dailyBoxName);
    _dailyBox = box;
    return box;
  }

  List<_DailyPracticeQuestion> _decodeCachedDailyQuestions(dynamic raw) {
    if (raw is! List) return const [];
    final parsed = <_DailyPracticeQuestion>[];
    for (final item in raw) {
      if (item is! Map) continue;
      final map = <String, dynamic>{};
      for (final entry in item.entries) {
        map[entry.key.toString()] = entry.value;
      }
      final q = _DailyPracticeQuestion.fromMap(map);
      if (q.id.isEmpty || q.source.isEmpty) continue;
      if (q.content.isEmpty || q.options.length < 2) continue;
      parsed.add(q);
    }
    return parsed;
  }

  Future<List<_DailyPracticeQuestion>> _loadOrCreateDailyQuestions({
    bool forceRefresh = false,
  }) async {
    final box = await _openDailyBox();
    final today = _dayKey(DateTime.now());
    final rng = math.Random();

    if (!forceRefresh) {
      final cachedDay = (box.get(_dailyPostsDayKey) ?? '').toString();
      final cached = _decodeCachedDailyQuestions(box.get(_dailyPostsItemsKey));
      if (cachedDay == today && cached.isNotEmpty) {
        final shuffled = cached.take(10).toList()..shuffle(rng);
        return shuffled;
      }
    }

    final fresh = await _fetchDailyQuestions();
    await box.put(_dailyPostsDayKey, today);
    await box.put(
      _dailyPostsItemsKey,
      fresh.map((q) => q.toMap()).toList(growable: false),
    );
    final shuffled = fresh.toList()..shuffle(rng);
    return shuffled;
  }

  Future<List<_DailyPracticeQuestion>> _fetchCollectionQuestions(
    String collection,
    String source,
    int limit,
  ) async {
    final snap = await FirebaseFirestore.instance
        .collection(collection)
        .orderBy('createdAt', descending: true)
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

  Future<List<_DailyPracticeQuestion>> _fetchDailyQuestions() async {
    final rng = math.Random();
    const dailyLimit = 10;

    final merged = <_DailyPracticeQuestion>[
      ...await _fetchCollectionQuestions('quizzes', 'quizzes', 5),
      ...await _fetchCollectionQuestions('polls', 'polls', 5),
    ];

    if (merged.length < dailyLimit) {
      final shortfall = dailyLimit - merged.length;
      merged.addAll(
        await _fetchCollectionQuestions('questions', 'questions', shortfall),
      );
    }

    if (merged.isEmpty) return const [];

    final dedup = <String, _DailyPracticeQuestion>{};
    for (final q in merged) {
      dedup[q.localKey] = q;
    }
    final pool = dedup.values.toList()
      ..sort((a, b) => a.id.compareTo(b.id))
      ..shuffle(rng);

    return pool.take(math.min(dailyLimit, pool.length)).toList();
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
    if (_answeredInFirebase.contains(q.localKey)) return;

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
        if (!mounted) return;
        setState(() => _answers[q.localKey] = optionIndex);
      } else {
        if (!mounted) return;
        setState(() => _answeredInFirebase.add(q.localKey));
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
        if (!mounted) return;
        setState(() => _answers[q.localKey] = optionIndex);
      } else {
        if (!mounted) return;
        setState(() => _answeredInFirebase.add(q.localKey));
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
        if (!mounted) return;
        setState(() => _answers[q.localKey] = optionIndex);
      } else {
        if (!mounted) return;
        setState(() => _answeredInFirebase.add(q.localKey));
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

  Widget _buildRegularOptions(
    _DailyPracticeQuestion q,
    int? selected,
    bool answered,
  ) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: q.options.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final isSelected = selected == i;
        final hasCorrect =
            q.correctIndex != null &&
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
          tileColor = Colors.red.withOpacity(0.82);
          tileBorderColor = Colors.red.shade100;
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
            constraints: const BoxConstraints(minHeight: 48),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: tileColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: tileBorderColor),
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
    );
  }

  Widget _buildPollOptions(_DailyPracticeQuestion q, int? localSelected) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return _buildRegularOptions(q, localSelected, localSelected != null);
    }

    final votesRef = FirebaseFirestore.instance
        .collection('polls')
        .doc(q.id)
        .collection('votes')
        .withConverter<Map<String, dynamic>>(
          fromFirestore: (snap, _) => snap.data() ?? const {},
          toFirestore: (value, _) => value,
        );

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: votesRef.snapshots(),
      builder: (context, snap) {
        final docs = snap.data?.docs ?? const [];
        final counts = List<int>.filled(q.options.length, 0);
        int? selectedFromFirebase;

        for (final doc in docs) {
          final option = (doc.data()['option'] ?? '').toString();
          final idx = q.options.indexOf(option);
          if (idx != -1) {
            counts[idx] += 1;
            if (doc.id == uid) selectedFromFirebase = idx;
          }
        }

        final selected = localSelected ?? selectedFromFirebase;
        final answered =
            selected != null || _answeredInFirebase.contains(q.localKey);
        final total = counts.fold<int>(0, (sum, c) => sum + c);

        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: q.options.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, i) {
            final isSelected = selected == i;
            final percent = answered && total > 0
                ? ((counts[i] / total) * 100).round()
                : 0;

            final tileColor = isSelected
                ? Colors.indigo.withOpacity(0.35)
                : Colors.white.withOpacity(0.12);
            final tileBorderColor = isSelected
                ? Colors.indigoAccent.withOpacity(0.9)
                : Colors.white.withOpacity(0.25);
            final fillColor = isSelected
                ? Colors.indigoAccent.withOpacity(0.28)
                : Colors.white.withOpacity(0.14);

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
                constraints: const BoxConstraints(minHeight: 48),
                decoration: BoxDecoration(
                  color: tileColor,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: tileBorderColor),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Stack(
                    children: [
                      if (answered)
                        FractionallySizedBox(
                          widthFactor: percent / 100,
                          alignment: Alignment.centerLeft,
                          child: Container(height: 48, color: fillColor),
                        ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                q.options[i],
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: isSelected
                                      ? FontWeight.w700
                                      : FontWeight.w600,
                                ),
                              ),
                            ),
                            if (answered)
                              Text(
                                '$percent%',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.9),
                                  fontWeight: FontWeight.w700,
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
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0C1020),
      body: FutureBuilder<void>(
        future: _initFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const _DailyPracticeSkeleton();
          }
          if (_questions.isEmpty) {
            return const Center(
              child: Text('No daily questions available right now.'),
            );
          }

          final q = _questions[_currentIndex];
          final selected = _answers[q.localKey];
          final answered =
              selected != null || _answeredInFirebase.contains(q.localKey);

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
                                  child: q.source == 'polls'
                                      ? _buildPollOptions(q, selected)
                                      : _buildRegularOptions(
                                          q,
                                          selected,
                                          answered,
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
                            constraints: const BoxConstraints(maxHeight: 140),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.25),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.2),
                              ),
                            ),
                            child: SingleChildScrollView(
                              child: Text(
                                q.explanation,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
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

class MockTestScreen extends StatefulWidget {
  const MockTestScreen({super.key});

  @override
  State<MockTestScreen> createState() => _MockTestScreenState();
}

class _MockTestScreenState extends State<MockTestScreen> {
  late Future<void> _initFuture;
  final List<_DailyPracticeQuestion> _questions = [];
  final Map<String, int> _answers = {};
  List<String> _preferences = <String>[];
  String _preferenceStream = 'Mock Tests';
  int _currentIndex = 0;
  bool _suppressNavigationTap = false;

  @override
  void initState() {
    super.initState();
    _initFuture = _initializeMockTests();
  }

  Future<void> _initializeMockTests() async {
    _preferences = <String>[];
    _preferenceStream = 'Mock Tests';
    final userUid = FirebaseAuth.instance.currentUser?.uid;
    if (userUid != null) {
      final userSnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(userUid)
          .get();
      final userData = userSnap.data() ?? const <String, dynamic>{};
      final rawPrefs = userData['preferences'];
      _preferences = rawPrefs is List
          ? rawPrefs
                .map((e) => e.toString().trim())
                .where((e) => e.isNotEmpty)
                .toList()
          : <String>[];
      final stream = (userData['preferenceStream'] ?? '').toString().trim();
      if (stream.isNotEmpty) {
        _preferenceStream = stream;
      }
    }

    final fetched = await _fetchMockQuestionsFromSetCards(
      preferenceStream: _preferenceStream,
      preferences: _preferences,
    );
    _questions
      ..clear()
      ..addAll(fetched);
    _answers.clear();
    _currentIndex = 0;
  }

  String _normalize(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
  }

  Future<List<_DailyPracticeQuestion>> _fetchMockQuestionsFromSetCards({
    required String preferenceStream,
    required List<String> preferences,
  }) async {
    final snap = await FirebaseFirestore.instance
        .collectionGroup('questions')
        .limit(150)
        .get();

    final streamNorm = _normalize(preferenceStream);
    final prefNormMap = <String, String>{
      for (final p in preferences) p: _normalize(p),
    };
    final allowedCardIds = <String, String>{};
    if (streamNorm.isNotEmpty && prefNormMap.isNotEmpty) {
      for (final entry in prefNormMap.entries) {
        allowedCardIds['${streamNorm}_${entry.value}'] = entry.key;
      }
    }

    final entries = <Map<String, dynamic>>[];
    for (final doc in snap.docs) {
      final data = doc.data();
      final optionsRaw = data['options'];
      final options = optionsRaw is List
          ? optionsRaw
                .map((e) => e.toString().trim())
                .where((e) => e.isNotEmpty)
                .toList()
          : <String>[];
      final content = (data['question'] ?? data['content'] ?? '')
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

      final pathParts = doc.reference.path.split('/');
      final cardId = pathParts.length > 1 ? pathParts[1] : '';
      final normalizedCardId = cardId.toLowerCase().trim();
      final streamMatched = streamNorm.isEmpty
          ? true
          : normalizedCardId.startsWith('${streamNorm}_');
      final matchedPreference = allowedCardIds[normalizedCardId];
      String derivedSource = (data['subject'] ?? data['category'] ?? '')
          .toString()
          .trim();
      if (derivedSource.isEmpty &&
          streamNorm.isNotEmpty &&
          normalizedCardId.startsWith('${streamNorm}_')) {
        final suffix = normalizedCardId.substring(streamNorm.length + 1);
        final human = suffix
            .replaceAll('_', ' ')
            .trim()
            .split(' ')
            .where((e) => e.isNotEmpty)
            .map((e) => e[0].toUpperCase() + e.substring(1))
            .join(' ');
        if (human.isNotEmpty) {
          derivedSource = human;
        }
      }

      entries.add({
        'question': _DailyPracticeQuestion(
        id: doc.id,
        source: matchedPreference ?? (derivedSource.isEmpty ? 'General' : derivedSource),
        content: content,
        options: options,
        correctIndex: correctIndex,
        explanation: explanation,
        stream: preferenceStream.isEmpty ? 'Mock Tests' : preferenceStream,
        ownerUid: '',
        ownerName: '',
        ownerUsername: '',
      ),
        'streamMatched': streamMatched,
        'prefMatched': matchedPreference != null,
      });
    }

    final validEntries = entries.where((e) {
      final q = e['question'] as _DailyPracticeQuestion;
      return q.content.isNotEmpty && q.options.length >= 2;
    }).toList();

    final strict = validEntries.where((e) {
      final streamMatched = e['streamMatched'] == true;
      final prefMatched = e['prefMatched'] == true;
      return streamMatched && prefMatched;
    }).toList();

    final streamOnly = validEntries
        .where((e) => e['streamMatched'] == true)
        .toList();

    if (streamNorm.isEmpty) {
      return const [];
    }

    final selectedEntries = preferences.isEmpty ? streamOnly : strict;
    if (selectedEntries.isEmpty) {
      return const [];
    }

    final all = selectedEntries
        .map((e) => e['question'] as _DailyPracticeQuestion)
        .toList();

    final dedup = <String, _DailyPracticeQuestion>{};
    for (final q in all) {
      dedup[q.localKey] = q;
    }
    final list = dedup.values.toList()..shuffle();
    return list.take(math.min(12, list.length)).toList();
  }

  void _submitAnswer(int optionIndex) {
    if (_questions.isEmpty) return;
    final q = _questions[_currentIndex];
    if (_answers.containsKey(q.localKey)) return;
    setState(() => _answers[q.localKey] = optionIndex);
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

  Future<void> _openPreferenceScreen() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PreferenceScreen()),
    );
    if (!mounted) return;
    setState(() {
      _initFuture = _initializeMockTests();
    });
  }

  void _openSubjectFromChip(_DailyPracticeQuestion q) {
    final subject = q.source.trim();
    if (subject.isEmpty || subject.toLowerCase() == 'general') return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            SubjectScreen(subjectName: subject, stream: _preferenceStream),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0C1020),
      body: FutureBuilder<void>(
        future: _initFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const _DailyPracticeSkeleton();
          }
          if (_questions.isEmpty) {
            return const Center(
              child: Text('No mock tests available right now.'),
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
                              "Mock Tests",
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
                                    GestureDetector(
                                      behavior: HitTestBehavior.opaque,
                                      onTapDown: (_) {
                                        _suppressNavigationTap = true;
                                      },
                                      onTap: _openPreferenceScreen,
                                      child: _BlurStatusChip(
                                        text: q.stream,
                                        icon: Iconsax.category,
                                        dark: true,
                                      ),
                                    ),
                                    const Spacer(),
                                    GestureDetector(
                                      behavior: HitTestBehavior.opaque,
                                      onTapDown: (_) {
                                        _suppressNavigationTap = true;
                                      },
                                      onTap: () => _openSubjectFromChip(q),
                                      child: _BlurStatusChip(
                                        text: q.source,
                                        icon: Iconsax.document_text,
                                        dark: true,
                                      ),
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
                                          q.correctIndex! < q.options.length;
                                      final isCorrect =
                                          hasCorrect && q.correctIndex == i;
                                      final isWrongSelected = answered &&
                                          isSelected &&
                                          !isCorrect &&
                                          hasCorrect;

                                      Color tileColor =
                                          Colors.white.withOpacity(0.12);
                                      Color tileBorderColor =
                                          Colors.white.withOpacity(0.25);

                                      if (answered) {
                                        if (isCorrect) {
                                          tileColor =
                                              Colors.green.withOpacity(0.24);
                                          tileBorderColor = Colors.greenAccent
                                              .withOpacity(0.9);
                                        } else if (isWrongSelected) {
                                          tileColor = Colors.red.withOpacity(
                                            0.24,
                                          );
                                          tileBorderColor =
                                              Colors.redAccent.withOpacity(0.9);
                                        }
                                      }

                                      return GestureDetector(
                                        behavior: HitTestBehavior.opaque,
                                        onTapDown: (_) {
                                          _suppressNavigationTap = true;
                                        },
                                        onTap: answered
                                            ? null
                                            : () => _submitAnswer(i),
                                        child: Container(
                                          constraints: const BoxConstraints(
                                            minHeight: 48,
                                          ),
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: tileColor,
                                            borderRadius:
                                                BorderRadius.circular(14),
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
                            constraints: const BoxConstraints(maxHeight: 140),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.25),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.2),
                              ),
                            ),
                            child: SingleChildScrollView(
                              child: Text(
                                'Explanation:\n\t${q.explanation}',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
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

class _DailyPracticeSkeleton extends StatelessWidget {
  const _DailyPracticeSkeleton();

  @override
  Widget build(BuildContext context) {
    const base = Color(0xFF1E2440);
    const highlight = Color(0xFF313A63);

    Widget bar({
      required double height,
      double radius = 10,
      double? width,
      EdgeInsetsGeometry margin = EdgeInsets.zero,
    }) {
      return Container(
        width: width,
        height: height,
        margin: margin,
        decoration: BoxDecoration(
          color: base,
          borderRadius: BorderRadius.circular(radius),
        ),
      );
    }

    return Container(
      color: const Color(0xFF0C1020),
      child: Shimmer.fromColors(
        baseColor: base,
        highlightColor: highlight,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                bar(height: 3, radius: 999, margin: const EdgeInsets.only(bottom: 10)),
                Row(
                  children: [
                    bar(height: 28, width: 28, radius: 999),
                    const SizedBox(width: 8),
                    bar(height: 12, width: 96),
                    const Spacer(),
                    bar(height: 12, width: 54),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: base.withOpacity(0.45),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: highlight.withOpacity(0.35)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          bar(height: 26, width: 26, radius: 999),
                          const SizedBox(width: 8),
                          Expanded(child: bar(height: 12, width: 110)),
                          const SizedBox(width: 8),
                          bar(height: 22, width: 64, radius: 999),
                        ],
                      ),
                      const SizedBox(height: 14),
                      bar(height: 16, width: double.infinity),
                      const SizedBox(height: 10),
                      bar(height: 16, width: 220),
                      const SizedBox(height: 16),
                      bar(height: 44, radius: 14, margin: const EdgeInsets.only(bottom: 10)),
                      bar(height: 44, radius: 14, margin: const EdgeInsets.only(bottom: 10)),
                      bar(height: 44, radius: 14, margin: const EdgeInsets.only(bottom: 10)),
                      bar(height: 44, radius: 14, margin: const EdgeInsets.only(bottom: 10)),
                      Row(
                        children: [
                          bar(height: 18, width: 56),
                          const Spacer(),
                          bar(height: 18, width: 86),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
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
