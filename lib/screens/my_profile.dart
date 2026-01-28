import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:gyanika/screens/personal_detail.dart';
import 'package:iconsax/iconsax.dart';
import 'education_detail.dart';

class MyProfileScreen extends StatelessWidget {
  const MyProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('My Profile'),
        elevation: 0,
      ),
      body: SafeArea(
        child: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(uid)
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final data = snapshot.data!.data() as Map<String, dynamic>? ?? {};

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                /// PERSONAL DETAILS
                _sectionTile(
                  title: 'PERSONAL DETAILS',
                  onEdit: () {
                    Navigator.push(
                      context,
                      PageRouteBuilder(
                        transitionDuration: const Duration(milliseconds: 250),
                        pageBuilder: (_, _, _) => const PersonalDetailScreen(),
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _normalText(
                        [data['name'], data['gender']]
                            .where((e) => e != null && e.toString().isNotEmpty)
                            .join(' • '),
                      ),
                      _subText(data['email']),
                      _subText(data['phone']),
                      _subText(data['location']),
                    ],
                  ),
                  isDark: isDark,
                ),

                const SizedBox(height: 16),

                /// EDUCATION
                _sectionTile(
                  title: 'EDUCATION',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (data['education'] != null)
                        _educationTile(
                          education: data['education'],
                          stream: data['stream'],
                          institute: data['institute'],
                          duration: data['duration'],
                        ),

                      _addButton(
                        label: data['education'] == null
                            ? 'Add education'
                            : 'Edit education',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const EducationDetailScreen(),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  isDark: isDark,
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  // ───────────────── SECTION TILE ─────────────────

  Widget _sectionTile({
    required String title,
    required Widget child,
    bool isDark = false,
    VoidCallback? onEdit,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withOpacity(0.05)
            : Colors.black.withOpacity(0.03),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  color: Colors.grey,
                  letterSpacing: 1,
                ),
              ),
              const Spacer(),
              if (onEdit != null)
                IconButton(
                  icon: const Icon(Iconsax.edit, size: 18),
                  onPressed: onEdit,
                ),
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  // ───────────────── TEXT STYLES ─────────────────

  Widget _normalText(String? text) {
    if (text == null || text.isEmpty) return const SizedBox();
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(text, style: const TextStyle(fontSize: 16)),
    );
  }

  Widget _subText(String? text) {
    if (text == null || text.isEmpty) return const SizedBox();
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        text,
        style: const TextStyle(fontSize: 14, color: Colors.grey),
      ),
    );
  }

  Widget _addButton({required String label, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            const Icon(Iconsax.add, color: Colors.indigo),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(color: Colors.indigo, fontSize: 15),
            ),
          ],
        ),
      ),
    );
  }

  Widget _educationTile({
    String? education,
    String? stream,
    String? institute,
    String? duration,
  }) {
    if (education == null || education.isEmpty) return const SizedBox();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          /// Degree / Course
          Text(
            '$education ${duration != null ? "($duration)" : ""}',
            style: const TextStyle(fontSize: 15),
          ),

          if (stream != null && stream.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              stream,
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],

          if (institute != null && institute.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              institute,
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],

          // if (duration != null && duration.isNotEmpty) ...[
          //   const SizedBox(height: 4),
          //   Text(
          //     duration,
          //     style: const TextStyle(fontSize: 13, color: Colors.grey),
          //   ),
          // ],
        ],
      ),
    );
  }
}
