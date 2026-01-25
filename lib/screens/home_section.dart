import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';

class HomeSection extends StatelessWidget {
  const HomeSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,

      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: false,

        titleSpacing: 12,
        title: Row(
          children: [
            // =====================
            // PROFILE ICON (NAVIGATION)
            // =====================
            GestureDetector(
              onTap: () {
                // navigate to profile screen
              },
              child: CircleAvatar(
                radius: 16,
                backgroundColor: Colors.indigo.shade100,
                child: const Icon(Iconsax.user, size: 18, color: Colors.indigo),
              ),
            ),

            const SizedBox(width: 10),

            // =====================
            // STREAM SELECTOR (ONLY STREAM)
            // =====================
            GestureDetector(
              onTap: () {
                // open stream selector bottom sheet
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(
                  children: const [
                    Text(
                      'SSC',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(width: 4),
                    Icon(Iconsax.arrow_down_1, size: 16, color: Colors.grey),
                  ],
                ),
              ),
            ),

            const Spacer(),

            // =====================
            // DAILY STREAK
            // =====================
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: Colors.orange.shade50,
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(
                children: const [
                  Icon(Iconsax.star5, size: 20, color: Colors.orange),
                  SizedBox(width: 4),
                  Text(
                    '12',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.orange,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 8),

            // =====================
            // NOTIFICATION
            // =====================
            IconButton(
              onPressed: () {
                // navigate to notifications
              },
              icon: const Icon(Iconsax.notification, color: Colors.black),
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
            _welcomeCard(),
            const SizedBox(height: 20),
            _quickActions(),
            const SizedBox(height: 24),
            _sectionTitle('Continue Learning'),
            const SizedBox(height: 14),
            _horizontalCards(),
            const SizedBox(height: 26),
            _sectionTitle('Recommended For You'),
            const SizedBox(height: 14),
            _gridCards(),
          ],
        ),
      ),
    );
  }

  // ==========================
  // WELCOME CARD
  // ==========================
  Widget _welcomeCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          colors: [Colors.indigo, Color(0xFF5C6BC0)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: const [
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

  // ==========================
  // QUICK ACTIONS
  // ==========================
  Widget _quickActions() {
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

  // ==========================
  // SECTION TITLE
  // ==========================
  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
    );
  }

  // ==========================
  // HORIZONTAL CARDS
  // ==========================
  Widget _horizontalCards() {
    return SizedBox(
      height: 170,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: 5,
        separatorBuilder: (_, __) => const SizedBox(width: 14),
        itemBuilder: (context, index) {
          return Container(
            width: 240,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: Colors.grey.shade100,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Icon(Iconsax.video, size: 28, color: Colors.indigo),
                Spacer(),
                Text(
                  'Flutter Basics',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                SizedBox(height: 4),
                Text('12 lessons', style: TextStyle(color: Colors.grey)),
              ],
            ),
          );
        },
      ),
    );
  }

  // ==========================
  // GRID CARDS
  // ==========================
  Widget _gridCards() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 6,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 14,
        crossAxisSpacing: 14,
        childAspectRatio: 0.9,
      ),
      itemBuilder: (context, index) {
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: Colors.grey.shade100,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Icon(Iconsax.teacher, color: Colors.indigo, size: 28),
              Spacer(),
              Text(
                'UI Design',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
              SizedBox(height: 4),
              Text('Beginner', style: TextStyle(color: Colors.grey)),
            ],
          ),
        );
      },
    );
  }
}

// ==========================
// QUICK ACTION ITEM
// ==========================
class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;

  const _QuickAction({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          height: 56,
          width: 56,
          decoration: BoxDecoration(
            color: Colors.indigo.shade50,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(icon, color: Colors.indigo, size: 26),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(fontSize: 13)),
      ],
    );
  }
}
