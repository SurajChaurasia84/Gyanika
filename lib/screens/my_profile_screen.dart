import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive/hive.dart';

import 'appearance_screen.dart';
import 'activity_screen.dart';
import 'help_n_support.dart';
import 'settings_screen.dart';
import 'update_profile.dart';

class MyProfileScreen extends StatelessWidget {
  const MyProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final theme = Theme.of(context);

    if (user == null) {
      return const Scaffold(body: Center(child: Text("User not logged in")));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('My Profile')),
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
          final name = data['name'] ?? 'User';
          final email = user.email ?? '';

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              /// 👤 PROFILE HEADER
              InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const UpdateProfileScreen()),
                  );
                },
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: theme.colorScheme.primary,
                      child: Text(
                        name.isNotEmpty ? name[0].toUpperCase() : 'U',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          email,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 30),
              
              _navTile(
                context,
                icon: Icons.bookmark_border,
                title: 'Activity',
                screen: const ActivityScreen(),
              ),

              _navTile(
                context,
                icon: Icons.palette_outlined,
                title: 'Appearance',
                screen: const AppearanceScreen(),
              ),

              _navTile(
                context,
                icon: Icons.notifications_active_outlined,
                title: 'Notifications',
                screen: const NotificationsScreen(),
              ),

              _navTile(
                context,
                icon: Icons.support_agent_outlined,
                title: 'Help & Support',
                screen: const HelpSupportFeedbackScreen(),
              ),

              _navTile(
                context,
                icon: Icons.settings_outlined,
                title: 'Settings',
                screen: const SettingsScreen(),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _navTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required Widget screen,
  }) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
      },
    );
  }
}

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _inAppEnabled = true;
  bool _soundEnabled = true;
  bool _vibrationEnabled = true;

  @override
  void initState() {
    super.initState();
    final box = Hive.box('settings');
    final saved = box.get('in_app_notifications', defaultValue: true);
    if (saved is bool) {
      _inAppEnabled = saved;
    }
    final sound = box.get('in_app_sound', defaultValue: true);
    if (sound is bool) {
      _soundEnabled = sound;
    }
    final vibration = box.get('in_app_vibration', defaultValue: true);
    if (vibration is bool) {
      _vibrationEnabled = vibration;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            leading: const Icon(Icons.notifications_active_outlined),
            title: const Text('In-app Notifications'),
            subtitle: const Text('Turn on to receive updates'),
            trailing: Switch(
              value: _inAppEnabled,
              onChanged: (value) {
                setState(() => _inAppEnabled = value);
                Hive.box('settings').put('in_app_notifications', value);
              },
            ),
            onTap: () {
              final next = !_inAppEnabled;
              setState(() => _inAppEnabled = next);
              Hive.box('settings').put('in_app_notifications', next);
            },
          ),
          const SizedBox(height: 6),
          const Text(
            'Sounds & Vibration',
            style: TextStyle(fontSize: 13, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          AnimatedOpacity(
            duration: const Duration(milliseconds: 200),
            opacity: _inAppEnabled ? 1 : 0.5,
            child: IgnorePointer(
              ignoring: !_inAppEnabled,
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.volume_up_outlined),
                    title: const Text('Sound'),
                    trailing: Switch(
                      value: _soundEnabled,
                      onChanged: (value) {
                        setState(() => _soundEnabled = value);
                        Hive.box('settings').put('in_app_sound', value);
                      },
                    ),
                    onTap: () {
                      final next = !_soundEnabled;
                      setState(() => _soundEnabled = next);
                      Hive.box('settings').put('in_app_sound', next);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.vibration_outlined),
                    title: const Text('Vibration'),
                    trailing: Switch(
                      value: _vibrationEnabled,
                      onChanged: (value) {
                        setState(() => _vibrationEnabled = value);
                        Hive.box('settings').put('in_app_vibration', value);
                      },
                    ),
                    onTap: () {
                      final next = !_vibrationEnabled;
                      setState(() => _vibrationEnabled = next);
                      Hive.box('settings').put('in_app_vibration', next);
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
