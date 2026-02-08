import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:vibration/vibration.dart';

class InAppNotificationService {
  static StreamSubscription<QuerySnapshot>? _sub;
  static bool _initialized = false;
  static bool _skipFirstSnapshot = true;
  static final AudioPlayer _player = AudioPlayer();

  static void init({
    required GlobalKey<NavigatorState> navigatorKey,
    required String uid,
  }) {
    if (_initialized) return;
    _initialized = true;
    _skipFirstSnapshot = true;

    _sub = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('activities')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .listen((snapshot) {
      if (_skipFirstSnapshot) {
        _skipFirstSnapshot = false;
        return;
      }

      for (final change in snapshot.docChanges) {
        if (change.type != DocumentChangeType.added) continue;
        final data = change.doc.data() ?? {};
        final title = (data['title'] ?? 'New notification').toString();
        _showBanner(navigatorKey, title);
      }
    });
  }

  static void dispose() {
    _sub?.cancel();
    _sub = null;
    _initialized = false;
    _skipFirstSnapshot = true;
  }

  static void _showBanner(
    GlobalKey<NavigatorState> navigatorKey,
    String title,
  ) {
    final enabled = Hive.box('settings')
        .get('in_app_notifications', defaultValue: true);
    if (enabled is bool && !enabled) return;

    _playAlert();

    final overlay = navigatorKey.currentState?.overlay;
    if (overlay == null) return;

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) {
        return _TopBanner(
          title: title,
          onDismiss: () => entry.remove(),
        );
      },
    );

    overlay.insert(entry);
  }

  static Future<void> _playAlert() async {
    try {
      final soundEnabled = Hive.box('settings')
          .get('in_app_sound', defaultValue: true);
      if (soundEnabled is bool && soundEnabled) {
        await _player.stop();
        await _player.play(AssetSource('bgs/ian.mp3'));
      }
    } catch (_) {}

    try {
      final vibrationEnabled = Hive.box('settings')
          .get('in_app_vibration', defaultValue: true);
      if (vibrationEnabled is bool && vibrationEnabled) {
        final hasVibrator = await Vibration.hasVibrator();
        if (hasVibrator == true) {
          Vibration.vibrate(duration: 120);
        }
      }
    } catch (_) {}
  }
}

class _TopBanner extends StatefulWidget {
  final String title;
  final VoidCallback onDismiss;

  const _TopBanner({
    required this.title,
    required this.onDismiss,
  });

  @override
  State<_TopBanner> createState() => _TopBannerState();
}

class _TopBannerState extends State<_TopBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
      reverseDuration: const Duration(milliseconds: 180),
    );
    _slide = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _controller.forward();
    Future.delayed(const Duration(seconds: 3), () async {
      if (!mounted) return;
      await _controller.reverse();
      widget.onDismiss();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: SlideTransition(
          position: _slide,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Material(
              elevation: 6,
              borderRadius: BorderRadius.circular(12),
              color: Theme.of(context).colorScheme.surface,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () async {
                  await _controller.reverse();
                  widget.onDismiss();
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.notifications, size: 18),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          widget.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
