import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MyDashboardScreen extends StatelessWidget {
  const MyDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final theme = Theme.of(context);

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text("User not logged in")),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Dashboard'),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              /// 👋 GREETING
              Text(
                "Welcome back, ${data['name'] ?? 'User'} 👋",
                style: theme.textTheme.titleLarge,
              ),

              const SizedBox(height: 20),

              /// 📊 STATS GRID
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                children: [
                  _statCard(
                    context,
                    icon: Icons.groups_outlined,
                    title: 'Joined Groups',
                    value: '${data['joinedGroups'] ?? 0}',
                  ),
                  _statCard(
                    context,
                    icon: Icons.quiz_outlined,
                    title: 'Tests Attempted',
                    value: '${data['testsAttempted'] ?? 0}',
                  ),
                  _statCard(
                    context,
                    icon: Icons.picture_as_pdf_outlined,
                    title: 'PDFs Viewed',
                    value: '${data['pdfViewed'] ?? 0}',
                  ),
                  _statCard(
                    context,
                    icon: Icons.poll_outlined,
                    title: 'Polls Answered',
                    value: '${data['pollsAnswered'] ?? 0}',
                  ),
                ],
              ),

              const SizedBox(height: 30),

              /// 🧠 INFO BOX
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: theme.brightness == Brightness.dark
                      ? Colors.white.withOpacity(0.05)
                      : Colors.black.withOpacity(0.04),
                ),
                child: const Text(
                  "Your learning progress will be shown here.\n"
                  "More detailed analytics are coming soon 🚀",
                  style: TextStyle(fontSize: 13),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _statCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String value,
  }) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: theme.colorScheme.primary.withOpacity(0.08),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 26, color: theme.colorScheme.primary),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              color: theme.hintColor,
            ),
          ),
        ],
      ),
    );
  }
}
