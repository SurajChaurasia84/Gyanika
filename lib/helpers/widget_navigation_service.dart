import 'package:flutter/services.dart';

class WidgetNavigationService {
  static const MethodChannel _channel = MethodChannel('gyanika/widget_navigation');

  static int? _pendingTabIndex;
  static bool _initialized = false;
  static void Function(int index)? onTabRequested;

  static Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    _channel.setMethodCallHandler((call) async {
      if (call.method != 'openTab') {
        return;
      }
      final tabIndex = _extractTabIndex(call.arguments);
      if (tabIndex != null) {
        _deliverTab(tabIndex);
      }
    });

    try {
      final initialTab = await _channel.invokeMethod<String>('getInitialWidgetTab');
      final initialIndex = _tabNameToIndex(initialTab);
      if (initialIndex != null) {
        _pendingTabIndex = initialIndex;
      }
    } catch (_) {
      // App can run normally even if platform channel is unavailable.
    }
  }

  static int? consumePendingTab() {
    final tab = _pendingTabIndex;
    _pendingTabIndex = null;
    return tab;
  }

  static void _deliverTab(int index) {
    final callback = onTabRequested;
    if (callback == null) {
      _pendingTabIndex = index;
      return;
    }
    callback(index);
  }

  static int? _extractTabIndex(dynamic args) {
    if (args is String) {
      return _tabNameToIndex(args);
    }
    if (args is Map) {
      final tab = args['tab'];
      if (tab is String) {
        return _tabNameToIndex(tab);
      }
    }
    return null;
  }

  static int? _tabNameToIndex(String? tabName) {
    switch (tabName?.toLowerCase()) {
      case 'library':
        return 1;
      case 'explore':
        return 2;
      default:
        return null;
    }
  }
}