import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'your_profile_screen.dart';
import 'course_detail_screen.dart';

class HomeSection extends StatefulWidget {
  const HomeSection({super.key});

  @override
  State<HomeSection> createState() => _HomeSectionState();
}

class _HomeSectionState extends State<HomeSection> {
  int streak = 1;

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
    _updateDailyStreak();
  }

  Future<void> _updateDailyStreak() async {
    final box = Hive.box('messages');

    final now = DateTime.now();
    final todayKey = "${now.year}-${now.month}-${now.day}";

    final String? lastDate = box.get('last_open_date');
    int currentStreak = box.get('daily_streak', defaultValue: 1);

    if (lastDate == null) {
      currentStreak = 1;
    } else if (lastDate == todayKey) {
      // same day → no change
    } else {
      final last = DateTime.parse(lastDate);
      final diff = now.difference(last).inDays;

      if (diff == 1) {
        currentStreak += 1;
      } else {
        currentStreak = 1;
      }
    }

    await box.put('last_open_date', todayKey);
    await box.put('daily_streak', currentStreak);

    if (mounted) {
      setState(() => streak = currentStreak);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

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
                    pageBuilder: (_, _, _) =>
                        const YourProfileScreen(),
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
                // padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: theme.colorScheme.primary.withOpacity(0.12),
                ),
                child: CircleAvatar(
                  radius: 16,
                  backgroundColor: theme.colorScheme.primary.withOpacity(0.15),
                  child: Icon(
                    Iconsax.user,
                    size: 20,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
            ),

            const SizedBox(width: 10),

            /// STREAM SELECTOR
            GestureDetector(
              onTap: () {},
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
                  children: [
                    Text(
                      'SSC',
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

            const Spacer(),

            /// 🔥 DAILY STREAK
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: Colors.orange.withOpacity(isDark ? 0.15 : 0.1),
                border: Border.all(
                  color: Colors.orange.withOpacity(0.5),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Iconsax.star5,
                      size: 18, color: Colors.orange),
                  const SizedBox(width: 4),
                  Text(
                    '$streak',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.orange,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 6),

            IconButton(
              onPressed: () {},
              icon: Icon(
                Iconsax.notification,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),

      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _welcomeCard(theme),
            const SizedBox(height: 20),
            _quickActions(theme),
            const SizedBox(height: 24),
            _sectionTitle('Continue Learning', theme),
            const SizedBox(height: 14),
            _horizontalCards(theme),
            const SizedBox(height: 26),
            _sectionTitle('Recommended For You', theme),
            const SizedBox(height: 14),
            _gridCards(theme),
          ],
        ),
      ),
    );
  }

  Widget _welcomeCard(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primary,
            theme.colorScheme.primary.withOpacity(0.85),
          ],
        ),
      ),
      child: const Row(
        children: [
          Expanded(
            child: Text(
              'Welcome back 👋\nReady to learn something new today?',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                height: 1.3,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Icon(Iconsax.book_1, color: Colors.white, size: 34),
        ],
      ),
    );
  }

  Widget _quickActions(ThemeData theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: const [
        _QuickAction(icon: Iconsax.cup, label: 'Quiz'),
        _QuickAction(icon: Iconsax.book, label: 'Library'),
        _QuickAction(icon: Iconsax.search_normal, label: 'Explore'),
        _QuickAction(icon: Iconsax.message, label: 'Chat'),
      ],
    );
  }

  Widget _sectionTitle(String title, ThemeData theme) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: theme.colorScheme.onSurface,
      ),
    );
  }

  Widget _horizontalCards(ThemeData theme) {
    return SizedBox(
      height: 170,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: 5,
        separatorBuilder: (_, _) => const SizedBox(width: 14),
        itemBuilder: (context, index) {
          return Container(
            width: 240,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: theme.colorScheme.surface,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Iconsax.video,
                    size: 28, color: theme.colorScheme.primary),
                const Spacer(),
                Text(
                  'Flutter Basics',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                Text(
                  '12 lessons',
                  style: TextStyle(color: theme.hintColor),
                ),
              ],
            ),
          );
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
  final courseData = courses[index].data() as Map<String, dynamic>;
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
                    style: TextStyle(
                      fontSize: 13,
                      color: theme.hintColor,
                    ),
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
                      color:
                          theme.colorScheme.primary.withOpacity(0.12),
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

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;

  const _QuickAction({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        Container(
          height: 56,
          width: 56,
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withOpacity(0.12),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(icon,
              color: theme.colorScheme.primary, size: 26),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: theme.colorScheme.onSurface,
          ),
        ),
      ],
    );
  }
}
